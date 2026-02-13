# AIRI Dome Keeper Plugin

## Documentation Rule
- When updating this file, always include references/links to the relevant docs or sources for new information.
- During discussion-only phases (no code changes yet), remind the user to update this file with the new decisions.
- Prefer automation across the workflow; automate any step that can be reliably automated, then use manual work only as a fallback.
- After discussions that change decisions/assumptions, update this file automatically (include references).

## AIRI Identity (Reference)
- "AIRI" refers to the open-source Project AIRI by `moeru-ai/airi` (web + desktop), which is a digital companion/virtual character platform. References: https://github.com/moeru-ai/airi , https://github.com/moeru-ai

## Architecture (Brief)
- **AIRI (top-level LLM):** Decides whether to start/stop gameplay. It interacts with the plugin at low frequency and may pause or terminate gameplay based on external context (e.g., time, messages).
- **Plugin Upper Agent (LLM):** Receives game-state summaries (via vision outputs) and produces mid-frequency, high-level tasks for gameplay (e.g., explore, mine, return to defend). It also reports concise status back to AIRI.
- **Plugin Lower Agent (controller):** Runs near-real-time control. It consumes the upper agent’s tasks and translates them into concrete keyboard/mouse actions based on the latest game state.
- **Vision Layer:** Uses object/UI detection to extract structured state from game frames. It feeds both agents, with lower latency to the lower agent and periodic summaries to the upper agent.

## Goals
- Build an AIRI plugin that can autonomously play Dome Keeper using game frames as input and keyboard/mouse mappings as output.
- Support a two-layer agent structure: high-level LLM planning and low-level real-time control.

## Vision (YOLO) Plan (Brief)
- Use YOLO26n for MVP detection. Reference: https://docs.ultralytics.com/models/yolo26/
- Collect data via a gameplay capture tool that records frames while playing. Reference: https://docs.ultralytics.com/guides/data-collection-and-annotation/
- Start with a small class set (player, dome, enemy; optional ore). Reference: https://docs.ultralytics.com/datasets/detect/
- Fix training resolution (e.g., 640) and iterate after the end-to-end pipeline works. Reference: https://docs.ultralytics.com/modes/train/

## Modding Notes (Brief)
- Dome Keeper mods use the GDScript Mod Loader and require decompiling/importing the game into Godot, then placing mods under `res://mods-unpacked/Author-ModName` with `manifest.json` and `mod_main.gd`. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod
- The modding wiki recommends reviewing Mod Loader docs and proceeding to "Game Investigation" after the first mod setup. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod

## Mod Dev Workflow (Decision)
- Keep mod source in this repo under `mods/domekeeper/`, and link or copy it into the decompiled Godot project at `res://mods-unpacked/<Author>-<ModName>/` for testing. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod
- Prefer script extensions for TitleStage UI tweaks (more reliable than hooks during editor runs). Extension scripts should `extends "res://stages/title/TitleStage.gd"` and call `super(...)` in overridden methods. Reference: https://wiki.godotmodding.com/guides/modding/script_extensions/

## Decompiled Project Layout (Decision)
- Store decompiled Godot projects under `external/domekeeper-decompiled/<game-version>/` (version-isolated).
- Link the repo mod source into each decompiled project at `external/domekeeper-decompiled/<game-version>/mods-unpacked/<Author>-<ModName>/` for testing. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod

## Modding EULA & Repo Hygiene (Brief)
- Modding rules explicitly forbid distributing the decompiled project (including the `.pck`) and require that shared mod source contains only modded files, not original game files; they also recommend using a `.gitignore` to enforce this. Reference: https://github-wiki-see.page/m/DomeKeeperMods/Docs/wiki/Getting-Started

