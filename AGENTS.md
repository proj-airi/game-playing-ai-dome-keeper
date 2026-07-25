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

## Gameplay Mechanics (Reference)
- The Engineer mines by moving into a tile with the drill; tiles have health/hardness and take multiple hits to break. Reference: https://domekeeper.wiki.gg/wiki/Engineer
- Resources must be picked up and carried; carrying slows movement, and carry-strength upgrades reduce the slowdown (so you can carry more). Reference: https://domekeeper.wiki.gg/wiki/Engineer
- The Engineer has dedicated pickup and drop keybinds for carrying resources (pickup: Space by default, drop: Q by default). Reference: https://domekeeper.wiki.gg/wiki/Engineer
- Drill-strength upgrades make the drill stronger (mine harder rock). Reference: https://domekeeper.wiki.gg/wiki/Engineer

## Vision (YOLO) Plan (Brief)
- Use YOLO26n for MVP detection. Reference: https://docs.ultralytics.com/models/yolo26/
- Collect data via a gameplay capture tool that records frames while playing. Reference: https://docs.ultralytics.com/guides/data-collection-and-annotation/
- Start with a small class set (player, dome, enemy; optional ore). Reference: https://docs.ultralytics.com/datasets/detect/
- Fix training resolution (e.g., 640) and iterate after the end-to-end pipeline works. Reference: https://docs.ultralytics.com/modes/train/
- Initial detection classes: player (engineer), dome (laser), iron ore, cobalt ore, water ore, enemy (all monsters). Reference: internal project decision (no external doc).
- Use Ultralytics YOLO dataset YAML format (`data.yaml`) for train/val paths and class names. Reference: https://docs.ultralytics.com/datasets/detect/

## Immediate Milestone (Decision)
- Build a rule-based teacher collection demo for a single local Engineer using the Laser Dome in a manually started run. The demo covers mining, picking up and delivering nearby resources, returning to the dome, simple defense, and basic stuck recovery while the existing collector produces valid ore/enemy YOLO image-label pairs. References: internal project decision, https://domekeeper.wiki.gg/wiki/Engineer
- The user starts the run manually; automated loadout or menu navigation and restart after death are outside this milestone. Reference: internal project decision.
- Keep teacher actions realizable by the future lower action model: emit normal configured keyboard actions instead of directly changing keeper movement, weapon input fields, or Laser transforms. Before each mining trip, use horizontal input to align the Engineer with the dome's shaft x-coordinate before descending. During defense, select a visible monster deterministically and use left/right/fire actions to close the signed error between the current Laser aim and the monster; do not randomly sweep or directly set the Laser angle. Emit weapon controls only while the keeper is inside the station and `BattleInputProcessor` is the active input leaf, recover the battle input if a wave is still required, and wait for the game's `wavebattle` settlement before leaving the station. References: internal project decision, https://docs.godotengine.org/en/4.3/classes/class_inputmap.html, https://docs.godotengine.org/en/4.3/classes/class_input.html#class-input-method-parse-input-event
- The future lower-model observation must expose the current Laser aim state in addition to visible enemy detections, because the enemy position alone does not determine whether the next realizable action is left, right, or fire. Reference: internal project decision.
- Use an explicit shaft-alignment state before mining and keep mining decisions action-observable rather than reading hidden map shape. Follow a wave-window fishbone pattern around the dome's central shaft: descend exactly two map tile rows, mine continuously to the right until the wave is imminent, then return for defense and start the next trip from the same shaft intersection mining left. After the left mining window, return to the shaft and descend another two rows. A full load outside the wave window resumes the exact mining position; when a wave interrupts visible uncollected resources, resume only to clean them up before advancing to the other side. Do not impose a fixed horizontal branch length. Reuse the target game's bounded open-tile A* path for returning through mined tunnels and resuming either a frontier or shaft checkpoint; do not retain a second breadcrumb navigation system. When shaft alignment or A* navigation stalls, try one-tile probes in the fixed cycle right, down, left, up, starting after the failed direction, and fail only after all four probes fail. Wait for the pause UI and input-processor transitions to finish before emitting gameplay keys, and fail closed when bounded recovery is exhausted. References: internal project decision, https://docs.godotengine.org/en/4.3/classes/class_astar2d.html#class-astar2d-method-get-point-path, https://docs.godotengine.org/en/4.3/tutorials/inputs/inputevent.html#how-does-it-work
- Defer multiplayer, other keepers, non-Laser weapons, upgrades, and action-model dataset or training work until the teacher collection demo is proven. Reference: internal project decision.

