# Vision, Datasets, and Inference

This document owns frame collection, detection classes, datasets, training, runtime inference, playground publication, and Electron vision integration. Read the development document as well when a change touches the Godot collector or repository tooling.

Imperative statements are binding project decisions unless explicitly framed as
an MVP plan, a published artifact, a future target, or historical context.

## Vision (YOLO) Plan

- Use YOLO26n for MVP detection.
- Collect data via a gameplay capture tool that records frames while playing.
- Start with a small class set (player, dome, enemy; optional ore).
- Fix training resolution (e.g., 640) and iterate after the end-to-end pipeline works.
- Initial detection classes: player (engineer), dome (laser), iron ore, cobalt ore, water ore, enemy (all monsters).
- Use Ultralytics YOLO dataset YAML format (`data.yaml`) for train/val paths and class names.

## Collection Boundaries

- Keep TechTree frames excluded from the ore/enemy YOLO dataset even while the
  teacher operates the upgrade popup.

## Dataset Versioning

- For Hugging Face datasets, use `main` for ongoing work and use git tags for released dataset versions; create branches only for long-lived variants.

## YOLO Python Dependency

- Training/export will use the Ultralytics CLI (`yolo ...`), which is installed via the `ultralytics` Python package.
- Runtime inference can be Python-free by exporting models to formats like ONNX/NCNN/OpenVINO/TensorRT and running them in a non-Python runtime.

## Inference Runtime

- Run inference in the browser/Electron worker using `onnxruntime-web` with WebGPU where supported.
- WebGPU is available from Web Workers (via `WorkerNavigator.gpu`), enabling worker-based inference.

## Playground & Spaces

- Use Hugging Face Spaces Static HTML SDK (`sdk: static`) for the WebGPU playground demo.
- Configure Spaces via the README YAML front-matter, using `app_build_command` and `app_file` when a build step is required (e.g., Vite).
- Publish DomeKeeper YOLO v0 for the shared 2D game-playing playground using the existing model/dataset repository convention: the model card pins `playground.dataset_revision`, declares `playground.input_size`, and identifies `playground.output_format`. Export YOLO26 detection as the default end-to-end ONNX layout `(batch, max_det, 6)` and decode `[x1, y1, x2, y2, confidence, class_id]` without external NMS; retain an explicit `yolo-raw` path for existing YOLO11 models.
- DomeKeeper YOLO v0 is published publicly at `proj-airi/domekeeper-yolo-v0`, with its dataset at `proj-airi/domekeeper-yolo-dataset-v0`. The v0 model card pins dataset revision `f0fe78553d6adcd00b830724d11e3f71a955e0a8`; `examples/demo.jpg` is derived from `frame_000008.png`. Publish the verified ONNX artifact and evaluation material, but do not publish the unsanitized PyTorch checkpoint or raw training arguments because they embed machine-local paths.
- The playground video MVP accepts local video files and uses the same inference-driven animation-frame loop as VNC: after one inference completes, the next animation frame copies the video element's current frame and starts another inference without waiting for a newly presented video frame. Keep at most one inference in flight, apply the same square letterbox preprocessing as image and VNC inputs, and stop processing when playback pauses, ends, the tab becomes inactive, or the component unmounts.

## Electron Integration

- Use a Node native addon (Rust via `napi-rs`) to pass captured frames into Electron, instead of `electron-rs`.
