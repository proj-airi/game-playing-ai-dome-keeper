# Roadmap

This document owns capability milestones, their broad ordering, and their open
design decisions. Maintenance, cleanup, and corrections to current behavior
belong in [`todo.md`](todo.md).

Roadmap entries commit only to their stated outcomes. They do not select an
implementation, interface, dataset schema, model, dependency, or training method
unless an explicit project decision says so.

## Planned Milestones

### Use Revealed Natural Cave Rewards

- `ScannerCave` and `DroneCave` are implemented in the supported rule-teacher
  loop and validated in representative recordings. The Scanner task spends two
  physical iron Drops and incorporates reveal distance two into fishbone branch
  spacing. The Drone task spends one physical water Drop and confirms the exact
  owned Squidley after asynchronous opening. Their binding behavior belongs in
  [`teacher-controller.md`](teacher-controller.md).
- Extend the remaining supported loop one exact target-version type at a time:
  `MushroomCave` for the temporary movement-speed buff, `PortalCave` for passive
  resource delivery, `IronTreeCave` for renewable iron, `HelmetCave` for the mine
  camera extension, `CobaltCave` for its two one-time cobalt resources, and
  `WaterCave` for renewable water. Inventory and validate each type's required
  input, resource cost, carried-object behavior, planner or map effects,
  persistence, cooldown, success evidence, and wave interruption behavior
  before claiming support.
- Leave `BombCave` and `SeedCave` outside the teacher allowlist. A Cave Bomb
  requires selecting a safe, useful blast location before its release commits
  the explosion. A mineral-tree seed requires selecting a planting site with
  sufficient space plus persistent memory, revisit, and harvest behavior. Do
  not claim or interact with either excluded Cave, and do not add either
  location policy or recurring task solely to support its reward.
- Treat a reachable allowlisted Cave newly revealed by ordinary exploration as
  a potential bounded side task rather than a Cave-search objective. Do not
  inspect hidden map data or choose an unexplored frontier to look for a Cave.
  The teacher may freeze its current work and perform Cave-specific navigation,
  resource acquisition, activation, interruption, and recovery comparable to a
  Gadget or Power Core Chamber task. The implemented `DroneCave` may fetch an
  additional physical water Drop. The implemented `ScannerCave` may reserve and
  fetch two physical iron Drops under the existing resource-reservation rules
  while preserving partial receiver progress across interruption. Validate each
  remaining type's arbitration against waves, return deadlines, Gadget delivery,
  and Power Core work instead of assigning every Cave one priority.
- After the initial Cave-specific task completes, never retain a recurring Cave
  task, estimate or poll its cooldown, add a Cave waypoint, or change a later
  route solely to collect a renewable reward. If an already-selected ordinary
  task path later enters the validated interaction area of `MushroomCave`,
  `IronTreeCave`, or `WaterCave`, snapshot the exact rewards authoritatively
  available at that moment, handle each snapshot member at most once with
  bounded local positioning, and immediately resume the same task. Do not wait
  for another reward, infer availability from elapsed time, or preserve
  unfinished opportunistic Cave work across an interruption. If no later
  ordinary path encounters the Cave, leave its renewed rewards unused.
- For `IronTreeCave`, enter fruit activation without unrelated cargo. After each
  currently available fruit spawns an attached iron Drop, issue the normal
  configured drop action and confirm the new iron is loose before activating
  another fruit. Record the released physical iron Drops together as one
  ordinary cache site, then resume ordinary work after the bounded harvest. The
  existing resource planner and cache-cleanup flow own later collection and
  delivery, with no Iron Tree direct-return path. An interrupted initial harvest
  may resume only the fruit identities that were available in its original
  snapshot; newly regrown fruit never extends that task.
- Share only revealed-and-reachable discovery, navigation, interruption, focus,
  and bounded normal-input infrastructure. Implement and validate one exact Cave
  type at a time: some require focused use, `PortalCave` is passive and needs
  resource routing, and `DroneCave` changes resource ownership and movement
  asynchronously after consuming water. Do not add a generic "activate Cave"
  fallback or claim Cave types outside the exact allowlist. Define bounded
  retry, abandonment, and failure behavior from each allowlisted type's validated
  lifecycle instead of imposing one generic Cave-task failure policy.
- Complete support for one Cave type only after its resulting buff, reveal
  change, resource source, passive transport, or autonomous helper is
  incorporated into each behavior-relevant current planner path identified by
  its lifecycle validation and confirmed in a representative recording.

### Complete Relic Hunt

- After the supported rule-teacher loop is proven, extend the manually started,
  single-player Engineer and Laser Dome run through the actual Relic Hunt
  completion condition: discover and activate revealed relic switches, excavate
  and open the relic chamber, pick up and carry the final relic to the dome
  through normal configured inputs, resolve the required final act, and confirm
  success only when `game.over == won`.
- Preserve the current revealed-information and realizable-action boundaries.
  Keep Gadget artifacts and their choice flow distinct from the final Relic Hunt
  relic; current supported Gadget behavior is owned by
  [`teacher-controller.md`](teacher-controller.md). Extend the allowlist only
  after validating any newly required Gadget's complete runtime semantics.
- Before implementing relic control, decide the minimum structured observations
  or Vision classes needed for relic switches, the chamber, the carried relic,
  the dome drop point, and terminal win/loss state. Keep them out of the current
  ore/enemy dataset until annotation and evaluation contracts are decided.

### Expand the YOLO Dataset

- Expand the detector beyond the current MVP classes as later gameplay
  capabilities establish concrete perception requirements. Define each
  addition's annotation rules and evaluation criteria before changing the
  dataset contract; current detector and collection decisions remain in
  [`vision.md`](vision.md).

### Collect Configured Keyboard-Action Data

- Add time-aligned collection of configured in-process actions from proven
  teacher runs so later Lower-Agent experiments can relate realizable control to
  frames, Vision output, and teacher context. Decide schema, sampling cadence,
  synchronization, and intended learning use before implementation; replay
  events and YOLO image-label pairs are not an action dataset.

### Design the Lower Agent and Candidate Student Model

- Derive the Upper-to-Lower task contract and the Lower Agent's observation,
  action, timing, and evaluation contracts from proven teacher and Vision
  evidence.
- Account for the control-relevant distinctions demonstrated by Laser defense:
  exact selected-target ray acquisition, runtime damage eligibility, and
  intentional-target eligibility, including the `WORM_ROCK` exclusion. Decide
  their frame-derived representation during contract design rather than
  exposing privileged teacher runtime fields.
- Design and evaluate a student model as one candidate Lower-Agent
  implementation. This milestone does not preselect imitation learning or
  require the deployed Lower Agent to be learned; rule-based, learned, hybrid,
  and other implementations remain open until a separate decision selects one.