## Modding Notes (Brief)
- Dome Keeper mods use the GDScript Mod Loader and require decompiling/importing the game into Godot, then placing mods under `res://mods-unpacked/Author-ModName` with `manifest.json` and `mod_main.gd`. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod
- The modding wiki recommends reviewing Mod Loader docs and proceeding to "Game Investigation" after the first mod setup. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod
- YOLO data collection mod targets Dome Keeper game version 5.0.5.19, Godot 4.3.1, and the official Dome Keeper Editor 5.1 custom build. References: internal project decision, https://github.com/DomeKeeperMods/Docs/wiki/Getting-Started , https://github.com/DomeKeeperMods/Docs/releases/tag/5.1 , https://docs.godotengine.org/en/4.3/about/introduction.html

## Mod Dev Workflow (Decision)
- Keep mod source in this repo under `mods/domekeeper/`, and link or copy it into the decompiled Godot project at `res://mods-unpacked/<Author>-<ModName>/` for testing. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod
- Do not use Mod Loader script extensions for base scripts that declare `class_name`; Godot 4 global classes are unsupported by that mechanism. Remove nonessential extensions instead of retaining a known parse failure, and use a script hook only when the behavior is required. Reference: https://wiki.godotmodding.com/guides/modding/script_extensions/
- For editor test runs, use a Mod Loader scene extension to disable `Game.devMode` while selecting the built-in custom-editor Level entry in memory. This keeps direct-to-level startup without development resources or disabled monster waves, does not persist editor configuration, and leaves retail startup unchanged. Reference: https://wiki.godotmodding.com/api/mod_loader_mod/#void-extend_scene-scene_vanilla_path-string-edit_callable-callable-static
- Add a pause-menu toggle that starts/stops data capture; the collector owns this integration and injects the button when `SceneTree.node_added` reports a PauseMenu instance, avoiding a script extension of the game's preloaded PauseMenu. Each run creates `user://yolo_data/session_<timestamp>/` with `images/` and `labels/`, saving screenshots + YOLO labels at a fixed interval using object-tree queries. References: https://docs.godotengine.org/en/4.3/classes/class_scenetree.html#signal-scenetree-node-added , https://docs.godotengine.org/en/4.3/classes/class_basebutton.html#signal-basebutton-pressed , https://wiki.godotmodding.com/guides/modding/script_extensions/
- On session start, create a `data.yaml` alongside `images/` and `labels/` with YOLO dataset fields (`path`, `train`, `val`, `names`) for the captured classes. Reference: https://docs.ultralytics.com/datasets/detect/
- On session stop, open the capture folder in the OS file manager using Godot's `OS.shell_open`. Reference: https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-shell-open
- Pause capture while the pause menu is visible by having the collector tag the dynamically observed menu panel with a group and check `CanvasItem.is_visible_in_tree()`. References: https://docs.godotengine.org/en/4.3/classes/class_scenetree.html#signal-scenetree-node-added , https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-add-to-group , https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-is-visible-in-tree
- Pause capture while the upgrade popup (TechTree) is visible by tagging `TechTreePopup` with the same group and checking visibility from the collector. References: https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-add-to-group , https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-is-visible-in-tree
- Capture frames are letterboxed to `640x640` with gray padding, and labels are transformed to match the padded image. Reference: https://docs.godotengine.org/en/4.2/classes/class_image.html
- Split each capture session into `train/val/test` by fixed 30-second segments, cycling `4/1/1` over time; write to `images/{split}` and `labels/{split}` and set `data.yaml` accordingly. References: https://docs.godotengine.org/en/4.2/classes/class_time.html#class-time-method-get-ticks-msec , https://docs.ultralytics.com/datasets/detect/
- Treat frames as having a target only when `enemy` or `ore_*` classes are present; allow one no-target frame only after 5 target frames have been captured. Reference: internal project decision (no external doc).
- Collect every active dome returned by the current game's `Level.getDomes()` API rather than the removed single-dome `Level.dome` property, so labels also cover multiplayer and versus runs. Verify game-facing APIs against the recovered target version during each version migration. References: internal project decision, https://github.com/DomeKeeperMods/Docs/wiki/Game-Investigation

