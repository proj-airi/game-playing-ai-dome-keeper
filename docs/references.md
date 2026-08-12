# References

This page collects external resources useful for understanding and maintaining the AIRI Dome Keeper plugin. Each entry explains what the resource is and how it relates to this project.

## Project and Game

- [Project AIRI](https://github.com/moeru-ai/airi) — The main Project AIRI repository; this project is a Dome Keeper plugin for AIRI.
- [Project AIRI v0.10.0 Release](https://github.com/moeru-ai/airi/releases/tag/v0.10.0) — The upstream release that introduced the current plugin manifest and Kits, Bindings, Tools, and Gamelet APIs relevant to defining this project's future AIRI integration boundary.
- [Dome Keeper Engineer](https://domekeeper.wiki.gg/wiki/Engineer) — A gameplay reference for the Engineer's drilling, carrying, controls, and upgrades used by the teacher.
- [Dome Keeper Laser Dome](https://domekeeper.wiki.gg/wiki/Laser_Dome) — A reference for the weapon and upgrades used by the currently supported Engineer and Laser Dome setup.
- [Dome Keeper Relic Hunt](https://domekeeper.wiki.gg/wiki/Relic_Hunt#Bedrock) — A guide to Relic Hunt progression, victory, and bedrock boundaries relevant to planned completion support and current exploration behavior.
- [Dome Keeper Technical Terms](https://domekeeper.wiki.gg/wiki/Technical_Terms#Run_Weight_in_Relic_Hunt) — Community documentation of gameplay terms, including the Relic Hunt run weight (a base value plus contributions from resources and Gadgets); used to corroborate the locally recovered observation that accumulated mining raises later wave pressure.
- [Dome Keeper Caves](https://domekeeper.wiki.gg/wiki/Caves) — A supplemental community overview of ordinary and special Cave rewards; target-version recovered scenes and runtime recordings remain authoritative for implementation.
- [Dome Keeper X-ray Cave](https://domekeeper.wiki.gg/wiki/X-ray_Cave) — A supplemental description of the two-iron Scanner Cave and its reveal-distance reward, used alongside the recovered target-version lifecycle.

## Game AI Architecture

- [The AI Systems of Left 4 Dead](https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) — Michael Booth's Valve presentation describing the `Continue`, `ChangeTo`, `SuspendFor`, and `Done` Action transitions, including suspended Action resumption and reason strings for runtime debugging; it is the design reference for the teacher's interruptible task stack.
- [Source SDK 2013: `NextBotBehavior.h`](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/NextBotBehavior.h) — Valve's public NextBot Action and Behavior implementation, used as the upstream code reference for stack-based task suspension, completion, and resumption without retaining a separate top-level state machine.
- [SHOP / SHOP2](https://www.cs.umd.edu/projects/shop/description.html) — The University of Maryland description of ordered Hierarchical Task Network planning, where methods decompose nonprimitive tasks into subtasks when their preconditions are satisfied; this is a conceptual reference for the recursive `TaskExecutor`, not a claim that the project implements formal HTN planning.

## Godot Testing and Automation

- [Vitest](https://vitest.dev/) — The test runner that owns ViDot's collection, filtering, watch mode, scheduling, assertions, and reporting.
- [Vitest: Test Context](https://vitest.dev/guide/test-context) — The file-scoped fixture API that lets `@vidot/vitest` own one Godot process per test file without exposing lifecycle hooks to tests.
- [Vitest: Configuration](https://vitest.dev/config/) — The configuration boundary through which a project enables ViDot without a separate ViDot CLI or configuration file.
- [Vitest: Global Setup](https://vitest.dev/config/globalsetup) — The once-per-test-session boundary used to provide ViDot's validated launch configuration before test workers start.
- [Vitest: Reporters](https://vitest.dev/guide/reporters) — The native result and reporting system reused by ViDot.
- [Vieval](https://github.com/vieval-dev/vieval) — A test-evaluation runner reviewed as prior art; its independent CLI and configuration are unnecessary because ViDot delegates runner responsibilities to Vitest.
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification) — The request, response, error, and notification model used as the basis for ViDot's small JSON-RPC-like WebSocket protocol.
- [Godot 4.3: Autoloads Versus Regular Nodes](https://docs.godotengine.org/en/4.3/tutorials/scripting/singletons_autoload.html) — The engine facility used to load ViDot's temporary bridge runtime before project scenes.
- [Godot 4.3: WebSocketPeer](https://docs.godotengine.org/en/4.3/classes/class_websocketpeer.html) — The WebSocket peer API used by the ViDot Autoload, including its required polling model.
- [Godot 4.3: TCPServer](https://docs.godotengine.org/en/4.3/classes/class_tcpserver.html) — The loopback server accepted by `WebSocketPeer` for ViDot's single-client bridge.
- [Godot source: `TCPServer::listen`](https://github.com/godotengine/godot/blob/77dcf97d82cbfe4e4615475fa52ca03da645dbd8/core/io/tcp_server.cpp#L530-L586) — The upstream implementation supporting port `0` for an OS-selected ephemeral ViDot port.
- [Godot 4.3: Object](https://docs.godotengine.org/en/4.3/classes/class_object.html) — The dynamic property, method, and signal APIs behind ViDot's `get`, `set`, `call`, and `waitForSignal` commands; Godot exposes property-list changes but no universal property-value change signal.
- [Godot 4.3: GDScript VM member storage](https://github.com/godotengine/godot/blob/77dcf97d82cbfe4e4615475fa52ca03da645dbd8/modules/gdscript/gdscript_vm.cpp#L678-L681) — The upstream implementation showing direct script-member storage, which rules out a complete property-change observer implemented only around `Object.set` and motivates bounded observation of active `waitForProperty` requests.

## Mod Development and Godot 4.3

- [Dome Keeper Mods: Getting Started](https://github.com/DomeKeeperMods/Docs/wiki/Getting-Started) — The official environment setup guide used to define this repository's Dome Keeper modding workflow.
- [Dome Keeper Mods: Your First Mod](https://github.com/DomeKeeperMods/Docs/wiki/Your-first-Mod) — The official introductory guide for the mod structure and loading conventions used by this project.
- [Dome Keeper Mods: Game Investigation](https://github.com/DomeKeeperMods/Docs/wiki/Game-Investigation) — The official guide used when inspecting scenes, nodes, and version-specific game APIs.
- [Dome Keeper Mods Editor 5.1](https://github.com/DomeKeeperMods/Docs/releases/tag/5.1) — The pinned custom Godot editor release required to work with the target Dome Keeper version.
- [Godot Mod Loader: Mod Structure](https://wiki.godotmodding.com/guides/modding/mod_structure/) — The directory-layout guide behind this repository's author-and-mod-name folder convention.
- [Godot Mod Loader: Mod Files](https://wiki.godotmodding.com/guides/modding/mod_files/) — The manifest contract used by ViKeeper to identify the tested Mod while leaving game-version compatibility to Mod Loader.
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
- [Godot 4.3: PackedScene](https://docs.godotengine.org/en/4.3/classes/class_packedscene.html) — The target engine's serialized scene resource used for the repository-owned Move test scene and map.
- [Godot 4.3: TileMap](https://docs.godotengine.org/en/4.3/classes/class_tilemap.html) — The target engine's multi-layer tile API underlying Dome Keeper 5.0.5.19's `MapData` methods; the newer replacement API is outside this pinned game boundary.
- [Godot 4.3: `Node.get_meta`](https://docs.godotengine.org/en/4.3/classes/class_node.html#class-node-method-get-meta) — The metadata API used to read controlled runtime information attached to game nodes.
- [Godot 4.3: `OS.get_environment`](https://docs.godotengine.org/en/4.3/classes/class_os.html#class-os-method-get-environment) — The environment API used to resolve the same temporary-directory variables recognized by Node.js.
- [Godot 4.3: RayCast2D](https://docs.godotengine.org/en/4.3/classes/class_raycast2d.html) — The ray-collision API used to confirm that the selected monster is the Laser's first acquired collider.
- [Godot 4.3: `SceneTree.node_added`](https://docs.godotengine.org/en/4.3/classes/class_scenetree.html#signal-scenetree-node-added) — The scene-tree signal used to discover dynamically created pause and upgrade interfaces.
- [Godot 4.3: `SceneTree.quit`](https://docs.godotengine.org/en/4.3/classes/class_scenetree.html#class-scenetree-method-quit) — The normal process-exit API used after the final replay event is flushed so Movie Maker can finalize its output.
- [Godot 4.3: `TileMap.local_to_map`](https://docs.godotengine.org/en/4.3/classes/class_tilemap.html#class-tilemap-method-local-to-map) — The coordinate-conversion API used by mining, navigation, and recovery logic.
- [Godot 4.3: `Window.Mode`](https://docs.godotengine.org/en/4.3/classes/class_window.html#enum-window-mode) — The runtime window-mode contract used to require a decorated Movie Maker window after Dome Keeper loads its options.
- [Godot 4.3: Creating Movies](https://docs.godotengine.org/en/4.3/tutorials/animation/creating_movies.html) — The Movie Maker guide used for deterministic fixed-frame-rate replay recording.
- [Godot 4.3: Project Organization](https://docs.godotengine.org/en/4.3/tutorials/best_practices/project_organization.html) — The organization guidance consulted when defining responsibility boundaries during teacher cleanup.
- [Godot 4.3: Command-Line Tutorial](https://docs.godotengine.org/en/4.3/tutorials/editor/command_line_tutorial.html) — The command-line reference used for headless validation and Movie Maker launches.
- [Godot 4.3: Input Events](https://docs.godotengine.org/en/4.3/tutorials/inputs/inputevent.html#how-does-it-work) — The input-flow guide supporting normal UI-driven upgrade and modal interaction.
- [Godot 4.3: Physics Introduction](https://docs.godotengine.org/en/4.3/tutorials/physics/physics_introduction.html) — The physics-timing guide behind running active Laser aiming on physics ticks.
- [Godot 4.3: Pausing Games](https://docs.godotengine.org/en/4.3/tutorials/scripting/pausing_games.html) — The pause-behavior guide used to coordinate upgrade menus, combat, and restored station control.
- [Godot 4.3: `CanvasItem.is_visible_in_tree`](https://docs.godotengine.org/en/4.3/classes/class_canvasitem.html#class-canvasitem-method-is-visible-in-tree) — The visibility API used to suspend capture while pause or TechTree overlays are visible.
- [Godot 4.3: `Node.add_to_group`](https://docs.godotengine.org/en/4.3/classes/class_node.html#class-node-method-add-to-group) — The grouping API used to mark dynamically discovered interfaces that should suspend capture.
- [Godot 4.3: `OS.shell_open`](https://docs.godotengine.org/en/4.3/classes/class_os.html#class-os-method-shell-open) — The system-opening API used to reveal the current dataset directory after capture stops.
- [Godot 4.3: ProjectSettings](https://docs.godotengine.org/en/4.3/classes/class_projectsettings.html) — The project-settings reference used for target rendering configuration and per-process custom `user://` isolation.
- [Godot 4.3: `OS.get_user_data_dir`](https://docs.godotengine.org/en/4.3/classes/class_os.html#class-os-method-get-user-data-dir) — The runtime path query used to fail closed unless a ViDot process received its expected isolated user-data directory.

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
- [typescript-to-gdscript](https://github.com/nnn3d/typescript-to-gdscript) — The converter used by `LemonNekoGH-DataCollectorAI` and ViDot to author Godot-compatible code in TypeScript and emit runtime GDScript.
- [typescript-to-gdscript Configuration](https://github.com/nnn3d/typescript-to-gdscript/blob/master/docs/configuration.md) — The compiler and Godot-typings configuration used for ViDot's TypeScript-authored Autoload.
- [typescript-to-gdscript Transform Rules](https://github.com/nnn3d/typescript-to-gdscript/blob/master/docs/transform-rules.md) — The documented TypeScript-to-GDScript transform boundary used alongside direct target-Godot validation.
- [Node.js Release Schedule](https://nodejs.org/en/about/previous-releases) — The Node.js release and LTS schedule used to select the pinned runtime for npm package executables.
- [Node.js File-System Promises API](https://nodejs.org/api/fs.html#promises-api) — The asynchronous file-system API used by the status dashboard development server to read live snapshots.
- [Node.js OS Temporary Directory](https://nodejs.org/api/os.html#ostmpdir) — Documentation for `os.tmpdir()`, used to align the Godot snapshot location with the Node.js reader.
- [uv Project Management](https://docs.astral.sh/uv/guides/projects/) — Documentation for uv dependencies, lockfiles, and virtual environments, all of which uv owns for this project.
- [uv Python Download Settings](https://docs.astral.sh/uv/reference/settings/#python-downloads) — Documentation for disabling uv-managed Python downloads so mise remains the sole interpreter owner.
- [Antfu ESLint Config](https://github.com/antfu/eslint-config) — The shared ESLint configuration used as the project's baseline ruleset for TypeScript and frontend code.
- [ESLint Flat Configuration Files](https://eslint.org/docs/latest/use/configure/configuration-files) — The official flat-config reference followed by the project's `eslint.config.mjs`.
- [Execa](https://github.com/sindresorhus/execa) — The process execution library used by the project's TypeScript automation and ViDot process lifecycle.
- [Execa Termination](https://github.com/sindresorhus/execa/blob/v10.0.1/docs/termination.md) — The graceful and forceful termination behavior used to bound ViDot process cleanup.

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
