# Lower v0 frozen-20260911

This version is the fixed baseline for game integration. Further collection and tuning are deferred.
The checkpoint is an offline policy, not a verified game controller.

## Artifacts

Paths are relative to the repository root:

- Dataset: `data/lower-v0-frozen-20260911/`
- Checkpoint: `models/lower-v0/artifacts/frozen-20260911/checkpoint.pt`
- Evaluation: `models/lower-v0/artifacts/frozen-20260911/report.json`
- Hashes and configuration: `models/lower-v0/artifacts/frozen-20260911/freeze.json`

The snapshot contains 166 Sessions and 2,727 frames: 160 existing Sessions and six new mixed-cargo Drop Sessions.
It excludes the other ten repeated smoke scenarios.
The existing Sessions precede the camera fix and use the earlier cargo fixture.
The six new Drop Sessions use the camera fix and carry three to eight resources.
The snapshot preserves the original Session metadata and images.

Training uses five epochs, batch size eight, seed five, and learning rate `0.0001` on MPS.
The model uses ResNet-18 and one hidden layer with 256 units.
The validation split groups Sessions by scenario and uses a fraction of `0.25`.
The checkpoint contains the exact split, configuration, and dataset fingerprint.

## Offline result

The split contains 2,054 training windows and 673 validation windows.
Validation accuracy is 83.95%. The majority-class baseline is 26.75% (`dome1_fire`).
Upward movement recall is 21.74% (5/23). The model misses all five `ui_select` labels.
Pickup recall is 80% (48/60), and Drop recall is 100% (18/18).
These results describe individual action labels, not game task completion.
This split differs from the previous model, so the accuracy figures are not a controlled comparison.

## Runtime contract

The source of truth is `checkpoint["contract"]` and [Policy](lower_v0.py).
The policy accepts three float32 tensors:

| Input | Shape | Meaning |
| --- | --- | --- |
| Frames | `[B, 10, 3, 216, 384]` | Ten RGB frames, oldest first |
| Held actions | `[B, 10, 9]` | One-hot action at each frame capture |
| Instruction | `[B, 9]` | Four task slots followed by five target slots |

Capture observations at 10 Hz. Resize the full view to 384 by 216 pixels without cropping.
Divide RGB values by 255. Normalize each channel with the mean and standard deviation from the checkpoint contract.
Use only completed frames captured before the decision.
At task start, pad missing images with the first image and missing actions with `none`.
Reset the history for each task.

Task order is `pickup, drop, activate, attack`.
Target order is `iron, cobalt, water, gadget_chamber, monster`.
Supported pairs are Pickup/Drop with each resource, Activate with the gadget chamber, and Attack with the monster.

The output contains nine logits in this order:
`ui_up, ui_down, ui_left, ui_right, ui_select, keeper1_pickup, keeper1_drop, dome1_fire, none`.
Select the largest logit. Maintain that action until the next decision.
Release the previous action when the action changes. The `none` action releases input; it does not indicate task completion.

Load `Policy(checkpoint["config"]["hidden"], pretrained=False)` and then load `checkpoint["state_dict"]`.
Call `eval()` and disable gradients for inference.
This artifact uses PyTorch. It does not include an ONNX export or a game-side inference host.

## Reproduce evaluation

Run from the repository root:

```sh
mise x -- uv run --locked --package lower-v0 lower-v0 evaluate \
  --data data/lower-v0-frozen-20260911 \
  --output models/lower-v0/artifacts/frozen-20260911 \
  --batch-size 8 --device mps
```

Evaluation rejects a dataset whose fingerprint differs from the checkpoint.
Do not train into this artifact directory. Use a new version directory for subsequent experiments.
