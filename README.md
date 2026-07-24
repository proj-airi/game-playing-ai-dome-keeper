<p align="center">
  <img src="./docs/cover.png" alt="Game AI - Dome Keeper">
</p>

<h1 align="center">Game AI - Dome Keeper</h1>

> This project is part of Project AIRI. We aim to build a LLM‑driven digital companion that can play games and interact with the world.
> Learn more at [Project AIRI](https://github.com/moeru-ai/airi) and the [AIRI live demo](https://airi.moeru.ai).

AI plays the game **Dome Keeper** with CV & LLM combined. Powered by YOLO.

## Models

| Name | Purpose | Base | Release |
| --- | --- | --- | --- |
| Entities | player/dome/ore/enemy detection | YOLO26n | WIP |

## Reproduce

Install [mise](https://mise.jdx.dev/installing-mise.html) before setting up the
repository.

### 1. Mod + Data Collection

1. Clone, install the pinned tools, and install locked dependencies.

```bash
git clone https://github.com/project-airi/game-playing-ai-dome-keeper.git
cd game-playing-ai-dome-keeper
mise install
mise run setup
```

2. Decompile the game.

Please follow the [modding rules](https://github.com/DomeKeeperMods/Docs/wiki/Getting-Started#modding-intro-and-rules). We assume you already own the game.

The [official Dome Keeper Editor 5.1](https://github.com/DomeKeeperMods/Docs/releases/tag/5.1)
(Godot 4.3.1 custom build) is installed and locked by mise. The pinned editor
supports macOS arm64/x64, Linux x64, and Windows x64. Keep the complete extracted
bundle intact because its Steam and multiplayer libraries are required at runtime.
Download GDRETools from [gdsdecomp releases](https://github.com/GDRETools/gdsdecomp/releases)
and set the remaining machine-local inputs:

```bash
export DOMEKEEPER_GAME_DIR="/path/to/Dome Keeper"
export GDRETOOLS_BIN="/path/to/gdre_tools"
```

PowerShell:

```powershell
$env:DOMEKEEPER_GAME_DIR = "C:\Path\To\Dome Keeper"
$env:GDRETOOLS_BIN = "C:\Path\To\gdre_tools"
```

Then run:

```bash
mise run decompile
```

3. Open the decompiled project.

```bash
mise run godot:open
```

4. Collect a dataset session.

- In the pause menu, click **YOLO Collect** to start/stop.
- Each session is stored under `user://yolo_data/session_<timestamp>/`.
- Outputs include `images/`, `labels/`, and `data.yaml`.
- Frames are letterboxed to `640×640` with gray padding.
- Session data is split into `train/val/test` by time segments (30s each, cycling 4/1/1).

### 2. Train a Baseline (Ultralytics)

We use the Ultralytics CLI (`yolo`) for training and export.

```bash
mise run train data=/path/to/session/data.yaml model=yolo26n imgsz=640
```

## Technical Reports

### Data Collection

- In‑game Godot mod adds a pause‑menu toggle and auto‑labels frames.
- Label transform handles view‑to‑texture scale mismatch and letterbox padding.

## Development

```bash
mise install
mise run setup
mise run check
```

`mise install` uses the committed `mise.lock`. After changing a tool version or
release asset in `mise.toml`, run `mise lock` and commit both files together.
The Dome Keeper Editor assets are pinned to the SHA-256 digests published by the
official GitHub release; review URL, digest, and asset-size changes together.

mise owns development-tool versions (including the Node runtime used by npm
package executables) and repository-level tasks. Bun owns JavaScript
dependencies through `package.json` and `bun.lock`; uv owns Python dependencies
and the project environment through `pyproject.toml`, `uv.lock`, and `.venv`.
Run Python tools through `uv run` or a mise task rather than using bare
`python`, `pip`, or `yolo` commands.

## Note

- **macOS rendering**: set `renderer/rendering_method="forward_plus"` in `project.godot` if you see crashes.
- **GDScript IntelliSense**: install [Godot Tools](https://marketplace.visualstudio.com/items?itemName=geequlim.godot-tools). If the extension cannot discover the editor, resolve the pinned installation with `mise where godotdome` and configure that location in an ignored local workspace file.

## Citation

If you find our works useful for your research, please consider citing:

```
@misc{airi_dome_keeper_2026,
  title        = {Game AI - Dome Keeper},
  author       = {Project AIRI Team},
  howpublished = {\url{https://github.com/project-airi/game-playing-ai-dome-keeper}},
  year         = {2026}
}
```

## About

AI plays the game Dome Keeper with CV & LLM combined. Powered by YOLO.
