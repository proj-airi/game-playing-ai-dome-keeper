# TODO

This document owns confirmed maintenance, cleanup, and behavior-correction work. An item authorizes only its stated scope and does not settle unstated architecture or design choices.

## Teacher Controller Cleanup

- After a fresh gameplay recording and teacher log confirm the current shaft-shift and descent-backtracking behavior, schedule a dedicated teacher cleanup before further controller expansion without turning it into a blanket gate on urgent fixes. Establish explicit expected observable outcomes for the representative lifecycle scenarios in scope rather than preserving one recording's exact action trace. Audit the current code and state-machine logic for dead or duplicated paths, unreachable transitions, unclear state ownership, accidental coupling, and contradictory invariants; identify responsibility boundaries without presuming that every large function or file must be split. Keep each batch independently reviewable and verifiable. Pure refactors must preserve the declared outcomes, while defect or policy corrections must declare the corrected expectation and receive targeted runtime validation.

## Relic Hunt Runtime Validation

- Capture a fresh run that exercises Relic Chamber and switch discovery in both
  orders, exact relic pickup and dome delivery, the automatically scheduled
  final `DEFEND`, and terminal `run_won`. The wave-20 checkpoint replay on
  2026-08-02 reached wave 31 without a teacher failure but lost before seeing a
  relic interaction while an older Drone water search, resource cleanup, and
  recurring Iron Tree interactions remained stacked above the root search. Do
  not count that replay as end-to-end Relic Hunt validation or change the relic
  chain to compensate for an unexercised path.

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
  Repository configured runs are replay-only and persist batched events directly
  to the final append-only JSONL. Headless fixed-FPS runs omit video; optional
  Movie Maker runs record at `1280x720` with VSync forced off only for that
  process.
  Keep the declared FPS unchanged within each performance comparison, and do
  not present a lower capture rate or dropped confirmed telemetry as a fix for
  the underlying slowdown. Preserve ordinary manual YOLO collection for later
  label work.
- Windowed replay throughput does not improve when the window is shrunk: the
  game renders its `1920x1080` canvas baseline under `canvas_items` stretch
  regardless of window size, and a same-seed `640x360` window measured ~11.9x
  versus ~11.5x at `1280x720` (10 FPS, no movie). Keep the fixed `1280x720`
  windowed mode; headless (~46x) remains the speed lever, and do not add a
  resolution-reduction code path.
- Bound JSONL and movie growth per fixed game minute, and validate the final
  replay flush and synchronized playback after a representative run beyond wave
  20. Do not prioritize the built-in AVI size boundary based on file size alone:
  the current recording beyond 4 GB remained readable and converted with an
  exact frame count. Revisit a fixed-timeline segmented or custom writer only
  after a representative recording is actually unreadable or fails conversion;
  do not switch to an external wall-clock recorder.

## Automated Recording Lifecycle Validation

- Validate the repository replay command's headless, windowed, and Movie Maker lifecycles
  in fresh won and lost runs. It waits for the supported single-player Engineer and Laser
  run's Keeper input to become active, starts the rule teacher and replay without
  the pause-menu button, treats authoritative `game.over` values as terminal,
  appends `run_won` or `run_lost` with the final complete snapshot, flushes the
  JSONL, and requests a normal Godot shutdown. Confirm ordinary launches and
  manually started YOLO collection remain unchanged. Confirm invalid recording
  configuration, an unsupported run, teacher failure, manual window closure in
  Movie Maker mode, malformed JSONL, and a missing terminal event all preserve
  incomplete artifacts and report failure. Movie Maker failures skip MP4 conversion.
- After Godot has exited successfully, transcode only that session's exact AVI
  to its MP4 destination and verify that the conversion completed successfully.
  Delete that exact AVI only after the MP4 passes the chosen validation; keep
  the AVI, replay, and diagnostic output on conversion or validation failure.
  Do not use globs, directory-wide cleanup, age-based pruning, or deletion that
  can affect another recording session.

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
  defense takeover deadlines, and task-stack interruption restoration.
- Use the new evidence to choose the smallest towing correction, such as
  stretch-aware movement pauses, cargo contraction before turns, or an adaptive
  load limit. A four-resource limit is permitted only as a bounded experiment
  from the current recording, not as a permanent level-based rule. Do not alter
  collision masks, tether distance, pull impulses, or resource positions, and
  do not treat another carry-strength purchase as a fix for rigid-body loss.
