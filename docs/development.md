# Development

The root `AGENTS.md` owns the stable first-read development contract. This
document owns detailed Dome Keeper Mod workflows, decompilation, tool rationale,
specialized configuration, and planned repository layout. Read the Vision
document as well when changing frame collection or inference integration.

Imperative statements in this document are current binding project decisions
unless explicitly marked as planned, future, or historical.

## Modding Notes

- Dome Keeper mods use the GDScript Mod Loader and require decompiling/importing the game into Godot, then placing mods under `res://mods-unpacked/Author-ModName` with `manifest.json` and `mod_main.gd`.
- The modding wiki recommends reviewing Mod Loader docs and proceeding to "Game Investigation" after the first mod setup.
- The retained YOLO data collection and rule-teacher source targets Dome Keeper game version 5.0.5.19, Godot 4.3.1, and the official Dome Keeper Editor 5.1 custom build, but that legacy Mod is currently disabled.
- `LemonNekoGH-DataCollectorAI` is the replacement TypeScript-authored Godot mod. Its source lives in `src/`; `tstogd convert` emits the loadable GDScript into `scripts/`, while the mod manifest remains tracked there. The generated GDScript is ignored. Its structure is divided into a planner, task executor, and `Quark Action` executor, replacing the old YOLO collector and rule-teacher organization.

## Mod Dev Workflow

- Keep mod source in this repo under `mods/<Author>-<ModName>/`. The decompile workflow links only the active TypeScript-authored DataCollectorAI Mod and removes an existing repository-owned legacy YOLO Mod link. DataCollectorAI's loadable root is its generated `scripts/` directory because that directory contains the runtime GDScript and manifest. The decompile, Godot open, and Godot check tasks own the required production build. The separate `packages/vikeeper/` package retains Dome Keeper-only test-scene assets outside the production Mod. Its former RPC harness has been removed, and no current workflow installs or launches those assets.
- Do not use Mod Loader script extensions for base scripts that declare `class_name`; Godot 4 global classes are unsupported by that mechanism. Remove nonessential extensions instead of retaining a known parse failure, and use a script hook only when the behavior is required.
- The retained ViKeeper Move fixture selects the built-in single-player Engineer and Laser configuration, constructs the smallest required map through Dome Keeper's `MapData` methods before the landing stage can start procedural generation, and instantiates the ordinary game scene without adding test behavior to the production controller. The map has one entry and only the bounded open space needed for one adjacent-tile Move. The old loopback WebSocket RPC execution path has been deliberately removed, so this fixture is currently non-runnable. Reconnect it through the pending Godot-native adapter; the game's Mod Loader must continue to own manifest compatibility validation. This direct scene construction remains temporary until ViKeeper's planned shared map-definition DSL owns test maps; do not commit serialized TileMap cell arrays as test definitions.
- The Godot-native ViDot target keeps the base game and tested Mod as separate inputs. Users or game-specific wrappers define how their application components join startup; generic ViDot does not define Mod packaging or loading. ViKeeper is the first wrapper and accepts the DataCollectorAI Mod project, then prepares the Dome Keeper-specific startup for either target form without permanently modifying the project, PCK, or installed game. Dome Keeper's Mod Loader remains responsible for manifest validation and loading.
- Run `mise run godot:check` after changing a Dome Keeper mod. The task starts the target project headlessly inside its own project and user-data sandbox, requires DataCollectorAI to enter the scene tree, fails if the legacy YOLO Mod is discovered, and ignores known decompiled-project errors outside the active Mod boundary. Build TypeScript-authored mods before this check. Keep the load check in the aggregate `mise run check` task because Godot may exit successfully even after reporting a GDScript parse error. There is no active ViDot gameplay test until the Godot-native adapter reconnects the retained fixtures.
- The legacy pause-menu collector, rule teacher, replay producer, checkpoints, and status-dashboard producer remain in source for reference but have no active repository task while `LemonNekoGH-YoloDataCollector` is disabled.

## Legacy Collector Reference (Inactive)

The following contracts describe retained legacy source. They are not active
development workflows while the YOLO Mod is disabled.

