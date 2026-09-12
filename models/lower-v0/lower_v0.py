"""ADR-0006 causal behavior cloning; run `lower-v0 --help`."""

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import random
import subprocess

from PIL import Image
from pydantic import ValidationError
import torch
from torch import nn
from torch.nn import functional as F
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from torchvision.models import ResNet18_Weights, resnet18
from torchvision.transforms.functional import pil_to_tensor

from session_schema import ACTIONS, PAIRS, TARGETS, TASKS, Session

CONTRACT = dict(schema_version=2, tasks=TASKS, targets=TARGETS, actions=ACTIONS,
                window=10, size=[384, 216], mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225], weights="IMAGENET1K_V1")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_sessions(root, directory="sessions"):
    sessions, ids = [], set()
    for path in sorted((Path(root) / directory).glob("*/session.json")):
        try:
            session = Session.model_validate_json(path.read_text())
        except ValidationError as error:
            error.add_note(f"Session file: {path}")
            raise
        require(session.id == path.parent.name and session.id not in ids,
                f"{path}: duplicate or mismatched ID")
        ids.add(session.id)
        for step in session.steps:
            with Image.open(path.parent / "frames" / f"{step.frame_id}.png") as image:
                require(image.size == (384, 216) and image.mode == "RGB", f"{path}: frame contract")
                image.verify()
        sessions.append(dict(session.model_dump(exclude_unset=True), path=path.parent,
                             pair=(session.instruction.task, session.instruction.target)))
    require(bool(sessions), "No successful Sessions found")
    return sessions


def extract_sessions(root, movie):
    root, movie = Path(root), Path(movie).resolve()
    paths = sorted((root / ".incomplete").glob("*/session.json"))
    require(bool(paths), "No completed recordings to extract")
    for path in paths:
        session = json.loads(path.read_text())
        require(Path(session["movie"]).resolve() == movie, f"{path}: movie mismatch")
        indices = [step["video_frame"] for step in session["steps"]]
        require(bool(indices) and all(isinstance(i, int) and i >= 0 for i in indices)
                and all(b - a == 3 for a, b in zip(indices, indices[1:])),
                f"{path}: invalid movie frame sequence")
        expression = "+".join(f"eq(n,{i})" for i in indices)
        subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-n", "-i", str(movie),
                        "-vf", f"select='{expression}',scale=384:216:flags=bilinear,format=rgb24",
                        "-fps_mode", "passthrough", "-start_number", "0",
                        str(path.parent / "frames" / "%d.png")], check=True)
    sessions = read_sessions(root, ".incomplete")
    destination = root / "sessions"
    destination.mkdir(exist_ok=True)
    for session in sessions:
        require(not (destination / session["id"]).exists(), "Session already exists")
    for session in sessions:
        session["path"].rename(destination / session["id"])
    print(json.dumps(dict(sessions=len(sessions), frames=sum(len(s["steps"]) for s in sessions))))


def split_sessions(sessions, fraction, seed):
    require(0 < fraction < 1, "validation fraction must be between zero and one")
    groups = defaultdict(set)
    for session in sessions:
        groups[session["pair"]].add(session["scenario_id"])
    require(set(groups) == set(PAIRS), "Dataset must cover every task/target pair")
    validation = set()
    rng = random.Random(seed)
    for pair, ids in sorted(groups.items()):
        require(len(ids) >= 2, f"{pair}: need at least two distinct scenarios")
        ids = sorted(ids)
        rng.shuffle(ids)
        validation.update(ids[:max(1, min(len(ids) - 1, round(len(ids) * fraction)))])
    train = [s for s in sessions if s["scenario_id"] not in validation]
    valid = [s for s in sessions if s["scenario_id"] in validation]
    require({s["pair"] for s in train} == set(PAIRS), "Scenario IDs cross instruction groups")
    return train, valid


