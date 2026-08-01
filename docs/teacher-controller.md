# Rule Teacher Controller

This document owns the supported gameplay scope, state ownership, and binding
behavior policies of the current in-process rule teacher. Read it before
changing teacher state, navigation, collection, upgrades, defense, recovery, or
runtime input behavior.

Statements under policy headings declare required behavior. The state-machine
section also describes statically observed code routing; a listed code path is
not runtime proof, and a code-policy mismatch is a defect rather than permission
to weaken the policy.

## Current Supported Scope

- The supported run is manually started, offline, and single-player, with one
  local keyboard-controlled Engineer and the normal Laser Dome.
- The teacher currently covers fishbone exploration, revealed ore mining,
  resource pickup and delivery, supported Gadget Chamber retrieval and choice,
  artifact-choice water rerolls, Power Core Chamber activation and Supplement
  choice, opportunistic `ScannerCave` and `DroneCave` side tasks, return,
  upgrades, simple Laser defense, and bounded stuck recovery while the collector
  produces ore/enemy YOLO image-label pairs.
- The user starts a fresh run. An explicit recording-time debug checkpoint may
  instead restore a previously supported run; automated loadout or menu
  navigation and restart after death are not supported.
- Starting collection inside a station supports only the normal
  `StationInputProcessor` or `BattleInputProcessor`. Startup while an upgrade or
  another station modal remains open must be rejected.
- Multiplayer, other keepers, non-Laser weapons, and Relic Hunt completion are
  outside the current supported scope. Later capability work belongs in
  [`roadmap.md`](roadmap.md).

## Compatibility Boundary

- The superseded teacher state machine and its runtime wiring were intentionally
  removed before the current seven-state controller was implemented and
  connected to the collector. Do not reintroduce the old implementation or a
  compatibility shim for it.

## Gameplay Mechanics

- The Engineer mines by moving into a tile with the drill; tiles have
  health/hardness and take multiple hits to break.
- Resources must be picked up and carried. Carrying slows movement, and
  carry-strength upgrades reduce the slowdown.
- The Engineer has dedicated pickup and drop actions for carrying resources
  (Space and Q by default).
- Drill-strength upgrades make the drill stronger and allow harder rock to be
  mined more efficiently.

## Runtime and Action Boundaries

- Emit only normal configured keyboard actions. Do not directly change keeper
  movement, weapon input fields, Laser transforms, or other game state, and do
  not use OS-level input injection.
- Keep ordinary gameplay unpaused during movement, mining, resource handling,
  return, defense, and recovery. The TechTree's gameplay pause is permitted only
  while `UPGRADE` operates that popup through configured in-process actions.
- While collection is active, save and temporarily disable
  `Options.pauseWhenOutOfFocus` and `Options.useMouseDomeGameplay`, clear
  `InputSystem.game_not_in_focus`, and keep `Input.MOUSE_MODE_VISIBLE`. Restore
  both prior options when the teacher stops and do not persist the overrides.
- These overrides must let the user focus and operate another macOS application
  while the teacher continues emitting configured in-process keyboard events.
- Disabling mouse dome gameplay prevents incidental mouse movement after focus
  changes from replacing simultaneous keyboard steering and fire with a stale
  mouse target.
- Normal state logic runs on a fixed real-time tick. Active Laser aiming and
  firing run on physics ticks to match the weapon update cadence.
- Operate the TechTree popup only in `UPGRADE`. The YOLO dataset exclusion for
  TechTree frames is owned by [`vision.md`](vision.md).

## Seven-State Controller

The controller in
[`rule_teacher.gd`](../mods/LemonNekoGH-YoloDataCollector/rule_teacher.gd) has
seven top-level states. It is hierarchical and event-driven rather than a fixed
linear sequence: exploration modes, mining outcomes, cache-cleanup modes,
upgrade arbitration, Gadget, Power Core, and natural Cave task context,
asynchronous game events, and the shared artifact-choice modal alter routing
without adding top-level states.

