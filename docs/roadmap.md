# Roadmap

This document owns capability milestones, their broad ordering, and their open
design decisions. Maintenance, cleanup, and corrections to current behavior
belong in [`todo.md`](todo.md).

Roadmap entries commit only to their stated outcomes. They do not select an
implementation, interface, dataset schema, model, dependency, or training method
unless an explicit project decision says so.

## Architecture Decision Sequence

This sequence preserves the decisions that must precede the next data and
Lower-Agent implementation work. Each entry states its decision status. An open
entry does not reserve an ADR number. It can split or change before a complete
proposal is ready for review.

### Adopt a Multi-Timescale Gameplay Agent

**Accepted by
[ADR-0004](decisions/0004-adopt-a-multi-timescale-gameplay-agent.md).** AIRI
starts a continuous tool-calling Upper LLM Agent for a whole-run gameplay task.
The Upper controls one asynchronous Lower task with `query` and
replace-on-`start` operations. The Lower runs outside the game and uses
operating-system input. The Upper does not wait for Lower completion. Each
Upper iteration queries the latest Lower state.

ADR-0004 does not select the Upper-to-Lower command, the Lower observation,
the learned model, the training objective, or the task boundary. ADR-0005 now
selects one bounded Lower v0 training contract; the remaining entries measure
the eventual deployed boundary and alternatives beyond that first model.

The following latency, command-representation, and Lower-contract decisions are
coupled work that may proceed in parallel. Their experiments must use shared
scenarios and metrics where one candidate affects another; their order below is
not a requirement to finish one before starting the next.

### Benchmark the Runtime Control Boundary

**Experiment design required.** Measure which decisions can wait for an LLM.
Keep the other decisions inside the Lower control loop. The ADR must define
these items:

- The meaning of “tolerated delay” for movement, interaction, mining, combat,
  and recovery scenarios
- A controlled delay-injection method and repeatable scenarios
- Outcome, degradation, interruption, and recovery metrics
- The reported latency distribution, with tail latency and the average
- Whether continuous Upper iterations meet reaction requirements without
  event-driven inference cancellation
- The complete LLM decision path: state preparation, request, structured
  generation, validation, tool dispatch, and the first resulting game input

The resulting allocation rule must determine which timing classes belong to
AIRI, the gameplay Upper Agent, the Lower Agent, or a small deterministic safety
and lifecycle boundary. Task granularity must not be selected from model names
or intuition alone.

### Define Candidate Upper-to-Lower Command Representations

**Experiment contract required beyond Lower v0.** ADR-0005 selects a closed
structured instruction for the initial model without selecting the final
Upper-to-Lower command. Compare natural-language subgoals, closed structured
calls, and a hybrid containing both language and explicit grounding before
changing that deployed boundary. The experiment must compare at least:

- complete valid-command latency for candidate LLMs;
- schema and argument validity;
- target ambiguity and stale-reference behavior;
- debuggability and compatibility with AIRI and gameplay memory; and
- how reliably a Lower model can learn from each representation.

This decision must cover how a transient visual target is identified without
requiring an LLM to remember an unstable detector identifier such as
`target=17`.

### Establish the Lower v0 Training and Evaluation Contract

**Accepted by
[ADR-0005](decisions/0005-train-lower-v0-with-automated-multitask-demonstrations.md).**
Lower v0 is one instruction-conditioned ResNet-18 and MLP action classifier.
Its fixed input, action, timing, Session, collection, storage, split, and offline
evaluation contracts are ready for implementation. It is a bounded measurement
instrument for the task boundary, not the final Lower architecture or a whole-run
Agent.

### Train Lower v0 with Automated Multitask Demonstrations

**Accepted in
[ADR-0005](decisions/0005-train-lower-v0-with-automated-multitask-demonstrations.md).**
The first model learns automatic demonstrations for Pickup and type-directed
Drop of iron, cobalt, and water; Gadget Chamber activation; and Laser attack.
The ADR fixes the structured instruction, observation window, past-action input,
nine action classes, pretrained visual model, supervised objective, Session
schema, capture owner, and repository locations. The first deliverable is an
offline checkpoint and held-out report, not a model connected to the game.