## Decompiled Project Layout (Decision)
- Store decompiled Godot projects under `external/domekeeper-decompiled/<game-version>/` (version-isolated).
- Link the repo mod source into each decompiled project at `external/domekeeper-decompiled/<game-version>/mods-unpacked/<Author>-<ModName>/` for testing. Reference: https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod

## Modding EULA & Repo Hygiene (Brief)
- Modding rules explicitly forbid distributing the decompiled project (including the `.pck`) and require that shared mod source contains only modded files, not original game files; they also recommend using a `.gitignore` to enforce this. Reference: https://github-wiki-see.page/m/DomeKeeperMods/Docs/wiki/Getting-Started
- Keep `tmp/` ignored because it may contain a machine-local link to the owned game PCK; never commit the link target or game contents. Reference: https://github-wiki-see.page/m/DomeKeeperMods/Docs/wiki/Getting-Started

## Decompile Script (Decision)
- It is acceptable to commit a local decompilation script as long as it does not include or distribute any game assets or decompiled outputs, and only operates on the user's local installation. Reference: https://github-wiki-see.page/m/DomeKeeperMods/Docs/wiki/Getting-Started
- Manage the required official Dome Keeper Editor with mise's GitHub backend. For the repository's Dome Keeper 5.0.5.19 target, pin editor release 5.1, a custom Godot 4.3.1 build containing the multiplayer modules used by the 5.0 update. Select exact editor assets and published SHA-256 digests for macOS arm64/x64, Linux x64, and Windows x64; unsupported architectures must fail instead of falling back to a mismatched artifact. Do not substitute a regular Godot or generic GodotSteam build, and keep the complete extracted bundle so its native Steam and multiplayer libraries remain beside the editor. References: https://github.com/DomeKeeperMods/Docs/wiki/Getting-Started , https://github.com/DomeKeeperMods/Docs/releases/tag/5.1 , https://mise.jdx.dev/dev-tools/backends/github.html
- The decompile script uses GDRETools CLI (`gdre_tools --headless --recover=... --output=...`) for one-step recovery, then links all repo mods under `mods/` into the decompiled `mods-unpacked/` directory. Reference: https://github.com/GDRETools/gdsdecomp
- Decompile script machine-local inputs are provided through `DOMEKEEPER_GAME_DIR`, `GDRETOOLS_BIN`, and optional `DOMEKEEPER_OUT_ROOT`, read via `import.meta.env`; mise provides the repository-owned `DOMEKEEPER_VERSION`. Godot tasks use the mise-managed editor and must not require a user-supplied `GODOT_BIN`. References: https://bun.com/reference/globals/ImportMeta , https://mise.jdx.dev/environments/
- For macOS stability, set the project rendering method to `forward_plus` in `project.godot` (rendering/renderer/rendering_method). Reference: https://docs.godotengine.org/en/stable/classes/class_projectsettings.html

## Repo Structure (Decision)
- Store each GDScript mod under `mods/<Author>-<ModName>/` (not under `crates/`). Reference: https://wiki.godotmodding.com/guides/modding/mod_structure/

## Dataset Versioning (Decision)
- For Hugging Face datasets, use `main` for ongoing work and use git tags for released dataset versions; create branches only for long-lived variants. References: https://huggingface.co/docs/huggingface_hub/guides/repository , https://huggingface.tw/docs/huggingface_hub/guides/repository