## Decompile Script (Decision)
- It is acceptable to commit a local decompilation script as long as it does not include or distribute any game assets or decompiled outputs, and only operates on the user's local installation. Reference: https://github-wiki-see.page/m/DomeKeeperMods/Docs/wiki/Getting-Started
- GodotSteam is required for modding per the Dome Keeper modding docs; the project should document how to obtain it, but avoid auto-downloading by default. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Getting-Started
- The decompile script uses GDRETools CLI (`gdre_tools --headless --recover=... --output=...`) for one-step recovery, then links all repo mods under `mods/` into the decompiled `mods-unpacked/` directory. Reference: https://github.com/GDRETools/gdsdecomp
- Decompile script configuration is provided via environment variables only (`DOMEKEEPER_GAME_DIR`, `GODOT_BIN`, `GDRETOOLS_BIN`, `DOMEKEEPER_VERSION`, optional `DOMEKEEPER_OUT_ROOT`), read via `import.meta.env`. Reference: https://bun.com/reference/globals/ImportMeta
- For macOS stability, set the project rendering method to `forward_plus` in `project.godot` (rendering/renderer/rendering_method). Reference: https://docs.godotengine.org/en/stable/classes/class_projectsettings.html

## Repo Structure (Decision)
- Store each GDScript mod under `mods/<Author>-<ModName>/` (not under `crates/`). Reference: https://wiki.godotmodding.com/guides/modding/mod_structure/

## Dataset Versioning (Decision)
- For Hugging Face datasets, use `main` for ongoing work and use git tags for released dataset versions; create branches only for long-lived variants. References: https://huggingface.co/docs/huggingface_hub/guides/repository , https://huggingface.tw/docs/huggingface_hub/guides/repository

## Tooling (Decision)
- Use Bun as the main task runner/entry point for repo scripts. Reference: https://bun.sh/docs/cli/run

## Linting (Decision)
- Use ESLint with `@antfu/eslint-config` and the flat config (`eslint.config.mjs`). References: https://github.com/antfu/eslint-config , https://eslint.org/docs/latest/use/configure/configuration-files-new

## Exec Utilities (Decision)
- Prefer minimal, actively maintained process-exec libraries when available. For this repo, use `tinyexec` as the lightweight command runner. Reference: https://www.npmjs.com/package/tinyexec

## YOLO Python Dependency (Decision)
- Training/export will use the Ultralytics CLI (`yolo ...`), which is installed via the `ultralytics` Python package. Reference: https://docs.ultralytics.com/quickstart/
- Runtime inference can be Python-free by exporting models to formats like ONNX/NCNN/OpenVINO/TensorRT and running them in a non-Python runtime. Reference: https://docs.ultralytics.com/modes/export/

## Python Environment (Decision)
- Use Pixi to manage Python environments and tasks for training/export tooling. References: https://pixi.prefix.dev/latest/reference/pixi_manifest/ , https://pixi.prefix.dev/latest/reference/pixi_configuration/

## Inference Runtime (Decision)
- Run inference in the browser/Electron worker using `onnxruntime-web` with WebGPU where supported. References: https://onnxruntime.ai/docs/tutorials/web/ , https://onnxruntime.ai/docs/get-started/with-javascript/web.html
- WebGPU is available from Web Workers (via `WorkerNavigator.gpu`), enabling worker-based inference. Reference: https://developer.mozilla.org/en-US/docs/Web/API/WorkerNavigator/gpu

## Scripts Convention (Decision)
- `scripts/` should contain TypeScript scripts executable directly via Bun (no extra task runner). Reference: https://bun.sh/docs/runtime/typescript

## Monorepo Structure (Decision)
- `apps/airi-plugin/` for the AIRI plugin (TypeScript + Bun).
- `apps/vision/` for web inference entrypoints (Electron/Worker runtime).
- `apps/vision-playground/` for a WebGPU model playground and Hugging Face Spaces demo.
- `crates/capture/` for Rust performance-sensitive modules (capture/input/inference helpers).
- `mods/domekeeper/` for the GDScript mod (auto-labeling/metadata export).
- `packages/shared/` for shared types/protocols/schema.
- `scripts/` for Bun-executable TypeScript automation scripts.
- `data/` for recordings/datasets/labels (ignored by git).

## Playground & Spaces (Decision)
- Use Hugging Face Spaces Static HTML SDK (`sdk: static`) for the WebGPU playground demo. References: https://huggingface.co/docs/hub/en/spaces-sdks-static , https://huggingface.tw/docs/hub/spaces-sdks-static
- Configure Spaces via the README YAML front-matter, using `app_build_command` and `app_file` when a build step is required (e.g., Vite). Reference: https://huggingface.co/docs/hub/en/spaces-config-reference

## Electron Integration (Decision)
- Use a Node native addon (Rust via `napi-rs`) to pass captured frames into Electron, instead of `electron-rs`.