| State | Owns | Possible next states |
| --- | --- | --- |
| `EXPLORE` | Saved-work travel and the fishbone mining pattern | `MINE`, `CARRY`, `RETURN`, `RECOVER` |
| `MINE` | Ore and chamber excavation, chamber opening, and detached-artifact clearance | `EXPLORE`, `CARRY`, `RETURN`, `RECOVER` |
| `CARRY` | Resource pickup plans, physical chamber or Cave input delivery, artifact activation, and exact reattachment | `MINE`, `RETURN`, `RECOVER` |
| `RETURN` | Travel to the main Laser station and station task arbitration | `EXPLORE`, `MINE`, `CARRY`, `UPGRADE`, `DEFEND`, `RECOVER` |
| `UPGRADE` | Normal-input TechTree navigation and confirmed purchases | `RETURN`, `DEFEND` |
| `DEFEND` | Battle-input entry, Laser aiming and firing, and wave settlement | `EXPLORE`, `MINE`, `CARRY`, `RETURN` |
| `RECOVER` | Bounded movement probes after a directed-action stall | The interrupted state or `RETURN` |

Failure is not an eighth state. Mandatory modal or UI failures and unsupported
required runtime states fail closed, emit the teacher's `failed` signal, and
stop collection. Ordinary policy exhaustion may instead prune an upgrade intent
or leave mining blocked inside `EXPLORE`.

### Startup and Shared Routing

- Starting outside a station selects `EXPLORE`. Starting inside a station with a
  supported input leaf selects `DEFEND` for `BattleInputProcessor` and otherwise
  selects `RETURN` for normal station task selection.
- Each actual state change through the shared transition helper releases held
  actions, applies the short transition delay, resets pickup-failure and
  movement-progress tracking, and records the old state, new state, and reason.
  Startup selects its initial state directly and is not recorded as a
  transition.
- Leaving active mining work in `EXPLORE` for a non-navigation task saves the
  keeper's current map coordinate, which policy requires to be open, and its
  `DESCEND` or `BRANCH` continuation when no saved continuation exists.
  `RECOVER` is excluded because it resumes the interrupted state directly.
- Leaving `CARRY` clears the concrete Drop and live carry plan except when
  entering `RECOVER`. Leaving `UPGRADE` clears the opportunity-local repair
  target and re-evaluates the persistent repair intent.
- The mandatory `GadgetChoiceInputProcessor` is a cross-cutting modal for both
  exact Gadget and Power Core Drops. It temporarily owns input without changing
  the top-level state, dispatches policy by exact popup `droptype`, then restores
  that state after authoritative popup closure.
- Detecting the exact carried chamber Gadget outside acquisition forces
  `RETURN`; it must be transported alone. Unsupported modal/input state blocks
  action emission without inventing another teacher state.
- Open-map A* is shared by several states, with a normal-input dome-departure
  bridge when travel starts inside the dome. Each state owns its reason and
  target: `EXPLORE` restores saved work, `MINE` reaches excavation approaches,
  `CARRY` reaches pickups or Usables, and `RETURN` reaches the dome and station.
- The binding recovery policy enters `RECOVER` after four seconds of held
  directional input without a one-tile directed move or effective drill hit in
  states other than `UPGRADE`, `DEFEND`, and `RECOVER`.

### `EXPLORE`

`EXPLORE` owns saved-work navigation, new fishbone tunneling, descent
backtracking, and safe idle waiting. It never picks up resources.

It is entered when collection starts outside a station; `MINE` clears its ore
task; `RETURN` closes a station with no task; `DEFEND` settles with keeper input
already active; or `RECOVER` completes a probe for interrupted exploration.

Its priority order is:

1. claim a revealed, visible-in-tree Gadget Chamber and enter `MINE`, or
   `RETURN` if an active wave preempts it;
2. respond to an active wave, active cache cleanup, descent backtracking, or a
   station task while mining is blocked;
3. enter `CARRY` when a dynamically safe resource plan opens;
4. enter `RETURN` when the current position and load exhaust the wave-safe
   return budget;
5. use open-map A* to restore a saved work coordinate and continuation;
6. enter `MINE` for the nearest currently visible revealed ore vein; and
7. continue the current fishbone mode.

The fishbone modes remain inside `EXPLORE`:

- `DESCEND` drills toward the next branch row. Reaching it saves the exact shaft
  intersection and changes to `BRANCH`; confirmed border below changes to
  `BYPASS`.
- `BRANCH` drills one side at a time. A confirmed border endpoint sends the
  keeper back to the exact intersection. The first side reverses direction; the
  second records the corridor, advances the row, and resumes `DESCEND` after the
  return.
