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
- The old ViDot loopback WebSocket RPC implementation has been deliberately
  removed. The basic ViDot and ViKeeper Godot fixture assets remain but are not
  runnable until the Godot-native adapter is implemented.
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

The topology below is the confirmed target, not a description of a currently
runnable harness. Godot-native ViDot will compile Vitest-shaped TypeScript test
modules through tstogd, and the real Godot runtime will collect and execute
their test trees.

ViKeeper is the thin Dome Keeper-specific layer above that generic boundary. It
owns Dome Keeper startup, test scenes, and the planned map-definition DSL.
ViDot starts its test runner instead of the selected target's original main
scene, so ViKeeper explicitly constructs the game scene and dependencies a test
needs. DataCollectorAI keeps only its assertions, and its production Mod does
not contain the test runtime.

Vitest retains candidate test-file discovery, its filter-facing CLI and
configuration, watch mode, scheduling, and reporting through a ViDot custom
pool. The Node.js adapter compiles the candidate modules, passes their paths and
raw selection inputs to Godot, and mirrors Godot's one-way tree and result
events into Vitest. It does not evaluate test modules, collect their trees, or
select tests.

Each Vitest project configuration selects an editable Godot project directory
or a standalone unencrypted PCK. The adapter starts that configured target with
its project settings and original Autoload configuration, then one Godot runner
handles candidate test files sequentially. Godot evaluates each generated
module's top-level code, dynamically collects and selects the authoritative test
tree, and runs hooks, assertions, bodies, and engine waits. Test-owned scenes
are released after each test; the generated module, hooks, and tree are released
after each file. The configured target remains alive until the runner exits.

The configured target and the production Mod under test are separate inputs.
The user or an upper wrapper owns how application-specific components join
startup; ViDot does not define a generic Mod loader or packaging contract.
ViKeeper is the first wrapper and helps a configured DataCollectorAI Mod project
start against the selected Dome Keeper target. ViDot itself is not installed as
a Mod.

The first supported engine baseline is Godot 4.3.1 without a runtime version
gate. Later versions may work but are not guaranteed. Editable project
directories and separate unencrypted PCKs, including those from released games,
are in scope; PCKs embedded in an executable and encrypted PCKs are deferred.
The runner does not permanently modify the target or require a ViDot Mod,
Autoload, GDExtension, or production source change. The detailed contract
belongs to [`vidot.md`](vidot.md).

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