class Windows(Dataset):
    def __init__(self, sessions):
        self.sessions = sessions
        self.indices = [(s, i) for s in sessions for i in range(len(s["steps"]))]

    def __len__(self):
        return len(self.indices)

    def __getitem__(self, index):
        session, end = self.indices[index]
        frames, held = [], []
        for i in range(end - 9, end + 1):
            step = session["steps"][max(0, i)]
            with Image.open(session["path"] / "frames" / f'{step["frame_id"]}.png') as image:
                frames.append(pil_to_tensor(image).float() / 255)
            held.append(ACTIONS.index(step["held_action"]) if i >= 0 else ACTIONS.index("none"))
        rgb = torch.stack(frames)
        rgb = (rgb - torch.tensor(CONTRACT["mean"])[None, :, None, None]) / torch.tensor(
            CONTRACT["std"])[None, :, None, None]
        task, target = session["pair"]
        instruction = torch.cat((F.one_hot(torch.tensor(TASKS.index(task)), len(TASKS)),
                                 F.one_hot(torch.tensor(TARGETS.index(target)), len(TARGETS)))).float()
        return rgb, F.one_hot(torch.tensor(held), len(ACTIONS)).float(), instruction, ACTIONS.index(
            session["steps"][end]["next_action"])


class Policy(nn.Module):
    def __init__(self, hidden, pretrained=True):
        super().__init__()
        self.cnn = resnet18(weights=ResNet18_Weights.IMAGENET1K_V1 if pretrained else None)
        self.cnn.fc = nn.Identity()
        input_width = 512 * CONTRACT["window"] + len(ACTIONS) * CONTRACT["window"] + len(TASKS) + len(TARGETS)
        widths, layers = [input_width, *hidden, len(ACTIONS)], []
        for i, (before, after) in enumerate(zip(widths, widths[1:])):
            layers.append(nn.Linear(before, after))
            if i < len(widths) - 2:
                layers.append(nn.ReLU())
        self.mlp = nn.Sequential(*layers)

    def forward(self, frames, held, instruction):
        visual = self.cnn(frames.flatten(0, 1)).reshape(frames.shape[0], -1)
        return self.mlp(torch.cat((visual, held.flatten(1), instruction), dim=1))


def counts(dataset):
    return Counter(ACTIONS.index(s["steps"][i]["next_action"]) for s, i in dataset.indices)


def evaluate(model, dataset, device, batch_size, baseline):
    model.eval()
    predictions, labels, loss = [], [], 0.0
    with torch.no_grad():
        for frames, held, instruction, target in DataLoader(dataset, batch_size=batch_size):
            logits = model(frames.to(device), held.to(device), instruction.to(device))
            loss += F.cross_entropy(logits, target.to(device), reduction="sum").item()
            predictions.extend(logits.argmax(1).cpu().tolist())
            labels.extend(target.tolist())
    def metrics(indices):
        return dict(count=len(indices), accuracy=sum(predictions[i] == labels[i] for i in indices) /
                    len(indices) if indices else None,
                    baseline_accuracy=sum(labels[i] == baseline for i in indices) /
                    len(indices) if indices else None)
    result = dict(loss=loss / len(labels), **metrics(list(range(len(labels)))),
                  baseline_action=ACTIONS[baseline])
    result["per_class"] = {action: metrics([i for i, label in enumerate(labels) if label == c])
                           for c, action in enumerate(ACTIONS)}
    for c, action in enumerate(ACTIONS):
        true_positive = sum(p == c and y == c for p, y in zip(predictions, labels))
        predicted = predictions.count(c)
        result["per_class"][action]["precision"] = true_positive / predicted if predicted else None
        result["per_class"][action]["recall"] = result["per_class"][action].pop("accuracy")
    for name, key in (("per_task", lambda s: s["pair"][0]),
                      ("per_target", lambda s: s["pair"][1]),
                      ("per_task_target", lambda s: "/".join(s["pair"]))):
        groups = defaultdict(list)
        for i, (session, _) in enumerate(dataset.indices):
            groups[key(session)].append(i)
        result[name] = {group: metrics(indices) for group, indices in groups.items()}
    return result


def fingerprint(sessions):
    digest = hashlib.sha256()
    for session in sessions:
        digest.update((session["path"] / "session.json").read_bytes())
        for step in session["steps"]:
            digest.update((session["path"] / "frames" / f'{step["frame_id"]}.png').read_bytes())
    return digest.hexdigest()


