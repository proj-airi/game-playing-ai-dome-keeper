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
  build; its first proven runtime slice executes `MoveTo` through normal
  configured input. The controlled test starts the Engineer underground and
  reaches a non-adjacent target that requires changing direction.
- `LemonNekoGH-YoloDataCollector` and its in-process rule teacher are retained
  as dormant behavior and data-collection references. They are not linked into
  newly decompiled projects, and their collection, replay, and dashboard
  producer workflows are inactive.
- Godot-native ViDot runs both the basic editable-project proof and the
  ViKeeper-wrapped DataCollectorAI Move proof end to end.
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

The current coordinate-based movement work keeps frame control separate from
task state without freezing the Lower Agent contract:

- `Move` is a stateless Quark action. For the current frame, it resolves the
  directional input needed from the current position toward a target. It does
  not retain the target, determine task completion, or plan a path.
- The current `MoveTo` task may own an arbitrary map coordinate, determine
  whether that coordinate has been reached, and resolve `Move` again on every
  active frame until completion. Coordinates are an implementation aid for the
  current privileged runtime and controlled tests, not a promised Lower Agent
  observation or task field.

`MovePath` is not a confirmed task. Add a path-consuming compound task only if
a concrete caller can supply an ordered path and demonstrated behavior requires
that abstraction. The future student or other Lower Agent may instead act from
frame history and an uncertain relative impression such as a resource being in
a general direction. Its observation and task contracts remain open until the
Vision and teacher evidence establish the smallest useful representation.

Configured gameplay actions remain separate Quark actions even when their
default physical bindings overlap. `Activate` resolves `ui_select`, `Pickup`
resolves `keeper1_pickup`, and `Drop` resolves `keeper1_drop`. Dome Keeper lets
players rebind Use, Engineer Pickup, and Engineer Drop independently, so none of
these actions may be implemented as a hard-coded key or collapsed into one
generic primary action. Tasks such as `ActivateTarget`, `PickupTarget`, and
`DropCargo` own their exact target, one-shot timing, and observable completion;
the Quark actions only describe the input for the current frame.

The initial design may use ordered method steps. Recursive child executors are
required even in that form so that a method step can itself be a compound task.
Formal HTN completeness, planner search, partial ordering, method-effect
semantics, and alternative-method backtracking are not project requirements.
The HTN literature is a design reference, not an implementation contract.

## ViDot Test Topology

Vitest discovers candidate files and reports results through a ViDot custom
pool. The Node.js adapter compiles the test modules and starts the configured
editable Godot project. Godot evaluates the modules, collects the authoritative
test trees, and executes the tests sequentially in one process.

ViKeeper is the Dome Keeper Mod testing layer above ViDot. It owns the
headless and Movie Maker launch policies for an explicitly configured editable
project. Each Mod owns its own fixtures, game setup, and assertions; ViKeeper
does not locate projects or inspect Mod manifests. The current ViDot contract
lives in [`vidot.md`](vidot.md).

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