- `BYPASS` searches right first for a column whose tile below is not confirmed
  border. It reverses once when the first side reaches border. Border on both
  sides terminates only that descent frontier, activates cleanup, and enters
  `CARRY` when cleanup can start safely or `RETURN` otherwise.

`EXPLORE` enters `RECOVER` under the shared stall condition. Mining-blocked,
wave-unsafe backtracking, dome-waiting, and fishbone mode changes remain within
`EXPLORE`.

### `MINE`

`MINE` owns destructive work: clearing an ordinary revealed ore vein without
pickup, excavating a claimed Gadget Chamber and waiting for it to open, or
clearing allowed revealed neighbors around a detached Gadget's fixed recovery
coordinate.

It enters `EXPLORE` when the ordinary vein is clear; `CARRY` when a safe resource
window opens, a chamber reaches `OPEN`, or detached-Gadget clearance completes;
`RETURN` when a wave, return deadline, unsafe carry opening, or authoritative
Gadget handoff preempts it; and `RECOVER` under the shared stall condition.

Temporary `RECOVER` interruption preserves the active mining task. Ordinary ore
completion or preemption records the active vein as a cache site before clearing
its live target.

### `CARRY`

`CARRY` owns acquisition rather than delivery. Resource work executes a bounded
quota, reselects interchangeable Drops by unmet demand and then open-path travel,
rechecks the real next leg against wave safety, and uses the configured pickup
action. It stores resource-type counts rather than a route of Drop identities.

Gadget work unloads resource cargo, activates the exact focused chamber
`Usable`, waits for the newly spawned exact Gadget to attach, and reacquires the
same Gadget after bounded detachment clearance.

It enters `MINE` when the chamber still needs excavation; `RETURN` when a wave
starts, the plan ends, the next pickup becomes unsafe, bounded pickup/path
failures are exhausted, or the exact Gadget attaches; and `RECOVER` under the
shared stall condition.

### `RETURN`

`RETURN` owns physical return and station task arbitration. Outside the station,
it uses open-map A* only to reach the mine mouth, moves upward along the dome
shaft to the main Laser station height, aligns with that exact `Usable`, and
enters through normal input. It never deliberately enters an optional cellar
station.

Inside the station, it resolves tasks in this order:

1. finish mandatory exact-Gadget delivery, handoff, or detachment recovery;
2. for a saved Gadget Chamber task, enter `DEFEND` while a wave is active or
   settling, and otherwise close the station and resume `MINE` or `CARRY`;
3. absent Gadget preemption, enter `UPGRADE` for the affordable selected target
   from the highest nonempty intent class;
4. enter `DEFEND` for any other active or imminent wave; and
5. otherwise issue the normal station-close action while entering `EXPLORE`, so
   the still-focused computer cannot be entered again.

If the exact Gadget detaches before authoritative handoff, `RETURN` freezes its
coordinate and enters `MINE` for bounded clearance. Ordinary outside-station
navigation can enter `RECOVER` under the shared stall condition.

### `UPGRADE`

`UPGRADE` owns one station upgrade opportunity. It freezes the selected intent
and current concrete runtime target, opens and navigates the TechTree through
configured actions, and accepts a purchase only after the matching game signal.

After a confirmed purchase it re-resolves pending intents and runtime costs and
may buy another affordable selected target in the same popup. It closes normally
when no selected target remains affordable or repair reaches its frozen target.
Once `StationInputProcessor` returns, it enters `DEFEND` if defense is required
and otherwise `RETURN` for fresh station arbitration. Purchase rejection or
bounded UI-navigation exhaustion fails closed.

### `DEFEND`

`DEFEND` owns the battle station lifecycle. It opens battle input when required
and aims on physics ticks while a monster wave is present. During the supported
in-station path it does not leave merely because `wavepresent` ended; it waits
for `wavebattle` settlement.

It enters `RETURN` if the keeper leaves the station, settlement restores station
input, or a settled Gadget interruption needs station arbitration; `EXPLORE` if
settlement already restored keeper input; and `MINE` or `CARRY` when keeper input
can immediately resume the saved Gadget phase.

### `RECOVER`

`RECOVER` records the interrupted movement state and probes clockwise beginning
with the direction immediately after the failed one. Each probe continues until
the keeper moves one directed tile. The policy says an effective drill hit
resets the probe's four-second timer but does not complete recovery.

