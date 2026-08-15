# Architecture

This document distinguishes the current implementation from the confirmed
target architecture. The target has two plugin Agent layers, and the Vision
Layer supplies both. The Lower Agent's implementation and the exact observation
and task contracts remain open until the rule teacher provides enough runtime
evidence.

## Project Context

"AIRI" refers to the open-source Project AIRI by `moeru-ai/airi` (web and
desktop), a digital companion and virtual character platform. This repository
implements its Dome Keeper game-playing integration.

## Current Implementation

- `LemonNekoGH-DataCollectorAI` is the only repository Mod loaded by current
  workflows. It is authored in TypeScript and converted to GDScript during the
  build; its first proven runtime slice executes one adjacent-tile Move through
  normal configured input.
- `LemonNekoGH-YoloDataCollector` and its in-process rule teacher are retained
  as dormant behavior and data-collection references. They are not linked into
  newly decompiled projects, and their collection, replay, and dashboard
  producer workflows are inactive.
- Runtime Vision inference does not yet control gameplay.

## Confirmed Target Runtime Architecture

- **AIRI host (outside the two-Agent plugin control loop):** Decides whether to
  start or stop gameplay at low frequency and may pause or terminate gameplay
  based on external context such as time or messages. Manual and test lifecycle
  controls remain necessary. The concrete AIRI plugin API and authority boundary
  are not implemented yet.
- **Plugin Upper Agent (LLM):** Receives Vision-derived game-state summaries and
  produces mid-frequency, high-level gameplay tasks such as explore, mine, or
  return to defend. It also reports concise status to AIRI.
- **Plugin Lower Agent (controller):** Consumes Upper Agent tasks and performs
  near-real-time control through normal configured game input actions based on
  current Vision-derived state. Direct game-state mutation is outside its
  action boundary. Its implementation may be learned, rule-based, hybrid, or
  another controller design; it is not assumed to be a student model.
- **Vision Layer:** Performs frame-derived perception and state estimation and
  supplies both Plugin Agent layers at their respective cadences. The two layers
  may receive different projections or summaries of the same perceived state.
  The exact observations, transformations, and update contracts will be derived
  after the teacher behavior is proven instead of being fixed in advance.

The target information flow is Vision to both Agent layers, Upper Agent tasks
to the Lower Agent, Lower Agent actions to the game, and Upper Agent status to
AIRI.

The TypeScript AI mod is the new implementation direction for the planner, task,
and `Quark Action` execution layers. It will replace the old YOLO collector and
rule teacher as the gameplay mod evolves toward the target Agent architecture.

## Frozen TaskExecutor Design

The TypeScript AI mod uses a recursive hierarchical task-execution design
inspired by Hierarchical Task Networks (HTNs). It borrows the useful concepts of
compound tasks, methods, subtasks, and primitive tasks, but it is not intended to
be a complete HTN planner or a formally compliant HTN implementation. This
design is frozen at the responsibility and control-flow level; the concrete
TypeScript data types and world-state fields remain open.

`TaskExecutor` owns one task. A compound task resolves a task method and creates
child `TaskExecutor` instances for its subtasks. A child executor keeps its own
method and current method step, and the parent advances only after the child
reports its result. This replaces a single global task stack with a recursive
executor tree.

Only the active primitive-task executor owns gameplay input. Compound executors
coordinate method selection and child lifecycle but do not compete for input.
Quark actions are declarative control results rather than side-effecting
operations: they describe what the controller should currently hold, release,
or pulse. The executor performs the input side effects and observes the game
state to determine completion or failure.

The initial design may use ordered method steps. Recursive child executors are
required even in that form so that a method step can itself be a compound task.
Formal HTN completeness, planner search, partial ordering, method-effect
semantics, and alternative-method backtracking are not project requirements.
The HTN literature is a design reference, not an implementation contract.

## ViDot Test Topology

ViDot compiles Vitest-shaped TypeScript test modules through tstogd, and the real
Godot runtime collects and executes their test trees.

ViKeeper is the thin Dome Keeper-specific layer above that generic boundary. It
owns game startup, test scenes, and the planned map-definition DSL. ViDot starts
its runner without automatically entering the original main scene; ViKeeper
starts Dome Keeper's main scene when a test requires it. DataCollectorAI keeps
only its assertions, and its production Mod does not contain the test runtime.

Vitest retains file discovery, its filter-facing CLI and configuration, watch
mode, scheduling, and reporting through a ViDot custom pool. Its thin Node.js
adapter passes selection inputs when it launches each file and maps one-way
Godot events into Vitest tasks. Each test file receives one fresh Godot process.
Godot evaluates the generated module's top-level code to collect `describe`,
`test`, and hook registrations, applies the supported in-tree filtering, then
runs the test bodies, assertions, and engine waits. Tests in one file run
sequentially and share its Godot state, while different files may run in
separate processes. Shared processes remain deferred until startup measurements
justify them.

The first supported baseline is an editable Godot 4.3.1 project,
including the recovered project used by ViKeeper. ViDot does not gate later
engine versions at runtime; they may work but are not guaranteed. The
runtime must preserve original project settings and Autoloads without a Mod,
GDExtension, permanent ViDot Autoload, or source change. Released-game execution
is outside the initial scope. The detailed contract belongs to
[`vidot.md`](vidot.md).

## Evidence for Target Design

The rule teacher establishes realizable behavior and produces evidence about
the state, timing, and action information needed by the target runtime. Its
recordings and telemetry support evaluation and contract design. Any later use
for training, imitation learning, or controller optimization requires a
separate explicit project decision and is not implied by this architecture.

If the legacy teacher is re-enabled, prioritize reliable mining, cache
collection, return, upgrade, and defense before designing detailed Lower-Agent
contracts. Do not constrain teacher improvements around an unconfirmed
Lower-Agent schema.