- Pass `--save` to the recording task to create a named debug checkpoint after every fully settled wave. Each ID is `<recording-session-id>_wave_<completed-wave-count>` and names a `user://` folder containing the game's official slot-zero save files plus `teacher.json`. Pass an ID unchanged through `--load <ID>` to load the official save, restore the teacher sidecar, and begin a new recording; combine both flags to continue creating checkpoints under the new recording session ID. Missing or malformed saves fail startup instead of falling back to a new run.
- Pass `--seed <integer>` to start a new recording with the game's normal `Level.setSeed` path. This is intended for reproducible behavior checks; it does not apply when loading a checkpoint.
- On session start, create a `data.yaml` alongside `images/` and `labels/` with YOLO dataset fields (`path`, `train`, `val`, `names`) for the captured classes.
- On session stop, open the capture folder in the OS file manager using Godot's `OS.shell_open`.
- Pause capture while the pause menu is visible by having the collector tag the dynamically observed menu panel with a group and check `CanvasItem.is_visible_in_tree()`.
- Pause capture while the upgrade popup (TechTree) is visible by tagging `TechTreePopup` with the same group and checking visibility from the collector.
- Capture frames are letterboxed to `640x640` with gray padding, and labels are transformed to match the padded image.
- Split each capture session into `train/val/test` by consecutive blocks of exactly 60 successfully saved image-label pairs, cycling blocks `4/1/1` as train, train, train, train, val, test. Compute the block from the accepted saved-image index after pause/overlay and target-balance rejection; a rejected capture advances neither the saved counter nor the block. Write paired files to `images/{split}` and `labels/{split}` and set `data.yaml` accordingly.
- Treat frames as having a target only when `enemy` or `ore_*` classes are present; allow one no-target frame only after 5 target frames have been captured.
- Collect every active dome returned by the current game's `Level.getDomes()` API rather than the removed single-dome `Level.dome` property, so labels also cover multiplayer and versus runs. Verify game-facing APIs against the recovered target version during each version migration.

## Decompiled Project Layout

- Store decompiled Godot projects under `external/domekeeper-decompiled/<game-version>/` (version-isolated).
- Link the repo mod source into each decompiled project at `external/domekeeper-decompiled/<game-version>/mods-unpacked/<Author>-<ModName>/` for testing.

## Modding EULA & Repo Hygiene

- Modding rules explicitly forbid distributing the decompiled project (including the `.pck`) and require that shared mod source contains only modded files, not original game files; they also recommend using a `.gitignore` to enforce this.
- Keep `tmp/` ignored because it may contain a machine-local link to the owned game PCK; never commit the link target or game contents.

## Decompile Script

- It is acceptable to commit a local decompilation script as long as it does not include or distribute any game assets or decompiled outputs, and only operates on the user's local installation.
- Manage the required official Dome Keeper Editor with mise's GitHub backend. For the repository's Dome Keeper 5.0.5.19 target, pin editor release 5.1, a custom Godot 4.3.1 build containing the multiplayer modules used by the 5.0 update. Select exact editor assets and published SHA-256 digests for macOS arm64/x64, Linux x64, and Windows x64; unsupported architectures must fail instead of falling back to a mismatched artifact. Do not substitute a regular Godot or generic GodotSteam build, and keep the complete extracted bundle so its native Steam and multiplayer libraries remain beside the editor.
- The decompile script uses GDRETools CLI (`gdre_tools --headless --recover=... --output=...`) for one-step recovery, then links DataCollectorAI into the decompiled `mods-unpacked/` directory. It removes only an exact repository-owned `LemonNekoGH-YoloDataCollector` symlink and fails on an unexpected target. The mise task builds DataCollectorAI before the script installs its generated root.
- Decompile script machine-local inputs are provided through `DOMEKEEPER_GAME_DIR`, `GDRETOOLS_BIN`, and optional `DOMEKEEPER_OUT_ROOT`, read via `process.env`; mise provides the repository-owned `DOMEKEEPER_VERSION`. Godot tasks use the mise-managed editor and must not require a user-supplied `GODOT_BIN`.
- For macOS stability, set the project rendering method to `forward_plus` in `project.godot` (rendering/renderer/rendering_method).

## Repo Structure

- Keep the disabled GDScript collector and teacher source under `mods/LemonNekoGH-YoloDataCollector/` as a migration reference; do not install it into active decompiled projects.
- Store the replacement TypeScript-authored Godot AI mod under `mods/LemonNekoGH-DataCollectorAI/`; keep TypeScript source in `src/` and generated GDScript in `scripts/`.
- Store reusable Dome Keeper test infrastructure under `packages/vikeeper/`; keep generic Godot automation under `packages/vidot/`.
- Do not put Godot mods under `crates/`.