## Tooling (Decision)
- Use mise as the repository-level development-tool manager and task entry point. Pin tool versions in `mise.toml`; mise tasks delegate dependency-specific work to the owning package manager. Pin an LTS Node.js runtime because npm package executables such as ESLint and TypeScript use Node shebangs even when Bun launches their package scripts. Keep mise tool paths ahead of ambient package-manager paths so child-process shebangs resolve the pinned tools. References: https://mise.jdx.dev/dev-tools/ , https://mise.jdx.dev/tasks/ , https://mise.jdx.dev/configuration/settings.html#activate-aggressive , https://nodejs.org/en/about/previous-releases
- Enable mise lockfiles, commit `mise.lock`, and run `mise lock` whenever tool configuration changes so tool URLs and supported checksums remain reproducible. Commit `mise.toml` and `mise.lock` together. Reference: https://mise.jdx.dev/dev-tools/mise-lock.html
- Use Bun for JavaScript dependency installation and lockfile management. Keep `package.json` and `bun.lock`, and run TypeScript scripts with Bun. References: https://bun.sh/docs/pm/cli/install , https://bun.sh/docs/runtime/typescript

## Linting (Decision)
- Use ESLint with `@antfu/eslint-config` and the flat config (`eslint.config.mjs`). References: https://github.com/antfu/eslint-config , https://eslint.org/docs/latest/use/configure/configuration-files-new
- Treat `mise.toml` as mise-owned configuration: format and validate it with `mise fmt`, and exclude it from ESLint's conflicting TOML formatting rules. Reference: https://mise.jdx.dev/cli/fmt.html

## Exec Utilities (Decision)
- Prefer minimal, actively maintained process-exec libraries when available. For this repo, use `tinyexec` as the lightweight command runner. Reference: https://www.npmjs.com/package/tinyexec

## YOLO Python Dependency (Decision)
- Training/export will use the Ultralytics CLI (`yolo ...`), which is installed via the `ultralytics` Python package. Reference: https://docs.ultralytics.com/quickstart/
- Runtime inference can be Python-free by exporting models to formats like ONNX/NCNN/OpenVINO/TensorRT and running them in a non-Python runtime. Reference: https://docs.ultralytics.com/modes/export/

## Python Environment (Decision)
- Use mise to pin the Python and uv executables. Use the explicit `aqua:astral-sh/uv` backend so local legacy plugins cannot change uv resolution or weaken `mise.lock` metadata. Use uv as the sole owner of Python dependencies, `uv.lock`, and `.venv`; do not also create a mise-managed virtual environment or add Pixi for the same environment. Bind uv to mise's Python and disable uv-managed Python downloads so the interpreter has one owner. References: https://mise.jdx.dev/lang/python.html , https://mise.jdx.dev/dev-tools/backends/aqua.html , https://mise.jdx.dev/dev-tools/backend_architecture , https://docs.astral.sh/uv/guides/projects/ , https://docs.astral.sh/uv/reference/settings/#python-downloads
- Reconsider Pixi only if a confirmed requirement needs Conda-native system packages or independently solved accelerator environments; if adopted, Pixi must own Python and the complete environment rather than overlap with mise Python or uv. References: https://pixi.prefix.dev/latest/concepts/conda_pypi/ , https://pixi.prefix.dev/latest/python/pytorch/

## Inference Runtime (Decision)
- Run inference in the browser/Electron worker using `onnxruntime-web` with WebGPU where supported. References: https://onnxruntime.ai/docs/tutorials/web/ , https://onnxruntime.ai/docs/get-started/with-javascript/web.html
- WebGPU is available from Web Workers (via `WorkerNavigator.gpu`), enabling worker-based inference. Reference: https://developer.mozilla.org/en-US/docs/Web/API/WorkerNavigator/gpu

## Scripts Convention (Decision)
- `scripts/` should contain TypeScript scripts executable directly via Bun. Expose shared workflow entry points through mise tasks when repository-level orchestration is useful. References: https://bun.sh/docs/runtime/typescript , https://mise.jdx.dev/tasks/

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
