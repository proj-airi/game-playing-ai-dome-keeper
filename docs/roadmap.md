# Roadmap

This document owns capability milestones, their broad ordering, and their open
design decisions. Maintenance, cleanup, and corrections to current behavior
belong in [`todo.md`](todo.md).

Roadmap entries commit only to their stated outcomes. They do not select an
implementation, interface, dataset schema, model, dependency, or training method
unless an explicit project decision says so.

## Capability Milestones

### Implement Godot-Native ViDot Test Execution — First Editable Proof Working

- Keep the editable-project proof passing through `mise run vidot:test`.
- Extend the test API only when a concrete test requires it.

### Connect the First Dome Keeper ViKeeper Test — Complete

- Keep the DataCollectorAI-owned fixture and Move test passing through the
  ViKeeper Dome Keeper wrapper, with a controlled map, signal-first completion,
  one Quark Action executed through `TaskExecutor`, and a final target-tile
  assertion.
- Keep headless and Movie Maker launch policy in ViKeeper, while each Mod owns
  its fixture, startup behavior, and assertions.
- Use this proof before expanding `TaskExecutor` to more actions or compound
  tasks.

### Replace the Existing Collector with the TypeScript AI Mod

- Develop `LemonNekoGH-DataCollectorAI` as the TypeScript-authored Godot
  replacement for `LemonNekoGH-YoloDataCollector`, using the planner, task, and
  `Quark Action` executor structure described in its README.
- Keep the legacy collector disabled in active repository workflows while its
  source remains available for migration evidence.
- Keep the TypeScript-to-GDScript build boundary and generated runtime files
  explicit while the new AI takes over the existing gameplay and data-collection
  responsibilities.

### Use Revealed Natural Cave Rewards

- `ScannerCave`, `DroneCave`, `IronTreeCave`, `WaterCave`, `MushroomCave`,
  `PortalCave`, and `HelmetCave` are implemented and validated in the supported
  rule-teacher loop. The Scanner task spends two physical iron Drops and
  incorporates reveal distance two into fishbone branch spacing. The Drone task
  spends one physical water Drop and confirms the exact owned Squidley after
  asynchronous opening. The three resource Cave tasks use one exact
  initial-snapshot lifecycle; Iron Tree and Water have representative runtime
  recordings. Mushroom observes a movement-speed increase, Portal observes a
  passive ore delivery and inventory increase, and Helmet observes a mine-camera
  zoom change. Their shared behavior belongs in [`interaction.md`](interaction.md); current
  controller details belong in [`teacher-controller.md`](teacher-controller.md).
- `CobaltCave` shares the implemented initial-snapshot path but remains
  provisional because fresh test maps did not expose its deep, rare Cave before
  the run ended. Validate it in a representative recording and add the
  already-specified opportunistic renewable revisit for Iron Tree and Water.
  Validate only the behavior needed to demonstrate its player-visible result.
- Leave `BombCave` and `SeedCave` outside the teacher allowlist. A Cave Bomb
  requires selecting a safe, useful blast location before its release commits
  the explosion. A mineral-tree seed requires selecting a planting site with
  sufficient space plus persistent memory, revisit, and harvest behavior. Do
  not claim or interact with either excluded Cave, and do not add either
  location policy or recurring task solely to support its reward.
- Treat a revealed allowlisted Cave found by the shared radius-ten scan as a short
  deviation from an ordinary path, not as a Cave-search objective. Share
  discovery, A*-versus-direct routing, decision recording, activation, outcome
  recording, and task resumption. Keep only required preparation and one
  player-visible success observation in each Cave-specific branch.
- After the initial Cave-specific task completes, never retain a recurring Cave
  task, estimate or poll its cooldown, add a Cave waypoint, or change a later
  route solely to collect a renewable reward. If an already-selected ordinary
  task path later enters the validated interaction area of `MushroomCave`,
  `IronTreeCave`, or `WaterCave`, snapshot the exact rewards authoritatively
  available at that moment, handle each snapshot member at most once with
  bounded local positioning, and immediately resume the same task. Do not wait
  for another reward or infer availability from elapsed time. A pushed defense
  or resource-acquisition task suspends the exact interaction snapshot; it does
  not create a recurring Cave task. If no later ordinary path encounters the
  Cave, leave its renewed rewards unused.
- For `IronTreeCave`, enter fruit activation without unrelated cargo. After each
  currently available fruit spawns an attached iron Drop, issue the normal
  configured drop action and confirm the new iron is loose before activating
  another fruit. Record the released physical iron Drops together as one
  ordinary cache site, then resume ordinary work after the bounded harvest.
  Post-wave cache quantity may later push cleanup, with no Iron Tree
  direct-return path. An interruption suspends the local snapshot; a later
  ordinary encounter after completion starts a fresh bounded snapshot.
- Do not inspect or persist receiver internals unless a runtime failure proves
  that the shared observation cannot diagnose or resume the interaction. Add
  only the narrow state required by that demonstrated failure.

### Validate Complete Relic Hunt

- The manually started, single-player Engineer and Laser Dome teacher now
  discovers and activates revealed relic switches, remembers and revisits one
  excavated Relic Chamber, carries the final relic to the dome through normal
  configured inputs, and lets the game-created final wave use ordinary defense.
  It still confirms overall success only when `game.over == won`.
- Prove the complete chain in a fresh runtime recording. Cover both discovery
  orders for the chamber and a switch, confirm exact artifact pickup and
  delivery, and observe the automatically scheduled final defense through its
  terminal outcome. Keep the revealed-information and realizable-action
  boundaries described in [`interaction.md`](interaction.md).
- Keep Gadget artifacts and their choice flow distinct from the final Relic Hunt
  relic. Extend either allowlist only after validating any newly required
  artifact's complete runtime semantics.
- Decide the minimum Vision classes needed for relic switches, the chamber, the
  carried relic, the dome drop point, and terminal win/loss state before adding
  them to the current ore/enemy dataset.

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