A one-tile move resumes the interrupted state. A timeout advances to the next
direction; four timed-out directions fail closed. Any active wave enters
`RETURN`; interrupted `DESCEND` or `BRANCH` first saves the probe coordinate and
continuation when no saved target exists.

### State Preserved Across Interruptions

- During ordinary nonterminal interruption, saved work and its `DESCEND` or
  `BRANCH` continuation survive mining, carrying, return, upgrade, defense,
  cleanup, and recovery. Terminal-frontier handling intentionally replaces that
  continuation with backtracking.
- Branch row, direction, exact intersection, completed corridor cells, and exact
  attempted descent origins preserve fishbone/backtracking progress.
- Pending upgrade intents survive top-level state changes. They may be cleared
  by a matching fulfilling purchase, authoritative exhaustion, or, for repair,
  satisfaction of the health-reserve condition.
- Cache sites and cleanup state survive waves and repeated `CARRY`/`RETURN`
  trips until no known reachable cached resource remains.
- Claimed chamber identity, exact Gadget identity, delivery flag, recovery
  coordinate, and bounded recovery count survive wave and station interruption
  until authoritative delivery and choice complete.
- The claimed Power Core Chamber and selected physical water survive wave
  interruptions. After attachment, the Power Core uses the same exact-Drop
  transport and bounded recovery state as a chamber Gadget.
- A claimed Scanner or Drone Cave, its exact reserved physical input, receiver
  progress, and Scanner activation state survive wave interruption. The teacher
  resumes the bounded side task after defense and clears it only after checking
  the exact resulting reveal distance or owned helper.
- Event-driven wave-health tracking preserves the inputs intended for post-wave
  combat and repair decisions across state changes.
- Debug checkpoints preserve these same teacher decisions across processes.
  Runtime object identity is stable only through saved Drop UIDs and restored
  Chamber/Cave coordinates; input bindings, held actions, replay buffers,
  pathfinding previews, and live Laser observations are rebuilt after load.

## Supported Natural Cave Tasks

- Claim only a revealed and reachable `ScannerCave` or `DroneCave` encountered
  during ordinary exploration. Never inspect hidden map data, select a frontier
  to search for a Cave, or retain a completed Cave as a revisit waypoint.
- A Scanner task reserves and carries two exact loose iron Drops, one to each
  unspent receiver, activates the exact focused `Usable` through configured
  input, and succeeds only after the Cave consumes its scanner and
  `map.revealdistance` authoritatively becomes `2`.
- A Drone task reserves and carries one exact loose water Drop to its receiver.
  It succeeds only after opening finishes and the Cave's dispatcher owns a
  team-matching Squidley created by the exact target-version script.
- Gadget acquisition may suspend either Cave task. Active or imminent waves and
  hard return deadlines drop any attached Cave input into the ordinary cache,
  preserve authoritative receiver progress, and resume the same task after
  defense. Missing exact nodes, inconsistent lifecycle state, or exhausted
  bounded interaction retries fail closed.

## Exploration and Mining Policy

- Do not add an `ALIGN` submode or a separate top-level travel state. Use
  `DESCEND`, `BRANCH`, and `BYPASS` only to open new tiles; use open-map A* for
  travel over confirmed-open coordinates.
- When departing from the Engineer spawn marker or from the main Laser keeper
  marker after the computer closes, build the mine path from the confirmed-open
  shaft mouth through map A*. Prepend normal-input-realizable orthogonal waypoints
  from the keeper's actual position horizontally to the runtime dome shaft
  x-coordinate and vertically toward the mouth. Keep the bridge outside the
  shared map graph and never hard-code team-one coordinates.
- Accept an authoritative reveal distance of one or two tiles. Fishbone spacing
  is `1 + reveal_distance * 2`: three rows normally and five rows after the
  Scanner Cave applies reveal distance two. Any other value is unsupported and
  fails preflight.
- Use only revealed Tiles, recorded open coordinates, and the open A* graph for
  planning. Never inspect hidden resource or map data and never infer full map
  completion from one terminal pocket or an exhausted recorded frontier set.
- Before `DESCEND` or `BRANCH` is preempted, freeze the exact open work coordinate,
  mode, and branch direction. A newly claimed Gadget Chamber must freeze this
  continuation before `MINE` moves the keeper. Return by open A* and resume only
  after reaching the exact saved coordinate.
