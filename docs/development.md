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
- YOLO data collection mod targets Dome Keeper game version 5.0.5.19, Godot 4.3.1, and the official Dome Keeper Editor 5.1 custom build.

## Mod Dev Workflow

- Keep mod source in this repo under `mods/<Author>-<ModName>/`, and link or copy it into the decompiled Godot project at `res://mods-unpacked/<Author>-<ModName>/` for testing.
- Do not use Mod Loader script extensions for base scripts that declare `class_name`; Godot 4 global classes are unsupported by that mechanism. Remove nonessential extensions instead of retaining a known parse failure, and use a script hook only when the behavior is required.
- For editor test runs, use a Mod Loader scene extension to disable `Game.devMode` while selecting the built-in custom-editor Level entry in memory. This keeps direct-to-level startup without development resources or disabled monster waves, does not persist editor configuration, and leaves retail startup unchanged.
- Run `mise run godot:check` after changing a Dome Keeper mod. The task starts the target project headlessly with an isolated temporary user-data directory, fails when a repository mod script reports a parse/load error or the YOLO collector does not enter the scene tree, and ignores known decompiled-project errors outside the repository mod boundary. Keep it in the aggregate `mise run check` task because Godot may exit successfully even after reporting a GDScript parse error.
- Add a pause-menu toggle that starts/stops collection; the collector owns this integration and injects the button when `SceneTree.node_added` reports a PauseMenu instance, avoiding a script extension of the game's preloaded PauseMenu. During an ordinary launch the toggle starts the teacher and creates `user://yolo_data/session_<timestamp>/` with `images/` and `labels/`, saving screenshots + YOLO labels at a fixed interval using object-tree queries. A repository Movie Maker recording instead waits for the supported run's Keeper input to become active, automatically starts only the teacher and replay, records the authoritative `game.over` outcome, flushes the JSONL, and normally exits Godot so unsettled YOLO label choices do not add capture work. In that explicitly configured recording process, extend the game's non-`class_name` Options script so its persisted fullscreen preference cannot override the command's initial windowed `1280x720` Movie Maker resolution; do not rewrite the saved preference or change ordinary launches.
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
- The decompile script uses GDRETools CLI (`gdre_tools --headless --recover=... --output=...`) for one-step recovery, then links all repo mods under `mods/` into the decompiled `mods-unpacked/` directory.
- Decompile script machine-local inputs are provided through `DOMEKEEPER_GAME_DIR`, `GDRETOOLS_BIN`, and optional `DOMEKEEPER_OUT_ROOT`, read via `import.meta.env`; mise provides the repository-owned `DOMEKEEPER_VERSION`. Godot tasks use the mise-managed editor and must not require a user-supplied `GODOT_BIN`.
- For macOS stability, set the project rendering method to `forward_plus` in `project.godot` (rendering/renderer/rendering_method).

## Repo Structure

- Store each GDScript mod under `mods/<Author>-<ModName>/` (not under `crates/`).

## Tooling

- Use mise as the repository-level development-tool manager and task entry point. Pin tool versions in `mise.toml`; mise tasks delegate dependency-specific work to the owning package manager. Pin an LTS Node.js runtime because npm package executables such as ESLint and TypeScript use Node shebangs even when Bun launches their package scripts. Keep mise tool paths ahead of ambient package-manager paths so child-process shebangs resolve the pinned tools.
- Enable mise lockfiles, commit `mise.lock`, and run `mise lock` whenever tool configuration changes so tool URLs and supported checksums remain reproducible. Commit `mise.toml` and `mise.lock` together.
- Use Bun for JavaScript dependency installation and lockfile management. Keep `package.json` and `bun.lock`, and run TypeScript scripts with Bun.

## Linting

- Use ESLint with `@antfu/eslint-config` and the flat config (`eslint.config.mjs`).
- Treat `mise.toml` as mise-owned configuration: format and validate it with `mise fmt`, and exclude it from ESLint's conflicting TOML formatting rules.

## Exec Utilities

- Prefer minimal, actively maintained process-exec libraries when available. For this repo, use `tinyexec` as the lightweight command runner.

## Python Environment

- Use mise to pin the Python and uv executables. Use the explicit `aqua:astral-sh/uv` backend so local legacy plugins cannot change uv resolution or weaken `mise.lock` metadata. Use uv as the sole owner of Python dependencies, `uv.lock`, and `.venv`; do not also create a mise-managed virtual environment or add Pixi for the same environment. Bind uv to mise's Python and disable uv-managed Python downloads so the interpreter has one owner.
- Reconsider Pixi only if a confirmed requirement needs Conda-native system packages or independently solved accelerator environments; if adopted, Pixi must own Python and the complete environment rather than overlap with mise Python or uv.

## Scripts Convention

- `scripts/` should contain TypeScript scripts executable directly via Bun. Expose shared workflow entry points through mise tasks when repository-level orchestration is useful.

## Planned Monorepo Structure

The listed application and crate paths are reserved target locations unless they already contain implemented project code.
- `apps/airi-plugin/` for the AIRI plugin (TypeScript + Bun).
- `crates/capture/` for Rust performance-sensitive modules (capture/input/inference helpers).
- `mods/<Author>-<ModName>/` for the GDScript mod (auto-labeling/metadata export).
- `packages/shared/` for shared types/protocols/schema.
- `packages/status-dashboard/` for the local Vue status observer.
- `scripts/` for Bun-executable TypeScript automation scripts.
- `data/` for datasets and labels, and `recordings/` for replay sessions (both ignored by git).
