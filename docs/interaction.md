# Local Interaction Model

This document defines the shared discovery and approach behavior for nearby
interactable objects in the mine. Ordinary ore, Gadget Chambers, Supply
Chambers, Relic Switch Chambers, Relic Chambers, and supported natural Caves
use the same local scan.

The teacher treats an interaction as a task pushed above the work it interrupts.
Interaction types share discovery, approach choice, decision recording, and
return to the suspended task.
A subtype supplies only the preparation and observable result required by that
game object.

The scan claims one target, records `interaction_decided`, and pushes `MINE` or
`INTERACT`. The target identifies the handler; there is no parallel
interaction-type state machine.

## Shared Interaction Flow

1. On the controller's existing fixed tick, scan eligible objects whose
   straight-line map distance from the keeper is less than `10` tiles.
2. Ignore unrevealed objects. A scan result is eligible only when its public
   game state says work remains and the teacher supports that subtype.
3. Select one target in priority order: Relic Switch Chamber, Relic Chamber,
   Supply Chamber, Gadget Chamber, supported Cave, then ordinary ore. Within a
   category choose the nearest target. A requested-resource search considers
   only relic-critical chambers and the requested ore type.
4. Lock that target until completion or invalidation. A wave suspends rather
   than discards the task. Do not rerank while the interaction remains active.
5. Estimate the travel time of the shortest A* route to a reachable interaction
   boundary from path length and current movement speed.
6. Estimate the time to reach the target directly from the intervening tiles,
   current drilling strength, and movement time.
7. Use the A* route when it is no slower. Dig directly toward the target when the
   A* estimate is longer.
8. Identify the interaction type and subtype and record the decision before
   leaving the current path. The event must explain why the teacher deviated
   and which approach it chose.
9. Push the target task and approach it by the selected route.
10. Perform only the preparation required by that subtype.
11. Activate the object through configured normal input when its subtype
    requires activation. Enter the target area without pressing interaction
    when the game's interaction is passive.
12. Judge success from the smallest public state or player-visible capability
    change for that subtype.
13. Record completion or failure, including the observed state change and
    reason, then resume the path and task that were active before the deviation.

A mandatory wave pushes `DEFEND` above the interaction. After defense, the
unfinished interaction resumes and re-evaluates the live target. Resource
preparation may push `ACQUIRE_RESOURCE`, which may push `SEARCH`; those tasks
continue the same local scan, so another nearby interactable can suspend them
without losing the original interaction.

The estimators are decision aids, not independent correctness proofs. They need
only enough fidelity to choose between the two available approaches. Add more
model inputs only after a recording demonstrates a wrong approach decision.
The open-route estimate follows the project's existing A* path query; see the
[Godot AStar2D path-query reference](references.md#mod-development-and-godot-43).

## Decision Event

Choosing to interact is itself an event. Record `interaction_decided`
before changing movement. Its evidence should be limited to what explains the
decision:

- interaction type, subtype, and map position;
- straight-line distance;
- estimated A* and direct-dig times;
- selected approach;
- the reason for leaving the previous path.

Do not wait for successful activation and reconstruct this decision afterward.
The decision and its eventual outcome are separate observations.

## Cave-Specific Behavior

### Mushroom Cave

- Preparation: none.
- Activation: press the interaction input once.
- Success: the keeper's movement speed increased from the value observed before
  activation.

The teacher does not need to inspect Buff origin, amount, duration, cooldown,
last user, or other Mushroom Cave internals. Those details belong to the game's
implementation rather than the agent's behavioral result.

### Scanner Cave

- Preparation: search known cache positions for the nearest cache containing
  more than two iron resources, take exactly two iron resources, and bring them
  to the Scanner Cave.
- Activation: after delivering the required iron, press the interaction input
  once.
- Success: the map reveal distance increased from the value observed before
  activation.

Known caches are frame-derived teacher knowledge. The preparation must not
search hidden map state for iron or for another Cave.

Do not inspect, persist, or validate Scanner receiver internals by default. In
particular, receiver progress, `spent`, arrival counters, and animation phases
are not part of the interaction contract. If a real recording later shows that
the observable reveal-distance result is insufficient to diagnose or resume a
failed delivery, first add narrow telemetry for that demonstrated failure. Add
the smallest necessary receiver state only when the evidence proves it is
required.

### Helmet Cave

- Preparation: none.
- Activation: press the interaction input once.
- Success: the keeper's mine camera zoom changed from the value observed before
  activation.

The teacher does not need to inspect `hasHelmet` after activation or require a
particular zoom constant. The observable camera capability change is enough.

### Portal Cave

- Preparation: use an ordinary ore resource that the keeper is already
  carrying; otherwise take the nearest reachable ordinary ore from a known
  cache.
- Activation: carry the resource into the Portal's passive entrance. Do not
  press the interaction input.
- Success: the selected resource detached and the matching stored-resource
  inventory increased from the value observed before entering the Portal.

The Portal remains eligible whenever it is revealed and another cached resource
can currently be delivered. The teacher does not keep a completed-Portal list
or inspect cooldown, overlap lists, gravity state, animation, or other receiver
internals.

## Adding Another Cave Type

Keep the shared flow unchanged. Add only:

1. the minimum preparation that must occur before activation; and
2. one player-visible success observation.

Do not introduce Cave-specific routing, completion markers, validation layers,
or interruption machinery unless an observed failure cannot be handled by the
shared task stack, acquisition, recording, and live interactability checks.

## Relic Hunt Behavior

A revealed Relic Switch Chamber is excavated and activated through its exact
usable. It completes when its live Chamber state becomes `EMPTY` and the
activation animation removes that usable. If the root search already remembers
an excavated Relic Chamber, completing a switch immediately revisits that chamber
to observe whether it opened; otherwise the root fishbone search scans a bounded
14-tile area from the Engineer's open tile beside the switch before resuming its
global frontier search. This matches the supported map's generated switch range
without reading the hidden Relic Chamber position. Ordinary ore veins and
post-wave cache cleanup do not interrupt this bounded search.

A revealed Relic Chamber is excavated and observed after one bounded state
settling interval. If it remains locked, the root relic search remembers the
exact chamber and scans its bounded generated switch area upward and then
downward before resuming global frontiers. The remembered locked chamber is not
reclaimed by the periodic local scan. Each later switch
activation triggers one explicit revisit instead, so the teacher neither reads
hidden switch positions nor hard-codes a switch count.

When the chamber opens, the teacher activates its exact usable with no unrelated
cargo. The game attaches the final Relic directly; only a later detachment uses
the shared exact-artifact recovery. The teacher carries it to the dome through
normal movement and completes the interaction when the corresponding stored
Relic inventory increases. The game-created final wave then uses the ordinary
`DEFEND` scheduling and authoritative `game.over` outcome.