- For non-adjacent revealed ore, compare the shortest open-approach ETA with
  direct cardinal tunneling. The tunneling ETA may use movement time and only
  revealed intervening Tiles' remaining health, runtime drill strength,
  hard-tile modifier, per-hit cap, drill buff, and hit cooldown. Use open travel
  only when strictly faster; direct tunneling wins ties or the absence of an open
  approach.
- Ordinary `MINE` clears the connected revealed vein without pickup, records its
  loose resources as a cache site, and resumes `EXPLORE` absent preemption. A
  revealed adjacent border is a known branch endpoint: return to the exact shaft
  intersection, do the other side, then advance the branch row. Do not enter
  `RETURN` or probe the border through `RECOVER` merely because of that endpoint.
- On a border below `DESCEND`, preserve the target branch row, search right
  first, reverse once, and adopt the first column whose tile below is not
  confirmed border. Center on its exact open coordinate before descending.
- Border on both bypass sides terminates only that frontier and forces persistent
  cleanup even below its normal threshold. Search completed branch corridors
  newest to oldest for later descent origins, record only actually traversed
  open cells, key attempts by exact origin, never retry one, and restore each
  corridor's own row plus branch spacing.
- Rank legal backtracking origins by open A* travel and require a dynamically
  wave-safe round trip before freezing one. A temporarily unsafe origin remains
  unattempted while the teacher waits through the wave. A movement stall enters
  `RECOVER`; it is not evidence of geometric exhaustion. With no legal recorded
  origin, report mining blocked while continuing upgrade and defense work.

## Resource Collection and Return Policy

- Do not store a requested level, concrete upgrade ID, or cost in either the
  pending intent set or a carry plan, and do not store concrete Drop routes in a
  carry plan. Resolve current upgrade targets and runtime costs during
  reservation and purchase.
- Reserve stored and carried resources through the same resource-aware class
  arbitration used for purchase. When a higher class has no affordable target,
  reserve every positive-cost resource type used by its current targets. A later
  class may use other resource types, but never a reserved type. Consume each
  fully funded selected cost before recalculating candidates and the next
  deficit so no mineral is counted twice.
- Open the resource `CARRY` window when a load-capped preview's collection ETA,
  loaded return ETA, and two-second station-entry margin reach the remaining wave
  time. The margin represents the observed 1.6–2.0 seconds from dome entrance to
  main-station task selection.
- Refresh the pathfinding-heavy preview at most once per second and invalidate it
  immediately after cache, pickup, or upgrade changes. While mining, include the
  active vein as a temporary cache so existing loose Drops can participate.
- On resource `CARRY` entry, diagnose mobility from the preview and rebuild the
  bounded plan once so a new mobility intent affects current-trip reservation.
- Plan across all reachable known cache sites. Rank the next pickup by earliest
  unmet resource demand and then open-path time; use current load for outbound
  legs, prospective load for return, include pickup delay, and admit a pickup
  only when the complete plan still meets the station margin.
- Store quota counts by runtime resource type and reselect the nearest valid
  matching Drop during execution. Recheck the actual next leg against the hard
  wave budget. Same-type Drops remain interchangeable; behavior for overlapping
  Drops of different types remains undecided. When an unresolved resource
  endpoint produces no directional input, consume the bounded pickup failure
  budget instead of treating a nonempty path as movement progress. Active cache
  cleanup excludes the repeatedly failing Drop before returning.
- The 15-second return target diagnoses mobility pressure only. It does not
  forbid a wave-safe pickup, trigger cleanup, or control live pickup admission.
- Funding one intent does not end collection. Continue toward later deficits,
  and treat resources that reduce no current deficit as lower-priority filler. A
  pending intent or deficit is not required for a safe filler trip.
- During ordinary resource `CARRY`, enter `RETURN` when the next pickup would
  cross the 55% speed-ratio floor, the wave-safe budget is exhausted, no planned
  cached resource remains, or bounded pickup/path failures are exhausted.
- If return finishes before the station-entry window, exit the station once.
  While the dynamic direct-return deadline is active, wait inside the dome but
  outside the station without resuming descent or repeatedly entering. Otherwise
  ordinary `EXPLORE` may resume. Re-enter when remaining wave time reaches the
  same two-second station-entry margin or another confirmed station task requires
  it.

