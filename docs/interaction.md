# Local Interaction Model

This document defines the shared discovery and approach behavior for nearby
interactable objects in the mine. Ordinary ore, Gadget Chambers, Supply
Chambers, and supported natural Caves use the same local scan. Relic Chambers
are classified by the same model but remain ineligible until Relic Hunt behavior
is supported.

The teacher treats an interaction as a locked, short deviation from ordinary
exploration, not as a separate defensive state machine. Interaction types share
discovery, approach choice, decision recording, and return to the saved path.
A subtype supplies only the preparation and observable result required by that
game object.

The scan claims one target, records `interaction_decided`, and enters
`INTERACTION`. The locked ore, Chamber, or Cave target identifies the handler;
there is no parallel interaction-type state.

## Shared Interaction Flow

1. On the controller's existing fixed tick, scan eligible objects whose
   straight-line map distance from the keeper is less than `10` tiles.
2. Ignore unrevealed objects. A scan result is eligible only when its public
   game state says work remains and the teacher supports that subtype.
3. Select one target in priority order: Supply Chamber, Gadget Chamber,
   supported Cave, then ordinary ore. Within a category choose the nearest
   target.
4. Lock that target until completion, invalidation, or a mandatory wave
   interruption. Do not rerank while the local interaction remains active.
5. Estimate the travel time of the shortest A* route to a reachable interaction
   boundary from path length and current movement speed.
6. Estimate the time to reach the target directly from the intervening tiles,
   current drilling strength, and movement time.
7. Use the A* route when it is no slower. Dig directly toward the target when the
   A* estimate is longer.
8. Identify the interaction type and subtype and record the decision before
   leaving the current path. The event must explain why the teacher deviated
   and which approach it chose.
9. Enter `INTERACTION` and approach the locked target by the selected route.
10. Perform only the preparation required by that subtype.
11. Activate the object through configured normal input when its subtype
    requires activation. Enter the target area without pressing interaction
    when the game's interaction is passive.
12. Judge success from the smallest public state or player-visible capability
    change for that subtype.
13. Record completion or failure, including the observed state change and
    reason, then resume the path and task that were active before the deviation.

A mandatory wave expires the local scan and clears its unfinished target. After
defense, ordinary exploration resumes and scans again from the keeper's current
position. A distant ore, Chamber, or Cave does not become a cross-map mission
merely because it was once within radius `10`. Exact artifact transport that has
already begun remains mandatory and is not a local scan target.

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

After one successful delivery, the teacher does not route to that Portal again.
It does not inspect Portal cooldown, overlap lists, gravity state, animation,
Drop identity history, or other receiver internals.

## Adding Another Cave Type

Keep the shared flow unchanged. Add only:

1. the minimum preparation that must occur before activation; and
2. one player-visible success observation.

Do not introduce Cave-specific routing, checkpoint fields, validation layers,
or interruption machinery unless an observed failure cannot be handled by the
shared mining, carrying, recording, and local rediscovery behavior.