## Tooling

- Use mise as the repository-level development-tool manager and task entry point. Pin Node.js and pnpm in `mise.toml`; mise tasks delegate dependency-specific work to pnpm. Keep mise tool paths ahead of ambient package-manager paths so child-process shebangs resolve the pinned tools.
- Enable mise lockfiles, commit `mise.lock`, and run `mise lock` whenever tool configuration changes so tool URLs and supported checksums remain reproducible. Commit `mise.toml` and `mise.lock` together.
- Use pnpm for JavaScript dependency installation and lockfile management. Keep `pnpm-workspace.yaml`, package manifests, and `pnpm-lock.yaml` together. Execute repository automation under `scripts/` directly with the pinned Node.js runtime.
- The root pnpm workspace includes `apps/*`, `packages/*`, and `mods/*`. Use `pnpm run build` to build every workspace that exposes a build script; this currently includes the TypeScript-to-GDScript AI mod and the status dashboard.
- Keep dependency build scripts fail-closed through pnpm's `allowBuilds`. Approve only the reviewed Tree-sitter native bindings required by `typescript-to-gdscript`; explicitly deny optional install-time rewrites that the resolved runtime does not need.
- Keep pnpm's trust-downgrade policy enabled. Exclude only `chokidar@4.0.3`, the `typescript-to-gdscript` file-watcher dependency already present with the same integrity in the previous lockfile, because that release lacks the provenance evidence present on an earlier release.

## Linting

- Use ESLint with `@antfu/eslint-config` and the flat config (`eslint.config.mjs`).
- Use alint with the official `@alint-js/plugin-js` `js/recommended` preset in `alint.config.ts` for model-assisted JavaScript and TypeScript design review. Configure a model provider with `pnpm exec alint setup`, then run the review through `mise run alint`.
- Keep alint separate from the aggregate `mise run check`: it supplements deterministic ESLint rather than replacing it, requires machine-local model configuration, and may consume paid model tokens. Its `.alintcache` output is local-only.
- Treat `mise.toml` as mise-owned configuration: format and validate it with `mise fmt`, and exclude it from ESLint's conflicting TOML formatting rules.

## Exec Utilities

- Use `execa` directly for TypeScript process execution. Prefer its built-in output, error, and termination behavior over local process wrappers.

## Python Environment

- Use mise to pin the Python and uv executables. Use the explicit `aqua:astral-sh/uv` backend so local legacy plugins cannot change uv resolution or weaken `mise.lock` metadata. Use uv as the sole owner of Python dependencies, `uv.lock`, and `.venv`; do not also create a mise-managed virtual environment or add Pixi for the same environment. Bind uv to mise's Python and disable uv-managed Python downloads so the interpreter has one owner.
- Reconsider Pixi only if a confirmed requirement needs Conda-native system packages or independently solved accelerator environments; if adopted, Pixi must own Python and the complete environment rather than overlap with mise Python or uv.

## Scripts Convention

- `scripts/` should contain TypeScript scripts executable directly via Node.js. Keep their runtime syntax within Node.js's erasable TypeScript boundary, and expose shared workflow entry points through mise tasks when repository-level orchestration is useful.

## Planned Monorepo Structure

The listed application and crate paths are reserved target locations unless they already contain implemented project code.
- `apps/airi-plugin/` for the AIRI plugin (TypeScript + Node.js).
- `crates/capture/` for Rust performance-sensitive modules (capture/input/inference helpers).
- `mods/LemonNekoGH-YoloDataCollector/` for the existing GDScript mod (teacher and YOLO auto-labeling).
- `mods/LemonNekoGH-DataCollectorAI/` for the replacement TypeScript-authored AI mod and its generated GDScript.
- `packages/vikeeper/` for Dome Keeper test scenes, mirror-only fixture files, and the future map-definition DSL.
- `packages/shared/` for shared types/protocols/schema.
- `packages/status-dashboard/` for the local Vue status observer.
- `scripts/` for Node.js-executable TypeScript automation scripts.
- `data/` for datasets and labels, and `recordings/` for replay sessions (both ignored by git).