### Cache Cleanup

- Latch cleanup while mining when known reachable cached resource Drops reach
  twice the current full-load count under the 55% speed-ratio floor. Do not
  interrupt the current mining period at the threshold.
- Activate cleanup after the next settled `DEFEND` and its post-defense upgrade
  opportunity, then start through `CARRY` only after `Keeper1InputProcessor`
  becomes active.
- Execute as many dynamically wave-safe `CARRY`/`RETURN` trips as needed,
  including a final partial load. Preserve cleanup and interrupted fishbone work
  through wave, return, defense, and upgrade interruption.
- Clear cleanup only when no known reachable cached resource remains. Drops
  rejected by the bounded path/pickup failure policy must not block cleanup
  forever.

## Gadget Retrieval and Choice Policy

- Treat a revealed Gadget Chamber as part of the current teacher loop, distinct
  from the final Relic Hunt relic. It preempts ordinary ore, resource collection,
  affordable upgrades, and merely imminent waves; only an already-active monster
  wave and its settlement may interrupt excavation or activation.
- Keep the target-version Gadget inventory and compatibility policy in the
  standalone data-only `gadget_catalog.gd`. List every canonical base Gadget ID,
  document what it does and why it is supported or rejected, store only facts not
  authoritative in game data, normalize team/player-prefixed runtime IDs, and
  fail closed for unknown IDs. Preload the catalog from the teacher so selection
  and the normal Godot parse check consume the same policy source.
- Classify each offer independently by gameplay benefit and controller impact.
  Initial benefit labels are combat, survival/repair, movement, drilling, and
  carrying/logistics. A label never grants support: only exact versioned IDs on
  the allowlist are selectable after their complete base semantics have been
  validated. A no-new-key Gadget may still be unsupported when it changes
  pathfinding, resource ownership or motion, usable focus, carried-object types,
  transient stats, or another planner assumption.
- Rank supported offers by the pending intent selected through current class
  arbitration, including the chosen mobility arm; then use deterministic
  canonical-ID order. When no non-shred offer is supported, select the exact
  `shredgadgettocobalt` fallback. Gadget selection never clears the corresponding
  upgrade intent.
- In either a Gadget or Supplement choice, reroll when the current best offer
  does not benefit the selected intent, the normal reroll button is visible and
  enabled, and stored water is nonzero. Do not reserve water in advance. Submit
  the focused button through normal UI input and re-evaluate each regenerated
  offer set; when no reroll is available, select the current supported offer or
  shred fallback.
- Handle `GadgetChoiceInputProcessor` as a mandatory cross-cutting modal, not a
  top-level state or `UPGRADE`. Wait for authoritative offers and animation
  readiness, freeze one target, navigate only through configured `ui_*` actions,
  submit `ui_select` once, wait for processor closure, and require a selected
  non-shred ID to appear in `GameWorld.boughtUpgrades`. Never call popup, focus,
  or server-selection methods directly.
- Excavate only the chamber's revealed remaining cover, wait through
  authoritative `OPENING`, and activate the exact focused `Usable`. Require an
  empty load; when carrying resources, use the configured drop action, record
  them as a cache, and resume the chamber instead of making an unloading trip.
- Keep Gadget Drops outside the resource quota planner. Confirm both chamber
  `EMPTY` and deferred attachment of a newly spawned exact
  `Drop.type == CONST.GADGET`; the broader `carryableType == "gadget"` category
  is insufficient. Freeze delivery until the exact Gadget popup completes and
  operate only a popup whose `droptype == CONST.GADGET`.
- Treat disappearance of the exact carried Gadget as delivery only after
  authoritative handoff makes it independent or absorbed, or removes it while
  opening the choice flow. If the same live Drop detaches first, freeze its map
  coordinate and preserve recovery through waves.
- Recovery may clear only already-revealed, destructible ordinary dirt or
  resource Tiles in the eight neighboring cells around that fixed coordinate.
  Skip the center, border, chambers, relic structures, nests, and every other
  special Tile type; record mined resource areas as caches, then reacquire only
  the exact Drop through `CARRY`.
- Permit three complete detachment recoveries and fail closed on the fourth. Do
  not recenter the clearance window as the rigid body drifts, add a top-level
  state, teleport the Gadget, or alter collision masks.

