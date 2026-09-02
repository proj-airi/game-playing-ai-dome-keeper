# Architecture

This document describes repository-level components and their relationships.
Each component owns its internal architecture in its own documentation.

## Current Repository Topology

```mermaid
flowchart LR
  dataCollector[DataCollectorAI Mod] -->|generated GDScript| project[Editable Dome Keeper project]
  tests[Mod-owned tests] --> viKeeper[ViKeeper]
  viKeeper --> viDot[ViDot]
  viDot --> project
  artifacts[Existing local status and replay artifacts] --> dashboard[Status dashboard]
```

| Component | Responsibility | Relationship |
| --- | --- | --- |
| `mods/LemonNekoGH-DataCollectorAI` | Active TypeScript-authored Dome Keeper Mod. | Generates the GDScript loaded by an editable Dome Keeper project. Its tests use ViKeeper. |
| `packages/vikeeper` | Dome Keeper-specific ViDot integration. | Supplies project launch policy to Mod-owned tests and composes ViDot. |
| `packages/vidot` | Generic Godot test runner. | Runs tests inside the explicitly configured editable Godot project. |
| `packages/status-dashboard` | Local observer for existing status and replay artifacts. | Has no active live or replay producer while the legacy collector is disabled. |
| `mods/LemonNekoGH-YoloDataCollector` | Retained legacy collector and rule teacher source. | Is not linked into current editable projects or workflows. |

The DataCollectorAI Mod owns its runtime design in its
[README](../mods/LemonNekoGH-DataCollectorAI/README.md). ViDot and ViKeeper own
their testing contracts in [ViDot](vidot.md) and their package READMEs.

## Target Runtime Topology

```mermaid
flowchart LR
  airi[AIRI] -->|start, update, stop, and query| keeper[Keeper Runtime]
  keeper -->|whole-run task and context| upper[Upper LLM Agent]
  upper -->|status summary| keeper
  keeper -->|status| airi
  game[Game] --> vision[Vision]
  vision -->|queried world and task status| upper
  vision --> lower[Lower Agent]
  lower -->|queried task state| upper
  upper -->|start and replace current task| lower
  lower -->|operating-system input| game
  keeper -->|launch and close| game
```

The AIRI host owns user intent, AIRI memory, and the whole-run gameplay task.
The Keeper runtime executes lifecycle requests, reports status to AIRI, and
runs a continuous tool-calling Upper LLM Agent. Each Upper iteration queries
the current game and Lower state, performs inference, and can replace the
current Lower task. The next iteration starts without a separate polling
interval or a Lower completion wake-up.

Each game instance has at most one active Lower task. A replacement invalidates
the old task-instance identifier, releases its held input, and clears unapplied
actions before the new task starts. The Lower Agent runs outside the game and
controls it through operating-system keyboard and mouse input.

Vision supplies frame-derived state to both Agents. The Upper Agent queries
YOLO-derived world state and task status. The Lower Agent uses recent visual
evidence. Only the Upper Agent decides whether to replace a task. The command
representation, state projection, task-status method, and Lower implementation
remain open.

Vision and model/dataset work are owned by [vision.md](vision.md). The future
AIRI plugin boundary is tracked by [roadmap.md](roadmap.md). The runtime role
decision is [ADR-0004](decisions/0004-adopt-a-multi-timescale-gameplay-agent.md).
