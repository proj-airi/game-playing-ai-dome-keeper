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

## Evidence for Target Design

The rule teacher establishes realizable behavior and produces evidence about
the state, timing, and action information needed by the target runtime. Its
recordings and telemetry support evaluation and contract design. Any later use
for training, imitation learning, or controller optimization requires a
separate explicit project decision and is not implied by this architecture.

Prioritize reliable mining, cache collection, return, upgrade, and defense in
the current teacher loop before designing detailed Lower-Agent contracts. Do not
constrain teacher improvements around an unconfirmed Lower-Agent schema.
