---
status: accepted
date: 2026-08-26
decision-makers: LemonNeko
---

# Model Type-Directed Drop as Compound Tasks

## Context

The Engineer's configured `keeper1_drop` input cannot select an exact carried
object. A short press releases the carried object farthest from the Keeper;
holding the input releases objects repeatedly from the front of the carried
array. Tasks nevertheless need to release one `Drop` of a requested type
without permanently losing unrelated cargo.

Quark Actions must remain stateless, and compound tasks must continue to
resolve one ordered method without changing `TaskExecutor` into a planner.
Gameplay after a fixture reports ready must use normal configured input rather
than direct game-state mutation.

## Decision

- `Drop` is a stateless Quark Action that resolves the configured
  `keeper1_drop` input.
- `DropUntilTypeTask` is a primitive task. It owns repeated short press/release
  cycles, observes the exact object removed from the Keeper's carried set after
  each cycle, and completes after the removed `Drop.type` matches the requested
  type.
- `DropByType` is a compound task. It snapshots the initial carried objects,
  executes one `DropUntilTypeTask`, then executes the existing `PickupTargetTask`
  for every initially carried object that is not a `Drop` of the requested
  type. A pickup for an object that remained carried completes immediately; an
  object released before the match is picked up again through configured input.
- `PickupTargetTask` and `Pickup` accept any `Carryable`. Drop-only failure
  state such as `absorbed` is checked only for `Drop`, and another carrier does
  not make pickup fail because the game supports shared carrying.
- Successful completion leaves the Keeper carrying the initial object-identity
  set minus one actually released object of the requested type. When multiple
  objects share that type, no exact instance is promised.
- Cargo categories do not create allowlists, rejection branches, or parallel
  Drop tasks. If a shared carry or pickup contract proves too narrow, correct
  that shared contract instead of adding a call-site workaround.
- Failure and cancellation stop execution and release held input. They do not
  compensate for physical actions that already occurred; later work starts a
  new task from observed world state.

## Consequences

- Type-directed intent is realizable despite the game's distance-selected
  physical Drop behavior.
- Recovery reuses exact object identities and the existing Pickup task instead
  of duplicating movement or input logic.
- The shared Pickup contract becomes broad enough to represent the game's
  existing `Carryable` focus and multiple-carrier behavior.
- The primitive task owns a small input-phase state machine because Drop takes
  effect on release and may require multiple deliberate cycles.
- A failed or cancelled task may leave previously released cargo in the world,
  matching the non-transactional behavior of normal gameplay actions.

## Non-Goals

- Selecting an exact instance among carried objects of the same type.
- Long-hold FIFO unloading or a Drop All action.
- Planner search, dynamic method growth, retries after task failure, or
  `DataCollectorAI` task selection.
- Type-specific Drop tasks or direct carry-state mutation.

## Implementation

- Add the Quark Action under
  `mods/LemonNekoGH-DataCollectorAI/src/quark_actions/` and both tasks under
  `src/tasks/`.
- Follow `ActivateUsable` for explicit press/release phases and
  `ActivateGadgetChamber` for fixed compound decomposition followed by an
  outcome owned by the parent task.
- Widen `PickupTargetTask` and `Pickup` at their existing source boundary to
  accept `Carryable`; do not add recovery callbacks, a second executor path,
  cargo allowlists, or new dependencies or configuration.
- Add one target-specific fixture and integration test under the Mod's `test/`
  tree. Arrange the initial cargo so a nonmatching object is released before a
  matching object, and do not mutate gameplay state after fixture readiness.

## Verification

- [x] `Drop` retains no state and resolves only `keeper1_drop`.
- [x] Each attempt produces a distinct short press/release cycle and observes
  the exact carried-set removal before another attempt.
- [x] The integration test releases a nonmatching object before a requested
  type, then restores every nonmatching initial object by identity.
- [x] The final carried identity set equals the initial set minus one object of
  the requested type.
- [x] Existing Move, Pickup, and target-activation tests pass unchanged.

## Rejected Alternatives

- Exact-target Drop: configured input cannot choose an arbitrary carried
  instance, so the task would promise control the game does not provide.
- Farthest-only task: it exposes the input mechanism but does not express the
  resource-type outcome required by callers.
- Cargo-category restrictions: they turn a temporary slice boundary into a
  permanent failure path and encourage parallel workaround tasks.
- Dynamic compound methods or executor replanning: the initial identity
  snapshot lets the fixed method include every potential recovery pickup.

## References

- [ADR-0002: Model Target Activation as Compound Tasks](0002-model-target-activation-as-compound-tasks.md)
- [DataCollectorAI runtime design](../../mods/LemonNekoGH-DataCollectorAI/README.md#runtime-design)
- `external/domekeeper-decompiled/5.0.5.19/content/keeper/Keeper1InputProcessor.gd`
- `external/domekeeper-decompiled/5.0.5.19/content/keeper/keeper1/Keeper1.gd`