## Power Core Chamber and Supplement Policy

- Identify a Power Core Chamber by exact `drop_type == CONST.POWERCORE`. Once
  discovered, excavating and activating it is exclusive except for a wave or an
  already attached/recovering Gadget handoff.
- Excavate the chamber cover, then use a reachable physical water Drop from a
  known cache immediately. Before fetching water, clear the single revealed,
  destructible ordinary tile directly above the chamber's top receiver and use
  that open tile as the fixed delivery destination, so the carried Drop crosses
  the receiver's `Area2D`. If no cached water exists, continue the existing
  fishbone exploration solely for water: remember revealed ore and Gadget
  Chambers, but do not act on them until the core task completes. Require
  authoritative `ResourceGrabber.spent` before treating the water as accepted.
- Wait for exact chamber `OPEN`, unload ordinary cargo, activate its focused
  `Usable`, and require chamber `EMPTY` plus a newly attached exact
  `Drop.type == CONST.POWERCORE`. From that point, use the existing Gadget
  exact-Drop transport, detachment recovery, wave interruption, and dome handoff
  mechanics, parameterized by the Power Core type.
- Finish an already attached or recovering Gadget handoff before claiming or
  resuming a Power Core task. Neither artifact task may unload the other's exact
  Drop as ordinary cargo.
- Dispatch the resulting shared popup only when `droptype == CONST.POWERCORE`.
  Keep the target-version allowlist in `supplement_catalog.gd`, normalize runtime
  team/player prefixes, prefer an allowlisted benefit for the selected planning
  intent, and otherwise choose deterministic supported order or exact shred.
  Unknown, control-changing, planning-invalidating, or new-action Supplements
  fail closed to shred. Confirm a non-shred runtime ID in
  `GameWorld.boughtUpgrades` after popup closure. After completion, resume normal
  priority: a remembered Gadget Chamber, then remembered revealed ore, then
  ordinary exploration.

## Upgrade Policy

### Intent Arbitration

- Maintain a deduplicated set of semantic intents and seed `drill` at startup.
  The survival class (`combat`, `repair`) outranks the development class
  (`drill`, `mobility`). An affordable target in a higher class wins. When no
  target in that class is affordable, reserve every positive-cost resource type
  used by its current targets; a lower-class target may proceed only when it is
  affordable and uses none of those reserved resource types. For example, an
  unfunded cobalt-only repair must not block an iron-only development upgrade.
- Resolve every pending intent to its next current runtime target. Among targets
  in the same class that are not blocked by a higher class's resource types,
  prefer affordable over unaffordable, lower total current cost among affordable
  targets, lower total current deficit otherwise, and use `combat > repair` or
  `drill > mobility` only as the final stable tie.
- Enqueue `combat` after a settled wave whose net health loss exceeds the
  configurable per-wave limit, initially 15% of maximum health. Alternate
  confirmed combat purchases between Laser attack strength first and dome
  maximum health.
- Re-enqueue `drill` after its confirmed purchase only when a subsequently
  observed tile reaches the configurable effective-hit limit, initially five.
- For each resource carry plan, calculate the maximum load under the 55% speed
  floor and the maximum load that can return from the planned final pickup within
  the 15-second diagnostic target. Enqueue `mobility` when safe capacity divided
  by full capacity is below 75%.
- Resolve movement-speed and carry-strength targets independently from current
  runtime state, apply their `PropertyChange` semantics hypothetically, and
  prefer the arm with the larger return-time saving over the same distance/load;
  speed wins ties. A later resource plan may update the arm until `UPGRADE`
  freezes a concrete target.
- Keep each intent at most once. Treat only exact prerequisites for supported
  health and repair targets as part of those intents; ignore unrelated TechTree
  branches.

### Station Opportunities

- Provide independent ordinary upgrade opportunities before and after defense.
  A mandatory Gadget task coupled to an active wave retains the `RETURN`
  priority documented above.
- When the resource-aware selected target is affordable, enter `UPGRADE` before
  ordinary defense because upgrade input pauses gameplay. Freeze the intent and
  decision-time target, use normal UI actions, and clear fulfillment only after
  the matching purchase signal.
- Re-run arbitration after every purchase. After `wavebattle` settlement,
  resolve all candidates and targets from current state so a new survival intent
  can preempt development and resources credited during defense are usable.
