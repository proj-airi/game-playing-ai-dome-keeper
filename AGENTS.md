# AIRI Dome Keeper Plugin

This repository builds the Dome Keeper game-playing integration for Project AIRI.

## Development Quick Start

- Run `mise install`, then `mise run setup`, to install pinned tools and locked dependencies.
- Use `mise.toml` as the executable source of truth and `mise tasks` to discover repository commands. Use mise tasks and pinned tools instead of ambient substitutes.
- After code changes, run `mise run check`; it covers the Godot mod load check, ESLint, and TypeScript/Vue typechecking.
- Before decompiling, launching, or testing Dome Keeper, read [`docs/development.md`](docs/development.md). Decompilation requires an owned local game and configured machine-local inputs; it is not part of unconditional setup.

## Tool Ownership

- Manage Godot, Node.js, .NET, Java, Python, and other repository development tools through mise. Do not depend on ambient installations.
- Pin tool versions in `mise.toml`. When tool configuration changes, update and commit `mise.toml` and `mise.lock` together.
- Bun owns JavaScript and TypeScript dependencies and `bun.lock`; install with Bun and run TypeScript scripts with Bun.
- uv owns Python dependencies, `uv.lock`, and `.venv`; invoke Python tools through uv or mise tasks, not bare `python`, `pip`, or `yolo`. Do not add a second overlapping Python environment manager.
- ESLint uses `@antfu/eslint-config` with the flat `eslint.config.mjs`; treat `mise.toml` as mise-owned configuration and format it with `mise fmt`, not ESLint.
- Use `tinyexec` for TypeScript process execution instead of adding another process wrapper without a confirmed requirement.

## Development Conventions

### JavaScript and TypeScript

- Avoid unnecessary `void` usage to discard promises and unnecessary dynamic imports.
- Return promises directly instead of using `return await` when no adaptation or error-boundary behavior is needed.
- Prefer eta reduction when a wrapper does not adapt arguments, bind context, add control flow, or improve readability.
- Represent state machines with enums instead of string-literal union types.

### General

- Architectural change size is not a constraint; broad refactors are allowed when they produce a smaller, clearer result.
- Keep the final code volume small and easy to understand. Prefer deletion, consolidation, and replacement over adding layers or parallel paths.
- Prefer early returns and early `continue` statements; keep control flow flat.
- Do not add one-line helpers solely to reduce arguments or standardize a log prefix.
- Do not suppress compiler, linter, deprecation, or parse warnings unless a confirmed compatibility target temporarily requires an older API and the modern path is already used where available.
- Use English for agent-facing communication, maintenance notes, and documentation unless the user explicitly requests a non-English artifact.
- Do not use absolute paths in documentation.
- Prefer current stable dependencies.
- When proposing or adopting a technical approach, cite official documentation, the upstream repository, or a relevant community discussion. Record externally sourced project decisions in `docs/references.md`.
- Use sub-agents for independent fact description, deletion review, and build or verification work when practical.

## Source Layout

- Store GDScript mods under `mods/<Author>-<ModName>/`.
- Store Bun-executable TypeScript automation under `scripts/` and expose repository-wide workflows through mise tasks.
- Keep reusable application and package code under the existing `apps/` and `packages/` workspaces.
- Keep decompiled projects under `external/domekeeper-decompiled/<game-version>/` and recordings or datasets in their documented ignored locations.

## Fail-Closed Boundaries

- Wrong external configuration must fail startup; do not silently change, normalize, or replace external input.
- If an upstream dependency, release artifact, manifest, checksum, package-manager record, or native integration is broken or inconsistent, stop and ask the user before changing the dependency boundary.
- Do not add local patches, package overrides, vendored source, forks, alternate URLs, generated shims, or binary artifacts without explicit approval for that exact workaround.
- Unsupported editor or platform combinations must fail instead of falling back to a mismatched build.
- Never commit or distribute the decompiled game, its PCK, or extracted game assets. Keep `external/`, `tmp/`, datasets, recordings, and machine-local links ignored as documented.

## Documentation Workflow

- Keep this root file focused on the first-read development contract, cross-cutting agent instructions, and task-based documentation routes.
- Before changing a subsystem, read only the relevant document listed below.
- When a decision or assumption changes, update its owning document automatically.
- Update `docs/references.md` only when the external reference material changes.
- Prefer reliable workflow automation, using manual steps only as fallback.

## Documentation Map

- Architecture, Agent roles, and runtime boundaries: [`docs/architecture.md`](docs/architecture.md).
- Current rule-teacher behavior and supported gameplay: [`docs/teacher-controller.md`](docs/teacher-controller.md).
- Confirmed maintenance and behavior-correction tasks: [`docs/todo.md`](docs/todo.md).
- Capability milestones, sequencing, and open design decisions: [`docs/roadmap.md`](docs/roadmap.md).
- Detection, datasets, training, inference, playground, and Electron vision integration: [`docs/vision.md`](docs/vision.md).
- Detailed Mod, decompilation, tool rationale, specialized workflows, and planned layout: [`docs/development.md`](docs/development.md).
- Status and replay producer/consumer contract: [`packages/status-dashboard/README.md`](packages/status-dashboard/README.md).
- External sources supporting project decisions: [`docs/references.md`](docs/references.md).

## Cross-Cutting Invariants

- Use the confirmed two-Agent plugin topology beneath AIRI, with Vision feeding both Agents; the Lower Agent implementation remains open.
- Deployed control must use frame-derived information and normal configured game inputs. Privileged teacher state may provide evidence and labels but never authorizes direct game-state mutation.
- In Chinese-facing discussion, translate upstream `Gadget` as “装备” and `Gadget Chamber` as “装备室”; reserve “遗物” and “遗物室” for `Relic` and `Relic Chamber`. Preserve upstream English identifiers in source code and runtime logs.

## Current Priority

- Prove and clean up the supported manually started, single-player Engineer and Laser rule-teacher loop before designing detailed Lower-Agent contracts or selecting its implementation.

## Non-Binding Dreams

- Do not read or apply [`docs/dreams/`](docs/dreams/README.md) during normal project work unless the user explicitly asks about a dream.
- Dream documents must not influence project scope, architecture, priorities, interfaces, dependencies, telemetry, acceptance criteria, or implementation unless the user explicitly promotes a specific proposal through a separate project decision.
- No project milestone is a prerequisite for a dream, and no dream is a prerequisite for a project milestone.

## Verification

- After code changes, run `mise run check`; after documentation-only changes, run focused Markdown, link, and consistency checks.
- After changing a Dome Keeper mod, the `godot:check` dependency inside `mise run check` must pass; do not rely on Godot's process exit code alone.
- Format and validate `mise.toml` with `mise fmt` when changing it.
