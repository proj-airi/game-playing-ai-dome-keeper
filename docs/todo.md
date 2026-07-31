# TODO

This document owns confirmed maintenance, cleanup, and behavior-correction work. An item authorizes only its stated scope and does not settle unstated architecture or design choices.

## Teacher Controller Cleanup

- After a fresh gameplay recording and teacher log confirm the current shaft-shift and descent-backtracking behavior, schedule a dedicated teacher cleanup before the planned Relic Hunt expansion without turning it into a blanket gate on urgent fixes. Establish explicit expected observable outcomes for the representative lifecycle scenarios in scope rather than preserving one recording's exact action trace. Audit the current code and state-machine logic for dead or duplicated paths, unreachable transitions, unclear state ownership, accidental coupling, and contradictory invariants; identify responsibility boundaries without presuming that every large function or file must be split. Keep each batch independently reviewable and verifiable. Pure refactors must preserve the declared outcomes, while defect or policy corrections must declare the corrected expectation and receive targeted runtime validation.

## Laser Targeting Runtime Validation

- Validate the corrected normal-Laser policy in a fresh recording. The teacher now retains an eligible target and tries to kill it before switching, replaces an ineligible target immediately, chooses initial or replacement targets by minimum actual turn with deterministic UID ties, pre-aims a non-damageable target only when no damageable target is visible, and lets a different eligible damageable first ray collider take over in the same physics tick. It no longer ranks by dome distance. Aim telemetry captures selected-monster identity and damageability, target-switch reasons, signed angular error, and the normal Laser's ordered first collider in Live status and replay events. Declare and check expected observable outcomes for same-tier crossings, runtime damageability changes, target death or departure, visibility loss, opposite-side candidates, and `WORM_ROCK` or projectile intersections. Preserve the intentional-target and exact-acquisition fire gates. Do not add fairness rotation, hysteresis, or an acquisition timeout unless runtime evidence demonstrates a remaining pathological switch or persistent-blocker stall.

## Long-Run Recording Performance

- Measure the gradual recording slowdown that was already noticeable by wave 20
  in the latest long run. Separate simulation and rendering cost, Godot Movie
  Maker output, viewport readback and YOLO image encoding when enabled, replay
  serialization, and post-run conversion; the conversion that starts after the
  game exits cannot explain an in-run slowdown. Calculate the throughput trend
  from fixed-frame replay events and matching timestamped logs rather than
  treating wave 20 as a performance discontinuity.
- Reduce the identified candidate bottlenecks while preserving exact
  fixed-frame replay synchronization, complete observer and aim telemetry, and
  the existing YOLO image-label contract whenever YOLO capture is enabled.
  Repository recording runs are replay-only, persist batched events directly to
  the final append-only JSONL, and record Movie Maker output at `1280x720` with
  VSync forced off only for the recording process.
  Keep the fixed FPS unchanged and do not hide the problem by dropping confirmed
  telemetry. Preserve ordinary manual YOLO collection for later label work.
- Bound JSONL and movie growth per fixed game minute, and validate the final
  replay flush and synchronized playback after a representative run beyond wave
  20. Do not prioritize the built-in AVI size boundary based on file size alone:
  the current recording beyond 4 GB remained readable and converted with an
  exact frame count. Revisit a fixed-timeline segmented or custom writer only
  after a representative recording is actually unreadable or fails conversion;
  do not switch to an external wall-clock recorder.

## Automated Recording Lifecycle Validation

- Validate the repository recording command's automatic lifecycle in fresh won
  and lost runs. It waits for the supported single-player Engineer and Laser
  run's Keeper input to become active, starts the rule teacher and replay without
  the pause-menu button, treats authoritative `game.over` values as terminal,
  appends `run_won` or `run_lost` with the final complete snapshot, flushes the
  JSONL, and requests a normal Godot shutdown. Confirm ordinary launches and
  manually started YOLO collection remain unchanged. Confirm invalid recording
  configuration, an unsupported run, teacher failure, manual window closure,
  malformed JSONL, and a missing terminal event all preserve incomplete
  artifacts, report failure, and skip MP4 conversion.
