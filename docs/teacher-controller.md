# Rule Teacher Controller

This document owns the supported gameplay scope and task policy of the current
in-process rule teacher. Read it before changing navigation, interaction,
resource handling, upgrades, defense, recovery, checkpointing, or observation.

## Goal and constraints

The teacher demonstrates one supported normal-input play loop with the smallest
control model that can resume interrupted work:

- one manually started, offline Engineer run;
- the normal Laser Dome and keyboard bindings;
- frame-derived deployment remains the eventual target, while the teacher may
  read privileged runtime state only to produce actions, evidence, and labels;
- all movement, drilling, pickup, usable, station, battle, upgrade, and reward
  choices go through configured game inputs;
- invalid required state fails the session instead of being repaired or
  guessed.

The controller is an interruptible task stack, following the suspend/resume
shape of Valve NextBot Actions documented in
[`references.md`](references.md#game-ai-architecture). It intentionally has no
parallel top-level state machine and no general-purpose behavior-tree runtime.

## Task stack

The last task in the internal array is active. Earlier tasks are suspended and
retain only the data they own. A task re-evaluates live game state whenever it
resumes; paths and decisions are not restored as stale snapshots.

| Task | Responsibility | Completion |
| --- | --- | --- |
| `SEARCH` | Fishbone search for the relic or a requested ore type | The requested cache exists; the root relic search does not pop |
| `MINE` | Drill one revealed connected ore vein and record its cache site | No revealed adjacent ore remains |
| `INTERACT` | Complete one Chamber or Cave using its exact runtime object | The interaction's visible effect or authoritative handoff is observed |
| `ACQUIRE_RESOURCE` | Attach a requested number of physical resources from one cache | The requested load is carried |
| `CLEANUP_RESOURCES` | Collect cached resources after a wave and deliver them to the dome | No reachable cached resource remains |
| `UPGRADE` | Buy affordable pending upgrades through the station UI | No affordable pending target remains |
| `DEFEND` | Reach the Laser station and finish the wave | The wave settles and keeper input returns |
| `RECOVER` | Try bounded movement probes after a directed-action stall | One tile of progress is observed |
| `CHOOSE_REWARD` | Resolve the mandatory Gadget or supplement popup | The chosen reward is authoritatively installed or shredded |

The controller uses only two structural operations:

- push a task to suspend the current task for a concrete reason;
- pop a completed task to resume the task below it.

There is no `ChangeTo` equivalent yet because no confirmed behavior needs
same-level permanent replacement. Every push and pop releases held input,
resets progress tracking, and records the operation, reason, and task summary.

## Scheduling

Each fixed control tick applies these rules in order:

1. A mandatory reward popup pushes `CHOOSE_REWARD`.
2. An active or imminent wave pushes `DEFEND`. If an upgrade popup is open, the
   `UPGRADE` task closes it first and defense is pushed on the following tick.
3. Being at the base computer with an affordable pending target pushes
   `UPGRADE` from any ordinary task.
4. `SEARCH`, `ACQUIRE_RESOURCE`, and `CLEANUP_RESOURCES` scan for nearby
   interactables.
5. The active task performs one normal-input step.

Consequently a resource search may be interrupted by another interaction, and
any of those tasks may be interrupted by defense. Popping defense resumes the
exact interaction, acquisition, or search task underneath without a separate
"resume" state.

## Local interaction discovery

The shared discovery and approach policy is owned by
[`interaction.md`](interaction.md). In summary, the teacher periodically scans
the ten-tile radius around the Engineer, ignores unrevealed objects, and accepts
only currently usable supported ore, Chambers, and Caves. It records the
decision to interact and the reason for leaving the current route.

For each candidate, it compares:

- open-tile A* travel time to an interaction boundary; and
- straight drilling time, including tile movement and drill time.

It follows A* unless direct drilling is faster. Re-scanning live
interactability replaces target-completion lists: exhausted Chambers, Caves, and
ore simply stop qualifying. Regrowing or repeatable Caves may qualify again.

## Search and mining

The root task searches for the relic with a deterministic fishbone pattern:

- descend a central shaft;
- mine alternating horizontal corridors spaced by the current reveal radius;
- bypass a revealed border laterally until downward progress is possible;
- record completed corridor cells as possible future descent frontiers;
- choose the nearest reachable, wave-safe untried frontier when a descent ends.

A resource `SEARCH` uses the same geometry but scans only the requested ore
type, while still allowing Chambers and Caves to interrupt it. `MINE` owns the
target coordinate, connected-vein coordinates, and selected A*/direct approach.
After the vein clears it records the first mined coordinate as a cache site and
pops. The parent resource search completes only when a cache contains the
required amount. Before another task diverts the keeper, the active search
stores its current corridor coordinate; after the diversion it follows a fresh
A* path back there and continues the same fishbone phase.

## Resource acquisition and cleanup

`ACQUIRE_RESOURCE` owns the resource type, requested carried amount, selected
cache site, and current physical Drop. If no qualifying cache exists it pushes
a resource `SEARCH`; it never turns the interaction itself into an exploration
mode.

The Scanner Cave requests two iron from the nearest cache that contains at
least three iron when selected. Other resource receivers request one exact
resource. Pickup and delivery always use physical Drops and normal input.

Ordinary return-to-dome behavior does not collect resources. After a wave
settles, the controller counts currently reachable cached Drops. It pushes
`CLEANUP_RESOURCES` only when that live count reaches twice the Engineer's
current bounded full-load count. Cleanup fills a supported load, delivers it,
and repeats until no reachable cached Drop remains. Repeatedly unreachable
Drops are ignored only by that cleanup task.

## Chambers, Caves, and rewards

`INTERACT` owns its runtime target and all in-progress evidence. Defense never
invalidates this context.

- Gadget Chambers and Power Core Chambers excavate revealed cover, activate
  the normal usable, carry the exact artifact directly to the dome, recover a
  detached artifact by clearing its neighboring tiles, and wait for the
  mandatory choice popup.
- A Power Core Chamber pushes acquisition of one water before delivering it to
  the exact receiver.
- Scanner pushes acquisition of two iron, crosses the two receivers, presses
  the usable once, and succeeds only when map reveal distance increases.
- Drone pushes acquisition of one water and succeeds only when its owned
  Squidley exists after opening.
- Mushroom and Helmet press the usable once and validate movement speed and
  mine-camera zoom respectively.
- Portal chooses one ordinary cached resource and succeeds only when its
  detachment increases the corresponding stored inventory.
- Iron Tree, Cobalt, and Water snapshot currently untaken reward nodes, activate
  each through normal input, verify the exact new Drop, detach it, and record
  its cache location. Later regrowth is a future scan, not part of the current
  interaction.

Reward choice waits for authoritative offers and animation. Supported choices
are ranked by the next upgrade intent, then by stable catalog order; an
affordable visible reroll may be used for unsuitable offers, otherwise the
supported shred fallback is allowed. Closing the popup without confirming the
chosen result fails the teacher.

## Upgrades

Upgrade intents are persistent knowledge, not controller states:

- repeated drill hits request drill strength;
- material wave damage requests combat improvement;
- low dome health requests repair;
- a post-wave cleanup backlog requests mobility, alternating the less-developed
  speed or carry-strength chain.

Whenever an ordinary task reaches the base computer, an affordable pending
target pushes `UPGRADE`. The task freezes one exact target while navigating the
UI so new observations cannot redirect a purchase mid-popup. Confirmed purchase
removes a fulfilled intent and immediately re-evaluates the next affordable
target. A wave closes the menu and then pushes defense.

## Defense and recovery

`DEFEND` alone owns travel to the main Laser station. It is pushed when the wave
is active or the live path-and-load return estimate reaches the station-entry
margin. It enters battle through normal station input, aims the normal Laser at
the eligible target requiring the least signed turn, and fires only when the
selected target is currently damageable and is the first supported collider.
After the wave settles it exits battle, pops, and evaluates the live cache count
for cleanup.

Directed movement or drilling that makes no one-tile progress for four seconds
pushes `RECOVER`. It probes the four cardinal directions in bounded order and
pops after one tile of movement. A wave may push defense above recovery exactly
as it can above any other ordinary task.

## Checkpoints, observation, and failure

The official save owns game state. The sidecar stores persistent teacher
knowledge plus the task stack and stable references to Drops, Chambers, and
Caves. A missing required reference or malformed sidecar fails loading. The
current sidecar version is intentionally incompatible with the removed state
machine.

The live status and each replay event expose the task stack from active task to
root. Replay task events are `task_pushed` and `task_popped`; their `detail`
contains the affected task summary, while `reason` contains the concrete
trigger. The dashboard does not reconstruct a second controller model.

Unsupported required objects, UI state, paths, resource ownership, or observed
effects fail closed, release input, record `teacher_failed`, and emit the
teacher's `failed` signal. Failure is not a task.