def export_model(output):
    checkpoint_path = Path(output) / "checkpoint.pt"
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    require(checkpoint["contract"] == CONTRACT, "Checkpoint contract mismatch")

    model = Policy(checkpoint["config"]["hidden"], pretrained=False)
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()

    frames = torch.zeros(1, 10, 3, 216, 384)
    held = torch.zeros(1, CONTRACT["window"], len(ACTIONS))
    instruction = torch.zeros(1, len(TASKS) + len(TARGETS))
    onnx_path = Path(output) / "model.onnx"
    torch.onnx.export(
        model,
        (frames, held, instruction),
        onnx_path,
        input_names=["frames", "held", "instruction"],
        output_names=["logits"],
        opset_version=18,
        dynamo=True,
        external_data=False,
    )

    import onnx
    exported = onnx.load(onnx_path)
    onnx.checker.check_model(exported, full_check=True)
    print(json.dumps({
        "onnx": str(onnx_path),
        "sha256": hashlib.sha256(onnx_path.read_bytes()).hexdigest(),
    }))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "train", "evaluate", "extract"])
    parser.add_argument("--movie", type=Path)
    parser.add_argument("--data", type=Path, default=Path("data/lower-v0"))
    parser.add_argument("--output", type=Path, default=Path("models/lower-v0/artifacts"))
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--batch-size", type=int, default=1)
    parser.add_argument("--hidden", type=int, nargs="+", default=[256])
    parser.add_argument("--lr", type=float, default=0.0001)
    parser.add_argument("--seed", type=int, default=5)
    parser.add_argument("--validation", type=float, default=0.25)
    parser.add_argument("--device", choices=["cpu", "mps", "cuda"], default=None)
    args = parser.parse_args()
    if args.command == "extract":
        require(args.movie is not None, "extract requires --movie")
        extract_sessions(args.data, args.movie)
        return
    require(args.epochs > 0 and args.batch_size > 0 and args.lr > 0 and
            all(width > 0 for width in args.hidden), "Training configuration must be positive")
    torch.manual_seed(args.seed)
    sessions = read_sessions(args.data)
    checkpoint = None
    if args.command == "evaluate":
        checkpoint = torch.load(args.output / "checkpoint.pt", map_location="cpu", weights_only=True)
        require(checkpoint["contract"] == CONTRACT, "Checkpoint contract mismatch")
        require(checkpoint["dataset_sha256"] == fingerprint(sessions), "Dataset changed since training")
        args.seed, args.validation = checkpoint["config"]["seed"], checkpoint["config"]["validation"]
        args.hidden = checkpoint["config"]["hidden"]
    train_sessions, valid_sessions = split_sessions(sessions, args.validation, args.seed)
    train, valid = Windows(train_sessions), Windows(valid_sessions)
    summary = dict(sessions=len(sessions), train_windows=len(train), validation_windows=len(valid),
                   train_counts={action: counts(train)[i] for i, action in enumerate(ACTIONS)},
                   validation_counts={action: counts(valid)[i] for i, action in enumerate(ACTIONS)})
    summary["missing_actions"] = {name: [action for action, count in summary[f"{name}_counts"].items()
                                        if count == 0] for name in ("train", "validation")}
    print(json.dumps(summary, indent=2))
    if args.command == "check":
        return
    device = args.device or ("cuda" if torch.cuda.is_available() else
                             "mps" if torch.backends.mps.is_available() else "cpu")
    model = Policy(args.hidden, pretrained=checkpoint is None).to(device)
    baseline = counts(train).most_common(1)[0][0]
    if checkpoint:
        model.load_state_dict(checkpoint["state_dict"])
    else:
        strata = Counter(session["pair"] for session, _ in train.indices)
        sampler = WeightedRandomSampler([1 / strata[s["pair"]] for s, _ in train.indices], len(train))
        loader = DataLoader(train, batch_size=args.batch_size, sampler=sampler)
        optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr)
        for epoch in range(args.epochs):
            model.train()
            total = 0.0
            for frames, held, instruction, target in loader:
                optimizer.zero_grad(set_to_none=True)
                logits = model(frames.to(device), held.to(device), instruction.to(device))
                loss = F.cross_entropy(logits, target.to(device))
                loss.backward()
                optimizer.step()
                total += loss.item() * len(target)
            print(json.dumps(dict(epoch=epoch + 1, train_loss=total / len(train))), flush=True)
        args.output.mkdir(parents=True, exist_ok=True)
        config = {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()}
        torch.save(dict(state_dict=model.cpu().state_dict(), contract=CONTRACT, config=config,
                        dataset_sha256=fingerprint(sessions),
                        train_sessions=[s["id"] for s in train_sessions],
                        validation_sessions=[s["id"] for s in valid_sessions]), args.output / "checkpoint.pt")
        model.to(device)
    report = dict(**summary, device=device, validation=evaluate(model, valid, device, args.batch_size, baseline))
    (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if checkpoint is None:
        export_model(args.output)


if __name__ == "__main__":
    main()
