---
status: accepted
date: 2026-08-25
decision-makers: LemonNeko
---

# Model Target Activation as Compound Tasks

## Context

Activating a Relic Switch, Mushroom Cave, or Gadget Chamber uses the same
`ui_select` input but has a different success condition. Emitting the input is
therefore not evidence that the interaction succeeded.

Quark Actions resolve frame-scoped input and must remain stateless. Durable
intent, sequencing, and outcome ownership belong to tasks.

## Decision

- `Activate` is a stateless Quark Action. It returns `ui_select` only when the
  exact requested `Usable` is focused.
- `ActivateUsable` is the primitive task that approaches the target, focuses
  it, presses `ui_select` once, and releases it on the next step. Press and
  release stay together because focus has no useful independent completion
  condition and the game handles use-hit on release.
- `ActivateRelicSwitch`, `ActivateMushroomCave`, and
  `ActivateGadgetChamber` are domain compound tasks without a `Task` suffix.
  Each resolves one ordered method once, then waits without input for its own
  completion condition.
- `TaskExecutor` may recursively execute compound children. Each parent owns
  at most one child executor, while only the active primitive leaf emits input.
  Completion, failure, and cancellation propagate through the child chain.
  The executor does not replan or backtrack.

Domain completion conditions are:

- Relic Switch: the exact Chamber is `EMPTY` and its `Usable` is removed.
- Mushroom Cave: Keeper movement speed increases from its pre-activation value.
- Gadget Chamber: the exact Chamber is `EMPTY` and the Keeper carries a Gadget
  `Drop`.

## Consequences

- Input mechanics are shared while each domain task owns its real outcome.
- Compound execution adds child lifecycle and recursive cancellation to
  `TaskExecutor`.
- Fixture bases only place declared landmarks. Target-specific fixtures own
  preparation such as excavating a Gadget Chamber and expose their own
  readiness condition.
- Gadget Chamber activation is the first delivery slice; the other two domain
  tasks remain separate slices with separate integration tests.

## Non-Goals

- Planner search, method backtracking, partial ordering, or retries.
- One callback- or strategy-configured `ActivateTarget` abstraction.
- Installed Gadget controls such as `keeper_gadget1` or `keeper_gadget2`.
- Excavation, resource delivery, Gadget choice, or complete teacher flows.
- Direct game-state mutation after a target-specific fixture reports ready.

## Implementation

- Task contracts and recursive execution live under
  `mods/LemonNekoGH-DataCollectorAI/src/tasks/` and `src/task_executor.ts`.
- Stateless input resolution lives in `src/quark_actions/`.
- Each domain task has one target-specific fixture and integration test.
- Existing Move and Pickup behavior continues through the same executor.
- This decision adds no dependency, configuration, or compatibility layer.

## Verification

- [x] `Activate` has no retained state and requires the exact focused usable.
- [x] Activation produces one press/release cycle owned by a primitive leaf.
- [x] Compound child completion, failure, and cancellation propagate.
- [x] Move, Pickup, and Gadget Chamber integration tests pass.
- [ ] Relic Switch and Mushroom Cave each have their stated domain test.

## Rejected Alternatives

- Monolithic primitive tasks: each target would duplicate a hidden state
  machine for movement, press/release, and observation.
- Generic `ActivateTarget`: configured predicates would hide domain meaning and
  add generality before runtime configurability is required.
- Stateful domain-aware `Activate`: it would mix frame input with Chamber and
  Cave semantics.

## References

- [ADR-0001: Adopt Architecture Decision Records](0001-adopt-architecture-decision-records.md)
- [DataCollectorAI runtime design](../../mods/LemonNekoGH-DataCollectorAI/README.md#runtime-design)
- [Local interaction model](../interaction.md)
- [Game-AI and Godot input references](../references.md)
