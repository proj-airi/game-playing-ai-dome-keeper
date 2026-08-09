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

- The Godot mod exposes manual collection controls and connects the YOLO
  collector to one in-process rule teacher driven by an interruptible task
  stack.
- `LemonNekoGH-YoloDataCollector` is the existing collector and teacher
  implementation. `LemonNekoGH-DataCollectorAI` is the replacement Godot mod,
  authored in TypeScript and converted to GDScript during the build. Its
  planner, task, and `Quark Action` layers replace the old collector/teacher
  structure.
- The rule teacher currently combines high-level task selection, navigation,
  upgrades, defense, and near-real-time control. It reads privileged Godot
  runtime state and emits normal configured game input actions. It is currently
  a behavior reference and data source; it does not yet instantiate the target
  Upper and Lower Agent separation.
- The collector captures game frames and derives YOLO labels from authoritative
  runtime objects. Model training is offline; runtime Vision inference does not
  yet control gameplay.
- Status snapshots and frame-synchronized replay records feed the local
  dashboard as an observer, not as a control component.

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

## Planned ViDot Test Topology

ViDot supplies the Godot boundary for Vitest rather than owning a second test
runner. Test and fixture modules execute in Node.js and use `@vidot/vitest` to
control an editable Godot project through a temporary TypeScript-authored
Autoload and a loopback WebSocket bridge.

One file-scoped ViDot fixture owns one Godot process. Tests receive its client
without manually starting or stopping Godot. Tests in that file run sequentially
with automatic fixture teardown, while different files may run in parallel in
separate processes. The Autoload calls ordinary project methods and observes
signals and state; project code does not depend on ViDot.

The `examples/basic-vidot` Godot project first proves the generic bridge,
process lifecycle, and `get`, `set`, `call`, `waitForProperty`, and
`waitForSignal` commands.
DataCollectorAI is the first project-specific runtime tested afterward. Its
fixtures remain with the Mod, and its first end-to-end test executes a Move
Quark Action through `TaskExecutor` before asserting the character's final tile.
[`vidot.md`](vidot.md) owns the detailed integration, process, protocol, and
lifecycle design.

## Evidence for Target Design

The rule teacher establishes realizable behavior and produces evidence about
the state, timing, and action information needed by the target runtime. Its
recordings and telemetry support evaluation and contract design. Any later use
for training, imitation learning, or controller optimization requires a
separate explicit project decision and is not implied by this architecture.

Prioritize reliable mining, cache collection, return, upgrade, and defense in
the current teacher loop before designing detailed Lower-Agent contracts. Do not
constrain teacher improvements around an unconfirmed Lower-Agent schema.
