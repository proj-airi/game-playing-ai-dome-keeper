# Roadmap

This document owns capability milestones, their broad ordering, and their open
design decisions. Maintenance, cleanup, and corrections to current behavior
belong in [`todo.md`](todo.md).

Roadmap entries commit only to their stated outcomes. They do not select an
implementation, interface, dataset schema, model, dependency, or training method
unless an explicit project decision says so.

## Planned Milestones

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