- After Godot has exited successfully, transcode only that session's exact AVI
  to its MP4 destination and verify that the conversion completed successfully.
  Delete that exact AVI only after the MP4 passes the chosen validation; keep
  the AVI, replay, and diagnostic output on conversion or validation failure.
  Do not use globs, directory-wide cleanup, age-based pruning, or deletion that
  can affect another recording session.

## Late-Game Save Checkpoint Debugging

- Use Dome Keeper's own save system to shorten iteration on late-game teacher
  behavior that is first reachable roughly 30 game minutes into a run,
  including natural Caves, Supply Drops, and the Relic lifecycle. Preserve
  representative saves shortly before each target encounter instead of
  replaying the entire early game after every policy change. Treat this as a
  focused debugging workflow, not evidence that a modified policy can still
  reach the checkpoint correctly from a fresh run.
- First confirm that a restored save preserves the target-version state needed
  for representative validation, including the generated and revealed map,
  mined terrain, run timer and wave progression, resources, upgrades, equipped
  Gadgets, chamber and Relic progress, player and dome state, and pending enemy
  or reward state. Record the game version, mod revision, save provenance, and
  target encounter with each checkpoint. Invalidate or regenerate a checkpoint
  when a game, save-schema, map-generation, economy, or progression change
  makes it unrepresentative or incompatible.
- Add repository automation to back up a completed game save, restore an
  immutable checkpoint into an isolated test profile, and launch a recording
  from that restored state. Restore the pristine checkpoint before every
  attempt so a previous test cannot mutate the baseline. Copy only after the
  game has completed its save write or exited normally; use explicit validated
  paths and atomic replacement where practical, and never use globs or
  directory-wide deletion that could affect ordinary player saves.
- Start each resumed evaluation early enough for the teacher to observe the
  restored world and rebuild any controller-only transient state that Dome
  Keeper does not save. Declare the warm-up interval and the exact expected
  encounter outcome in the resulting replay. Keep fresh-run regression as the
  final acceptance gate whenever a change can affect the earlier decisions,
  resources, upgrades, exploration route, or ability to reach that late-game
  state.

## Late-Game Carry Reliability

- Correct the resource-delivery loss demonstrated after movement speed level
  three and carry strength level two in narrow mined routes. Add trip-level
  evidence for planned pickups, peak attached load, return-start load,
  detachments, dome-entry load, delivered resources, predicted and actual return
  duration, and enough tether or turn context to distinguish towing loss from
  ordinary pickup, delivery, or absorption.
- A detached resource must remain authoritatively known and recoverable instead
  of being silently counted as completed or disappearing outside the recorded
  cache area. Preserve normal configured inputs, physical resource behavior,
  existing wave-safe return deadlines, and interrupted-work restoration.
- Use the new evidence to choose the smallest towing correction, such as
  stretch-aware movement pauses, cargo contraction before turns, or an adaptive
  load limit. A four-resource limit is permitted only as a bounded experiment
  from the current recording, not as a permanent level-based rule. Do not alter
  collision masks, tether distance, pull impulses, or resource positions, and
  do not treat another carry-strength purchase as a fix for rigid-body loss.

## Natural Cave Interaction Inventory

- Inventory and validate the complete target-version lifecycles for the
  confirmed requested natural Cave rewards: `MushroomCave` for the temporary
  movement-speed buff, `PortalCave` for the passive portal or black-hole-like
  resource route, `IronTreeCave` for renewable iron, `HelmetCave` for the mine
  view extension, and `DroneCave` for the water-funded Squidley helper. Record
  each type's required input, resource cost, carried-object behavior, planner or
  map effects, persistence, cooldown, success evidence, and wave interruption
  behavior.
- Share only revealed-and-reachable discovery, navigation, interruption, focus,
  and bounded normal-input infrastructure. Implement and validate one exact
  Cave type at a time: some require a focused use, `PortalCave` is passive and
  needs resource routing, and `DroneCave` consumes one physical water Drop and
  then changes resource ownership and movement asynchronously. Do not add a
  generic "activate Cave" fallback.
- Keep unvalidated Cave scenes explicitly unsupported and fail closed. Per-type
  support is complete only after the resulting buff, reveal change, resource
  source, passive transport, or autonomous helper is incorporated into every
  affected teacher planner and confirmed in a representative recording.
