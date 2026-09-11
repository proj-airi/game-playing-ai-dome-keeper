# Lower v0

The game integration baseline is [frozen-20260911](FROZEN.md).

Offline behavior cloning for [ADR-0005](../../docs/decisions/0005-train-lower-v0-with-automated-multitask-demonstrations.md).
Run from the repository root:

```sh
mise run lower-v0:collect
mise run lower-v0:check-dataset
mise run lower-v0:train
mise run lower-v0:evaluate
```

Use `mise run lower-v0:train -- --help` for training options.
The first training run downloads Torchvision's ImageNet ResNet-18 weights.

Data lives in `data/lower-v0/sessions/`. Each Session contains `session.json`
and `frames/<frame_id>.png` RGB images. Each instruction needs at least two distinct scenarios.
Outputs go to `models/lower-v0/artifacts/checkpoint.pt` and `report.json`.
