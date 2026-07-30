# TODO

This document owns confirmed maintenance, cleanup, and behavior-correction work. An item authorizes only its stated scope and does not settle unstated architecture or design choices.

## Teacher Controller Cleanup

- After a fresh gameplay recording and teacher log confirm the current shaft-shift and descent-backtracking behavior, schedule a dedicated teacher cleanup before the planned Relic Hunt expansion without turning it into a blanket gate on urgent fixes. Establish explicit expected observable outcomes for the representative lifecycle scenarios in scope rather than preserving one recording's exact action trace. Audit the current code and state-machine logic for dead or duplicated paths, unreachable transitions, unclear state ownership, accidental coupling, and contradictory invariants; identify responsibility boundaries without presuming that every large function or file must be split. Keep each batch independently reviewable and verifiable. Pure refactors must preserve the declared outcomes, while defect or policy corrections must declare the corrected expectation and receive targeted runtime validation.

## Gadget Choice Water Reroll

- Consider bounded normal-UI use of a paid water reroll during the currently
  supported Gadget choice flow. Before implementation, decide when rerolling is
  preferable to the current supported offer or shred fallback, how pending
  upgrade resource reservations constrain water spending, when rerolling must
  stop, and how the available free-reroll pool participates. After each
  confirmed reroll, re-evaluate the regenerated offers and authoritative reroll
  availability and cost before acting again. Keep Supplement rerolls outside
  this task until their acquisition flow enters the supported scope.

## Laser Targeting Runtime Validation

- Validate the corrected normal-Laser policy in a fresh recording. The teacher now retains an eligible target and tries to kill it before switching, replaces an ineligible target immediately, chooses initial or replacement targets by minimum actual turn with deterministic UID ties, pre-aims a non-damageable target only when no damageable target is visible, and lets a different eligible damageable first ray collider take over in the same physics tick. It no longer ranks by dome distance. Aim telemetry captures selected-monster identity and damageability, target-switch reasons, signed angular error, and the normal Laser's ordered first collider in Live status and replay events. Declare and check expected observable outcomes for same-tier crossings, runtime damageability changes, target death or departure, visibility loss, opposite-side candidates, and `WORM_ROCK` or projectile intersections. Preserve the intentional-target and exact-acquisition fire gates. Do not add fairness rotation, hysteresis, or an acquisition timeout unless runtime evidence demonstrates a remaining pathological switch or persistent-blocker stall.

## Long-Run Recording Performance

- Reproduce and profile the severe recording slowdown reported after wave 20 in
  the latest long run. Separate simulation and rendering cost, Godot Movie Maker
  output, viewport readback and YOLO image encoding, replay serialization, and
  post-run conversion; the conversion that starts after the game exits cannot
  explain an in-run stall. Record before-and-after simulation throughput or wall
  time per fixed game minute rather than requiring an unmeasurable absence of
  slowdown.
- Reduce the identified candidate bottlenecks while preserving exact
  fixed-frame replay synchronization, complete observer and aim telemetry, and
  the existing YOLO image-label contract whenever YOLO capture is enabled.
  Evaluate a replay-only teacher mode, batched append-only event persistence
  with finalization to the current replay JSON, and a lower movie resolution as
  separate measured changes. Keep the fixed FPS unchanged until evidence shows
  that changing the simulation and synchronization clock is safe, and do not
  hide the problem by dropping confirmed telemetry.
- Bound long-session intermediate-output growth per fixed game minute and
  validate finalization after a representative run beyond wave 20. If the
  built-in AVI writer remains an unsafe or impractical long-session boundary,
  decide a fixed-timeline segmented or custom writer separately rather than
  switching to an external wall-clock recorder.

## Automated Recording Lifecycle

- Make the repository recording command opt into an automatic lifecycle. Once
  the supported single-player Engineer and Laser run is authoritatively ready,
  start the rule teacher and YOLO collection without requiring the pause-menu
  button. Keep ordinary launches and manually started collection unchanged, and
  fail closed if the requested recording configuration or supported run cannot
  be established.
- Treat authoritative dome collapse and successful run completion as terminal
  outcomes. Capture the final outcome and complete status snapshot, stop new
  captures, flush the replay and collector output, and then request a normal
  Godot shutdown so Movie Maker can finalize its AVI. Preserve all incomplete
  artifacts and report failure on an unexpected exit or any teardown error.
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
  existing wave-safe return deadlines, and interrupted-work restoration.
- Use the new evidence to choose the smallest towing correction, such as
  stretch-aware movement pauses, cargo contraction before turns, or an adaptive
  load limit. A four-resource limit is permitted only as a bounded experiment
  from the current recording, not as a permanent level-based rule. Do not alter
  collision masks, tether distance, pull impulses, or resource positions, and
  do not treat another carry-strength purchase as a fix for rigid-body loss.

## Power Core Chamber and Supplement Choice

- Add a dedicated normal-input lifecycle for the target-version
  `PowerCoreChamber`. Keep it distinct from a natural Cave and from an ordinary
  Gadget Chamber: reveal and excavate its four cover tiles, reserve and
  physically deliver exactly one water Drop to its one-shot `ResourceGrabber`,
  wait for the chamber to open, use its `Usable` to receive the carried
  `powercore`, return that core to the dome, and complete the mandatory
  `CONST.POWERCORE` Supplement choice.
- Preserve wave-safe interruption and resumption, resource reservations,
  exclusive special-artifact transport, detachment recovery, and authoritative
  acquisition and delivery confirmation. Reuse the established Gadget Chamber
  mechanics only where their runtime semantics actually match; do not classify
  `powercore` as a Gadget or pass its popup through a Gadget-only allowlist.
- Define a target-version Supplement allowlist and selection policy before
  accepting offers. Prefer a supported combat, survival, or current-planning
  benefit over shredding, and incorporate the selected Supplement's effects
  into affected planners. Keep paid and free Supplement rerolls outside this
  item until their spending and stopping policy is confirmed separately.

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