The six-physics-frame TaskExecutor cadence is implemented. Verification on
2026-09-05 passed `mise run check`, including all five Dome Keeper task tests
and both basic ViDot tests. MoveTo, Pickup, laser attack, type-directed Drop,
and Gadget Chamber activation complete in their existing controlled scenarios.
The laser test also waits for task completion and delivery of input release.
The separate `mise run godot:check` passes. These results do not establish
reliability across other maps, upgrades, or monsters.

Automated collection and the first offline model are implemented as of 2026-09-09.
Collection uses the existing ViKeeper Movie Maker flow without taking window focus.
The recorder redraws before capture, including when another application covers the window.
Scenarios use bounded fixtures and seeded two-dimensional positions.

The first dataset contains 61 successful Sessions and 988 RGB frames.
Both splits contain all nine actions. The root uv workspace manages the
PyTorch 2.14 and Torchvision 0.29 training subproject.
The first checkpoint scores 65.65% held-out action accuracy against an 18.32% common-action baseline.
The [training README](../models/lower-v0/README.md#first-model-2026-09-09)
records the configuration, timing, memory measurement, class limitations, and reproduction commands.

The initial verification covers:

- [x] Each target action follows its input observation. No input contains the target action or future outcome.
- [x] All eight valid `(task, target)` combinations produce complete automated Sessions with 384-by-216 RGB PNG frames and ordered JSON metadata.
- [x] Failed, interrupted, timed-out, and invalid temporary Sessions do not enter the promoted training dataset.
- [x] The loader reconstructs held input, repeated actions, releases, and the initial window without crossing Session boundaries.
- [x] Successful terminal releases supply no-input targets. Failure and cancellation cleanup do not supply success labels.
- [x] Repeated scenarios and all windows from a Session remain in one dataset split.
- [x] Model inputs have shapes `[10, 3, 216, 384]`, `[10, 9]`, and `[9]`; the classifier produces nine scores in the ADR-defined order.
- [x] A training step updates both the CNN and MLP parameters. Validation does not update parameters or model statistics.
- [x] A saved checkpoint reproduces predictions with its recorded preprocessing and class order.
- [x] The report includes held-out loss, accuracy, per-class and `(task, target)` results, class counts, and a common-action baseline.

Live model control, ViDot model integration, and game-execution evaluation are
deferred. They require a separate runtime-boundary decision, not an inference
RPC or asynchronous model task added to the teacher for this experiment.

The teacher source lives under
`mods/LemonNekoGH-DataCollectorAI/src/tasks/` and `src/task_executor.ts`; its
fixtures and integration tests live under that Mod's `test/`. Lower collection
will be implemented in the same Mod, training code in `models/lower-v0/`, and
local Session data in `data/lower-v0/`.

### Derive Capture and Human-Telemetry Requirements

**Lower v0 requirements accepted; human telemetry remains open.** ADR-0005
defines the training-data producer, files, clocks, cadence, alignment, and
provenance for Lower v0. Separately describe the questions a human must answer
when reviewing an Agent timeline in the status dashboard. Existing teacher
fields are evidence of an old debugging workflow, not automatically future
telemetry requirements.

### Separate Legacy Collector Responsibilities

**Lower v0 ownership resolved; other responsibilities remain open.**
`LemonNekoGH-DataCollectorAI` owns Lower v0 Session capture. Human-facing
telemetry, replay, and YOLO-label capture still require explicit destinations;
the Lower decision does not imply one universal schema or producer for them.

The legacy rule-teacher gameplay strategy is not a migration target and will be
deleted after retained capabilities have explicit destinations. Existing
in-game configured-action execution may remain only where controlled tests or
approved data generation require it; it must not become the deployed Lower
execution path.

### Select the Initial Upper-to-Lower Operating Boundary

**Blocked on the preceding evidence.** Increase task duration and complexity
until the Lower Agent's reliability fails under a predefined criterion. Select
the initial command representation and task boundary together from the game's
measured delay tolerance, candidate LLM tail latency, command validity and
grounding results, and the Lower task-ladder results. Record the selection and
failure evidence in a later ADR; expect that ADR to be superseded when measured
capabilities materially change.

## Capability Milestones

### Implement Godot-Native ViDot Test Execution — Moved to ViDot Repository

- Maintain the editable-project proof and generic test API in the
  [ViDot repository](https://github.com/LemonNekoGH/vidot).
- Keep Dome Keeper-specific coverage in `mise run domekeeper:vidot:test`.

### Connect the First Dome Keeper ViKeeper Test — Complete

- Keep the DataCollectorAI-owned fixture and Move test passing through the
  ViKeeper Dome Keeper wrapper, with a controlled map, signal-first completion,
  a frame-scoped Move Quark Action executed by `MoveToTask` through
  `TaskExecutor`, and a final non-adjacent target-tile assertion.
- Keep headless and Movie Maker launch policy in ViKeeper, while each Mod owns
  its fixture, startup behavior, and assertions.
- Use this proof before expanding `TaskExecutor` to more actions or compound
  tasks.

### Implement the Accepted Lower Agent v0 Contract

- Implement ADR-0005's closed structured instruction and learned Lower Agent
  observation, action, timing, training, and offline evaluation contracts.
- Account for the control-relevant distinctions demonstrated by Laser defense:
  exact selected-target ray acquisition, runtime damage eligibility, and
  intentional-target eligibility, including the `WORM_ROCK` exclusion. Decide
  their frame-derived representation rather than exposing privileged teacher
  runtime fields.
- Define a task ladder that can vary duration and decision complexity and expose
  where each Lower candidate fails. Do not require whole-run independence.

### Derive Training-Data and Human-Telemetry Requirements

- Derive required training observations, targets, outcomes, provenance, and
  timing from the Lower v0 and command experiment contracts.
- Define status-dashboard review scenarios as human questions about what the
  Agent observed, was asked to do, attempted, and achieved. Do not preserve old
  teacher fields merely because the existing dashboard can display them.
- Keep human telemetry requirements independent of the Lower v0 Session layout
  until the dashboard establishes a shared need.

### Retire the Existing Collector Boundary

- Use `LemonNekoGH-DataCollectorAI` for Lower v0 Session capture and its task and
  `Quark Action` tests as migration evidence. Do not infer ownership of every
  legacy responsibility or the future operating-system input path.
- Keep the legacy collector disabled while its source remains available until
  the required data capture and telemetry and replay capabilities have explicit
  destinations. Delete its rule-teacher gameplay strategy rather than migrating
  it.
- Decide the remaining human telemetry, replay, and YOLO capture ownership
  before deleting the legacy implementation. Preserve the TypeScript-to-GDScript
  build boundary only for capabilities that remain in a Godot Mod.

### Expand the YOLO Dataset

- Expand the detector beyond the current MVP classes as later gameplay
  capabilities establish concrete perception requirements. Define each
  addition's annotation rules and evaluation criteria before changing the
  dataset contract; current detector and collection decisions remain in
  [`vision.md`](vision.md).

### Implement Required Lower-Agent Data Capture

- Implement ADR-0005's visual, instruction, action, timing, outcome, and
  provenance streams in `LemonNekoGH-DataCollectorAI`. Keep in-game-injected
  and operating-system-injected action sources distinguishable.
- Write only finalized successful Sessions to `data/lower-v0/`. Replay events
  and YOLO image-label pairs are not Lower action data.

### Train and Evaluate the Lower Agent v0

- Train and evaluate the accepted instruction-conditioned classifier in
  `models/lower-v0/`. Report offline results by action class and `(task, target)`
  without claiming gameplay success.
- Use the results together with measured game delay tolerance and LLM tail
  latency to propose the initial Upper-to-Lower operating boundary.
