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
operating-system input.

ADR-0004 does not select the Upper-to-Lower command, the Lower observation,
the learned model, the training objective, or the task boundary. The remaining
entries define and measure those contracts.

The following latency, command-representation, and Lower-contract decisions are
coupled work that may proceed in parallel. Their experiments must use shared
scenarios and metrics where one candidate affects another; their order below is
not a requirement to finish one before starting the next.

### Benchmark the Runtime Control Boundary

**Experiment design required.** Measure rather than guess which decisions can
wait for an LLM and which must stay inside the Lower control loop. The ADR must
define:

- what “tolerated delay” means for movement, interaction, mining, combat, and
  recovery scenarios;
- a controlled delay-injection method and repeatable scenarios;
- outcome, degradation, interruption, and recovery metrics;
- the latency distribution to report, including tail latency rather than only
  an average; and
- the complete LLM decision path to measure: state preparation, request,
  structured generation, validation, tool dispatch, and the first resulting
  game input.

The resulting allocation rule must determine which timing classes belong to
AIRI, the gameplay Upper Agent, the Lower Agent, or a small deterministic safety
and lifecycle boundary. Task granularity must not be selected from model names
or intuition alone.

### Define Candidate Upper-to-Lower Command Representations

**Experiment contract required.** Define natural-language subgoals, closed
structured calls, and a hybrid containing both language and explicit grounding
as candidates rather than choosing a winner before a Lower model exists. The
ADR must define candidate envelopes and compare at least:

- complete valid-command latency for candidate LLMs;
- schema and argument validity;
- target ambiguity and stale-reference behavior;
- debuggability and compatibility with AIRI and gameplay memory; and
- how reliably a Lower model can learn from each representation.

This decision must cover how a transient visual target is identified without
requiring an LLM to remember an unstable detector identifier such as
`target=17`.

### Establish the Lower v0 Training and Evaluation Contract

**Research and experiment design required.** Define enough of the Lower Agent to
train and falsify a candidate without treating that candidate as disposable or
as the final architecture. The ADR must decide:

- deployed observation, task, configured-action, timing, and outcome contracts;
- the initial architecture and learning objective, with reasons it can be
  extended or replaced behind those contracts;
- collection and alignment requirements for visual, task, action, and outcome
  streams;
- whole-episode or whole-seed dataset splits and leakage controls;
- success, failure, timeout, interruption, and recovery labels; and
- a task ladder that increases duration and decision complexity independently
  where possible.

The Lower v0 is successful when it provides a valid measurement instrument for
the task boundary. It is not required to complete a whole run independently.

### Derive Capture and Human-Telemetry Requirements

**Evidence work; not necessarily an ADR.** Derive training-data requirements
from the accepted Lower observation, command, action, timing, outcome, and
evaluation contracts. Separately describe the questions a human must answer
when reviewing an Agent timeline in the status dashboard. Existing teacher
fields are evidence of an old debugging workflow, not automatically future
telemetry requirements.

This work must identify required information and provenance before selecting
runtime producers, files, clocks, sampling cadences, or shared session
machinery. It must distinguish in-game injected actions from deployed
operating-system input.

### Separate Legacy Collector Responsibilities

**Blocked on the preceding requirements.** Decide ownership and migration for
the required training-data capture and human-facing telemetry and replay. Do
not assume one universal schema, one producer, or one shared capture session
before their consumers establish a need for it.

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

### Implement Godot-Native ViDot Test Execution — First Editable Proof Working

- Keep the editable-project proof passing through `mise run vidot:test`.
- Extend the test API only when a concrete test requires it.

### Connect the First Dome Keeper ViKeeper Test — Complete

- Keep the DataCollectorAI-owned fixture and Move test passing through the
  ViKeeper Dome Keeper wrapper, with a controlled map, signal-first completion,
  a frame-scoped Move Quark Action executed by `MoveToTask` through
  `TaskExecutor`, and a final non-adjacent target-tile assertion.
- Keep headless and Movie Maker launch policy in ViKeeper, while each Mod owns
  its fixture, startup behavior, and assertions.
- Use this proof before expanding `TaskExecutor` to more actions or compound
  tasks.

### Define the Lower Agent v0 Contract

- Define the Upper-to-Lower candidate command envelopes and the learned Lower
  Agent's observation, action, timing, training, and evaluation contracts before
  implementing new multimodal capture.
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
- Keep requirements independent of a particular file layout, shared session
  object, or producer until synchronization and consumer needs justify one.

### Retire the Existing Collector Boundary

- Use `LemonNekoGH-DataCollectorAI` and its task and `Quark Action` tests as
  migration evidence, not as a predetermined owner of every legacy
  responsibility or as the future operating-system input path.
- Keep the legacy collector disabled while its source remains available until
  the required data capture and telemetry and replay capabilities have explicit
  destinations. Delete its rule-teacher gameplay strategy rather than migrating
  it.
- Complete the collector-responsibility ADR before assigning long-term
  ownership or deleting the legacy implementation. Preserve the
  TypeScript-to-GDScript build boundary only for capabilities that remain in a
  Godot Mod after that decision.

### Expand the YOLO Dataset

- Expand the detector beyond the current MVP classes as later gameplay
  capabilities establish concrete perception requirements. Define each
  addition's annotation rules and evaluation criteria before changing the
  dataset contract; current detector and collection decisions remain in
  [`vision.md`](vision.md).

### Implement Required Lower-Agent Data Capture

- Implement only the visual, command, action, timing, outcome, and provenance
  streams required by the accepted Lower and experiment contracts. Keep
  in-game-injected and operating-system-injected action sources distinguishable.
- Decide eligible data sources, schema, sampling cadence, synchronization, and
  intended learning use before collection. Replay events and YOLO image-label
  pairs are not automatically a Lower action dataset.

### Train and Evaluate the Lower Agent v0

- Train and evaluate the initial learned Lower-Agent candidates behind the
  accepted contracts. Compare candidate command representations and progress
  through the task ladder without preselecting the final task granularity.
- Use the results together with measured game delay tolerance and LLM tail
  latency to propose the initial Upper-to-Lower operating boundary.