- The normal post-defense path remains inside the station and returns to fresh
  station arbitration before closing, providing the independent post-defense
  upgrade opportunity.
- One opportunity may confirm multiple sequential purchases. An unaffordable
  selected target never requires a purchase.

### Repair Reserve

- Treat dome health as a bounded reserve, not a full-health target. Enqueue
  `repair` only below 40% of maximum health.
- When an opportunity first selects repair, freeze its target as
  `min(current maximum health, max(40% of current maximum health, last settled tracked wave net loss))`.
  Use zero loss before any tracked settled wave.
- Calculate net wave loss as the increase in missing health so equal current and
  maximum-health growth from a pre-defense upgrade cannot hide battle damage.
- Re-read authoritative health, addability, runtime cost, and affordability
  after every confirmed `domesandrepair` purchase. Continue until the frozen
  target, full health, or unaffordability. Do not predict a purchase count or
  recompute the target after repairs; clear the elevated target when the
  opportunity closes.

## Defense Targeting Policy

- Select deterministically from valid, alive, non-leaving `Monster` instances
  registered in the supported team's active wave. Require the monster's actual
  `getCenter()` aim point to be inside the visible viewport, and never select
  projectile-group nodes.
- Exclude `Monster.Type.WORM_ROCK` from intentional pre-aim and fire despite its
  `Monster` implementation. Leave it in the normal wave lifecycle, never let it
  authorize fire, and tolerate only unavoidable one-physics-tick incidental
  collision from cached ray/input timing.
- Revalidate the retained target on every physics tick. While it remains
  eligible, keep it without reranking against other candidates and try to kill
  it before changing targets. If it becomes ineligible, replace it immediately.
- When the retained target is currently damageable by runtime `canBeHit()` and
  `invulnerable` state, keep it. Otherwise select a damageable eligible target
  when one exists. Only when no damageable target exists may the teacher retain
  or select an eligible non-damageable target for pre-aim, and it must not fire
  at that target. Never hard-code damageability from monster type or apparent
  animation phase.
- For initial selection and required reselection, rank the applicable candidate
  tier by the smallest absolute signed angular error along the normal Laser's
  actual steering path. Break equal-angle ties by runtime monster UID and then
  instance ID. Do not rank by dome distance, alternate sides for fairness, or
  expire an otherwise eligible retained target.
- Read the enabled raycasts in the weapon's collision-priority order and consume
  their cached physics result without forcing a same-frame refresh. If their
  first collider is a different eligible and currently damageable monster,
  adopt it as the retained target and fire in the same physics tick. Never skip
  an ineligible projectile, `WORM_ROCK`, or other blocker to inspect a collider
  behind it.
- Stop steering and fire only while the exact acquired target is also runtime
  damageable. Release fire immediately when acquisition is lost. Do not use a
  fixed angular dead zone, early-fire braking, random sweeping, direct Laser
  angle mutation, or direct weapon-field mutation.
- Observe normal-Laser aiming without changing selection or control behavior.
  Live status and every replay snapshot identify the selected monster by its
  runtime UID, wave counter, and kind; include current damageability, signed
  angular error in radians, and the first collider with its enabled-ray order.
  Identify non-monster colliders by category, runtime class, and session-only
  instance ID.
  Record semantic target, damageability, and first-collider changes as replay
  events, with concrete target-switch reasons in the event header. Older replay
  files may omit the aim object.
- Leave persistent ineligible-blocker timeouts open until fresh targeting
  telemetry distinguishes transient intersections from a repeatable stall.
- Emit weapon controls only while the keeper is inside the station and
  `BattleInputProcessor` is active. Recover battle input when a wave still needs
  defense and wait for authoritative `wavebattle` settlement before the normal
  station exit path.

## Known Static Code-Policy Gaps

These findings do not relax policy. They require correction or runtime evidence:

- `DESCEND`, `BRANCH`, and `BYPASS` border reads do not independently assert
  reveal state, and adjacent-vein continuation scans the runtime ore collection
  without an explicit reveal check.
- The recovery mining callback resets a probe timer without inspecting its
  reported damage amount, so it does not independently prove an effective hit.
- Return navigation treats `dome.stations.front()` as the main Laser station,
  while preflight validates the normal Laser Dome but does not independently
  prove that the first station is its main interaction station.
