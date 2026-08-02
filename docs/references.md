# References

This page collects external resources useful for understanding and maintaining the AIRI Dome Keeper plugin. Each entry explains what the resource is and how it relates to this project.

## Project and Game

- [Project AIRI](https://github.com/moeru-ai/airi) — The main Project AIRI repository; this project is a Dome Keeper plugin for AIRI.
- [Project AIRI v0.10.0 Release](https://github.com/moeru-ai/airi/releases/tag/v0.10.0) — The upstream release that introduced the current plugin manifest and Kits, Bindings, Tools, and Gamelet APIs relevant to defining this project's future AIRI integration boundary.
- [Dome Keeper Engineer](https://domekeeper.wiki.gg/wiki/Engineer) — A gameplay reference for the Engineer's drilling, carrying, controls, and upgrades used by the teacher.
- [Dome Keeper Laser Dome](https://domekeeper.wiki.gg/wiki/Laser_Dome) — A reference for the weapon and upgrades used by the currently supported Engineer and Laser Dome setup.
- [Dome Keeper Relic Hunt](https://domekeeper.wiki.gg/wiki/Relic_Hunt#Bedrock) — A guide to Relic Hunt progression, victory, and bedrock boundaries relevant to planned completion support and current exploration behavior.
- [Dome Keeper Caves](https://domekeeper.wiki.gg/wiki/Caves) — A supplemental community overview of ordinary and special Cave rewards; target-version recovered scenes and runtime recordings remain authoritative for implementation.
- [Dome Keeper X-ray Cave](https://domekeeper.wiki.gg/wiki/X-ray_Cave) — A supplemental description of the two-iron Scanner Cave and its reveal-distance reward, used alongside the recovered target-version lifecycle.

## Game AI Architecture

- [The AI Systems of Left 4 Dead](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) — Michael Booth's Valve presentation describing the `Continue`, `ChangeTo`, `SuspendFor`, and `Done` Action transitions, including suspended Action resumption and reason strings for runtime debugging; it is the design reference for the teacher's interruptible task stack.
- [Source SDK 2013: `NextBotBehavior.h`](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/NextBotBehavior.h) — Valve's public NextBot Action and Behavior implementation, used as the upstream code reference for stack-based task suspension, completion, and resumption without retaining a separate top-level state machine.

## Mod Development and Godot 4.3

- [Dome Keeper Mods: Getting Started](https://github.com/DomeKeeperMods/Docs/wiki/Getting-Started) — The official environment setup guide used to define this repository's Dome Keeper modding workflow.
- [Dome Keeper Mods: Your First Mod](https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod) — The official introductory guide for the mod structure and loading conventions used by this project.
- [Dome Keeper Mods: Game Investigation](https://github.com/DomeKeeperMods/Docs/wiki/Game-Investigation) — The official guide used when inspecting scenes, nodes, and version-specific game APIs.
- [Dome Keeper Mods Editor 5.1](https://github.com/DomeKeeperMods/Docs/releases/tag/5.1) — The pinned custom Godot editor release required to work with the target Dome Keeper version.
- [Godot Mod Loader: Mod Structure](https://wiki.godotmodding.com/guides/modding/mod_structure/) — The directory-layout guide behind this repository's author-and-mod-name folder convention.
- [Godot Mod Loader: Script Extensions](https://wiki.godotmodding.com/guides/modding/script_extensions/) — The extension guide used to evaluate when game behavior should be extended through the mod loader.
- [Godot Mod Loader: `extend_scene`](https://wiki.godotmodding.com/api/mod_loader_mod/#void-extend_scene-scene_vanilla_path-string-edit_callable-callable-static) — The scene-extension API used to distinguish static scene extensions from runtime node integration.
- [GDRETools](https://github.com/GDRETools/gdsdecomp) — The upstream recovery toolkit used by the repository's local decompilation workflow.
- [Godot 4.3 Introduction](https://docs.godotengine.org/en/4.3/about/introduction.html) — An overview of the engine version underlying the custom Dome Keeper modding editor.
- [Godot 4.3: `AStar2D.get_point_path`](https://docs.godotengine.org/en/4.3/classes/class_astar2d.html#class-astar2d-method-get-point-path) — The path-query API used for open-tile navigation, returns, work resumption, and frontier selection.
- [Godot 4.3: `Area2D.area_entered`](https://docs.godotengine.org/en/4.3/classes/class_area2d.html#class-area2d-signal-area-entered) — The overlap-entry signal underlying the Power Core chamber's physical water receiver, which requires the carried Drop to cross the receiver area rather than merely approach it.
- [Godot 4.3: `BaseButton.pressed`](https://docs.godotengine.org/en/4.3/classes/class_basebutton.html#signal-basebutton-pressed) — The button signal used by the pause-menu control that starts and stops data collection.
- [Godot 4.3: `Engine.get_process_frames`](https://docs.godotengine.org/en/4.3/classes/class_engine.html#class-engine-method-get-process-frames) — The frame counter used as the synchronization clock for Movie Maker recordings and replay snapshots.
- [Godot 4.3: FileAccess](https://docs.godotengine.org/en/4.3/classes/class_fileaccess.html) — The file API used to write live status data and append and flush event-driven replay records.
- [Godot 4.3: Image](https://docs.godotengine.org/en/4.3/classes/class_image.html) — The image API used for captured-frame processing and YOLO-compatible letterboxing.
- [Godot 4.3: `Input.parse_input_event`](https://docs.godotengine.org/en/4.3/classes/class_input.html#class-input-method-parse-input-event) — The in-process event API used to emit normal configured gameplay and UI actions.
- [Godot 4.3: Input MouseMode](https://docs.godotengine.org/en/4.3/classes/class_input.html#enum-input-mousemode) — The mouse-mode reference supporting visible-cursor behavior during background collection.
- [Godot 4.3: InputMap](https://docs.godotengine.org/en/4.3/classes/class_inputmap.html) — The action-mapping API used to honor the game's configured controls instead of hard-coded physical keys.
- [Godot 4.3: JSON](https://docs.godotengine.org/en/4.3/classes/class_json.html) — The serialization API used for complete observer snapshots in replay recordings.
- [Godot 4.3: MovieWriter](https://docs.godotengine.org/en/4.3/classes/class_moviewriter.html) — The video-writer API underlying fixed-frame-rate replay capture.
- [Godot 4.3: `Node.get_meta`](https://docs.godotengine.org/en/4.3/classes/class_node.html#class-node-method-get-meta) — The metadata API used to read controlled runtime information attached to game nodes.
- [Godot 4.3: `OS.get_environment`](https://docs.godotengine.org/en/4.3/classes/class_os.html#class-os-method-get-environment) — The environment API used to resolve the same temporary-directory variables recognized by Node.js.
- [Godot 4.3: RayCast2D](https://docs.godotengine.org/en/4.3/classes/class_raycast2d.html) — The ray-collision API used to confirm that the selected monster is the Laser's first acquired collider.
- [Godot 4.3: `SceneTree.node_added`](https://docs.godotengine.org/en/4.3/classes/class_scenetree.html#signal-scenetree-node-added) — The scene-tree signal used to discover dynamically created pause and upgrade interfaces.
- [Godot 4.3: `SceneTree.quit`](https://docs.godotengine.org/en/4.3/classes/class_scenetree.html#class-scenetree-method-quit) — The normal process-exit API used after the final replay event is flushed so Movie Maker can finalize its output.
- [Godot 4.3: `TileMap.local_to_map`](https://docs.godotengine.org/en/4.3/classes/class_tilemap.html#class-tilemap-method-local-to-map) — The coordinate-conversion API used by mining, navigation, and recovery logic.
- [Godot 4.3: `Window.size`](https://docs.godotengine.org/en/4.3/classes/class_window.html#class-window-property-size) — The actual recording-window dimensions validated against the requested Movie Maker output resolution, independently of the project's scaled logical viewport.
- [Godot 4.3: Creating Movies](https://docs.godotengine.org/en/4.3/tutorials/animation/creating_movies.html) — The Movie Maker guide used for deterministic fixed-frame-rate replay recording.
- [Godot 4.3: Project Organization](https://docs.godotengine.org/en/4.3/tutorials/best_practices/project_organization.html) — The organization guidance consulted when defining responsibility boundaries during teacher cleanup.
- [Godot 4.3: Command-Line Tutorial](https://docs.godotengine.org/en/4.3/tutorials/editor/command_line_tutorial.html) — The command-line reference used for headless validation and Movie Maker launches.
- [Godot 4.3: Input Events](https://docs.godotengine.org/en/4.3/tutorials/inputs/inputevent.html#how-does-it-work) — The input-flow guide supporting normal UI-driven upgrade and modal interaction.
- [Godot 4.3: Physics Introduction](https://docs.godotengine.org/en/4.3/tutorials/physics/physics_introduction.html) — The physics-timing guide behind running active Laser aiming on physics ticks.
- [Godot 4.3: Pausing Games](https://docs.godotengine.org/en/4.3/tutorials/scripting/pausing_games.html) — The pause-behavior guide used to coordinate upgrade menus, combat, and restored station control.
- [Godot 4.3: `CanvasItem.is_visible_in_tree`](https://docs.godotengine.org/en/4.3/classes/class_canvasitem.html#class-canvasitem-method-is-visible-in-tree) — The visibility API used to suspend capture while pause or TechTree overlays are visible.
- [Godot 4.3: `Node.add_to_group`](https://docs.godotengine.org/en/4.3/classes/class_node.html#class-node-method-add-to-group) — The grouping API used to mark dynamically discovered interfaces that should suspend capture.
- [Godot 4.3: `OS.shell_open`](https://docs.godotengine.org/en/4.3/classes/class_os.html#class-os-method-shell-open) — The system-opening API used to reveal the current dataset directory after capture stops.
- [Godot 4.3: ProjectSettings](https://docs.godotengine.org/en/4.3/classes/class_projectsettings.html) — The project-settings reference used when configuring `forward_plus` for the target project on macOS.

## Vision, Datasets, and Experiments

- [Ultralytics YOLO26](https://docs.ultralytics.com/models/yolo26) — Official documentation for the YOLO26 model family, whose YOLO26n variant is the project's MVP detector.
- [Ultralytics Data Collection and Annotation](https://docs.ultralytics.com/guides/data-collection-and-annotation) — Guidance for collecting and labeling images, used to shape the project's gameplay capture and dataset iteration workflow.
- [Ultralytics YOLO Detection Datasets](https://docs.ultralytics.com/datasets/detect) — The detection dataset and `data.yaml` format reference followed by the project's collector and dataset splits.
- [Ultralytics Model Training](https://docs.ultralytics.com/modes/train) — The YOLO training command and configuration reference used for fixed-resolution model training.
- [Ultralytics Model Validation](https://docs.ultralytics.com/modes/val) — The reference for precision, recall, and mAP metrics used to evaluate the project's vision models.
- [Ultralytics Quickstart](https://docs.ultralytics.com/quickstart) — Installation and basic usage documentation for the Python package and `yolo` CLI used by the project's training and export commands.
- [Ultralytics Model Export](https://docs.ultralytics.com/modes/export) — Documentation for exporting models to ONNX, NCNN, OpenVINO, TensorRT, and other formats used by non-Python inference runtimes.
- [Ultralytics End-to-End Object Detection](https://docs.ultralytics.com/guides/end2end-detection) — Documentation for end-to-end detection outputs without external NMS, used to define the default YOLO26 ONNX output contract.
- [Hugging Face Spaces Static HTML SDK](https://huggingface.co/docs/hub/en/spaces-sdks-static) — The static-site SDK used to publish the project's WebGPU playground with `sdk: static`.
- [Hugging Face Spaces Configuration Reference](https://huggingface.co/docs/hub/en/spaces-config-reference) — The README YAML front-matter reference used to define the playground's build command and entry file.
- [Hugging Face Hub Repository Guide](https://huggingface.co/docs/huggingface_hub/guides/repository) — The repository versioning guide used for the project's model and dataset release workflow.
- [Dome Keeper YOLO v0 Model](https://huggingface.co/proj-airi/domekeeper-yolo-v0) — The project's public model repository containing the model card, ONNX artifact, and evaluation material.
- [Dome Keeper YOLO v0 Dataset](https://huggingface.co/datasets/proj-airi/domekeeper-yolo-dataset-v0) — The public dataset repository paired with the v0 model and pinned by the model card.

## Development Toolchain

- [mise Development Tools](https://mise.jdx.dev/dev-tools/) — An overview of mise tool version management, which the project uses to pin repository-wide development tools.
- [mise Tasks](https://mise.jdx.dev/tasks/) — Documentation for defining and running mise tasks, which expose the project's checks, training, and automation entry points.
- [mise Aggressive Activation](https://mise.jdx.dev/configuration/settings.html#activate-aggressive) — Documentation for mise path precedence, used to ensure child-process shebangs resolve to pinned tools.
- [mise Lockfiles](https://mise.jdx.dev/dev-tools/mise-lock.html) — Documentation for `mise.lock`, which the project commits to preserve tool URLs and checksums reproducibly.
- [mise GitHub Backend](https://mise.jdx.dev/dev-tools/backends/github.html) — Documentation for installing assets from GitHub Releases, used to manage the required Dome Keeper Editor build.
- [mise Aqua Backend](https://mise.jdx.dev/dev-tools/backends/aqua.html) — Documentation for mise's Aqua backend, explicitly used to keep uv resolution reproducible.
- [mise Backend Architecture](https://mise.jdx.dev/dev-tools/backend_architecture) — An explanation of mise backend resolution and responsibilities, supporting the project's explicit uv backend choice.
- [mise Environments](https://mise.jdx.dev/environments/) — Documentation for mise-managed environment variables, used for project versions and machine-local decompilation inputs.
- [mise Python](https://mise.jdx.dev/lang/python.html) — Documentation for Python installation and version management through mise, which owns the project interpreter.
- [mise Format Command](https://mise.jdx.dev/cli/fmt.html) — Documentation for `mise fmt`, used to format and validate the project's `mise.toml`.
- [Bun ImportMeta Environment Reference](https://bun.com/reference/globals/ImportMeta) — The `import.meta.env` API reference used by the project's TypeScript scripts to read machine-local inputs.
- [Bun Package Installation](https://bun.sh/docs/pm/cli/install) — Documentation for Bun package installation and lockfiles, which the project uses for JavaScript dependencies and `bun.lock`.
- [Bun TypeScript Runtime](https://bun.sh/docs/runtime/typescript) — Documentation for running TypeScript directly with Bun, used by automation under `scripts/` without a compile step.
- [Node.js Release Schedule](https://nodejs.org/en/about/previous-releases) — The Node.js release and LTS schedule used to select the pinned runtime for npm package executables.
- [Node.js File-System Promises API](https://nodejs.org/api/fs.html#promises-api) — The asynchronous file-system API used by the status dashboard development server to read live snapshots.
- [Node.js OS Temporary Directory](https://nodejs.org/api/os.html#ostmpdir) — Documentation for `os.tmpdir()`, used to align the Godot snapshot location with the Node.js reader.
- [uv Project Management](https://docs.astral.sh/uv/guides/projects/) — Documentation for uv dependencies, lockfiles, and virtual environments, all of which uv owns for this project.
- [uv Python Download Settings](https://docs.astral.sh/uv/reference/settings/#python-downloads) — Documentation for disabling uv-managed Python downloads so mise remains the sole interpreter owner.
- [Antfu ESLint Config](https://github.com/antfu/eslint-config) — The shared ESLint configuration used as the project's baseline ruleset for TypeScript and frontend code.
- [ESLint Flat Configuration Files](https://eslint.org/docs/latest/use/configure/configuration-files) — The official flat-config reference followed by the project's `eslint.config.mjs`.
- [tinyexec](https://www.npmjs.com/package/tinyexec) — A lightweight cross-platform process execution library used by the project's TypeScript automation.

## Web UI and Inference Runtime

- [JSON Lines](https://jsonlines.org/) — The line-delimited JSON format used for append-only replay metadata and events.
- [ONNX Runtime Web Tutorial](https://onnxruntime.ai/docs/tutorials/web/) — Official guidance for loading and running ONNX models in browsers, informing the project's web and Electron inference flow.
- [ONNX Runtime Web JavaScript Setup](https://onnxruntime.ai/docs/get-started/with-javascript/web.html) — Setup and execution-provider documentation for `onnxruntime-web`, which the project runs with WebGPU where supported.
- [MDN: `WorkerNavigator.gpu`](https://developer.mozilla.org/en-US/docs/Web/API/WorkerNavigator/gpu) — The WebGPU API available inside Web Workers, enabling the project to keep inference off the main UI thread.
- [Vue TypeScript Overview](https://vuejs.org/guide/typescript/overview.html) — Official guidance for Vue 3 with TypeScript, the stack used by the project's status dashboard.
- [Vite: `configureServer`](https://vite.dev/guide/api-plugin.html#configureserver) — Documentation for the Vite development-server hook used to expose the project's narrow live-status bridge.
- [AIRI UI](https://www.npmjs.com/package/@proj-airi/ui) — Project AIRI's shared component library, used to keep the status dashboard visually consistent with AIRI.
- [UnoCSS Vite Integration](https://unocss.dev/integrations/vite) — Documentation for integrating UnoCSS with Vite, used for the dashboard's utility classes and shortcuts.
- [MDN: `HTMLMediaElement.currentTime`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/currentTime) — The media position and seeking API used to align replay video with fixed-frame snapshots.
- [MDN: `requestAnimationFrame`](https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame) — The browser frame scheduling API used to queue the next video inference after the current inference completes.
- [MDN: `Date.toISOString`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/toISOString) — The UTC ISO timestamp API used to create readable, sortable recording session directories.
- [Nano ID](https://github.com/ai/nanoid) — The URL-friendly random ID generator used for compact recording session directory suffixes.
