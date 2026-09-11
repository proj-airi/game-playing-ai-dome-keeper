# LemonNekoGH-DataCollectorAI

The replacement TypeScript-authored Godot AI mod for AIRI. TypeScript is the
authoring layer; `tstogd convert` emits the GDScript that Godot loads from
`mods-unpacked/LemonNekoGH-DataCollectorAI/`, alongside the tracked mod manifest.
It replaces `LemonNekoGH-YoloDataCollector`.

## Runtime design

The runtime is centered on one recursive `TaskExecutor` abstraction. Its design
is inspired by Hierarchical Task Networks (HTNs), but it is not a complete HTN
planner or a formally compliant HTN implementation:

- a compound task resolves a task method;
- the method creates child `TaskExecutor` instances for its subtasks;
- a primitive task resolves a declarative `Quark Action` from the current world
  state;
- the active primitive executor applies the resulting control state through
  normal configured game inputs.

Each executor owns its current method and method step. A parent advances only
after its child reports a result, so a method step may itself be a compound task.
Only the active primitive-task executor owns gameplay input.

Unrecorded task startup and compound child transitions execute immediately. During active
execution, each executor checks completion and failure and updates input every
six physics frames. At the game's default 60 Hz physics rate, this cadence is
10 Hz. Held input persists between checks. Cancellation and scene removal
submit release events immediately and reset the frame counter. Godot delivers
those events through its normal input processing. This runtime supports
[ADR-0005](../../docs/decisions/0005-train-lower-v0-with-automated-multitask-demonstrations.md).

The current action hierarchy keeps frame control separate from task state
without fixing the future Lower Agent interface:

- `Move` is a stateless Quark Action that returns the directional input for the
  current frame. The current `MoveTo` task may own an arbitrary map coordinate
  and resolve `Move` at each task check until the target is reached. Coordinates are
  useful for the privileged runtime and controlled tests but are not a promised
  student-model input.
- `MovePath` is not a confirmed task. Introduce a path-consuming compound task
  only after a concrete caller and behavior require one; a future student model
  may instead act from frame history and uncertain relative target direction.
- `Activate` and `Pickup` are separate stateless Quark Actions. They resolve the
  configured `ui_select` and `keeper1_pickup` actions only while the exact
  requested object has focus. Their default physical bindings may overlap, but
  Dome Keeper allows them to be rebound independently.
- `PickupTarget` moves toward one exact Carryable and completes only after that
  object attaches to the Keeper, including as an additional shared carrier.
- `ActivateGadgetChamber` is a compound task. It focuses the exact usable,
  issues one `Activate` press and release, and then waits without input until
  the Chamber is empty and a Gadget is carried by the Keeper.
- `DropUntilTypeTask` repeats short `Drop` press/release cycles until the game
  releases a carried object of the requested type. `DropByType` then uses the
  existing Pickup task to recover every nonmatching object released first.

`DataCollectorAI` owns Lower v0 scenario construction, task selection, and
Session recording. Its automated collection uses the existing ViKeeper fixtures.
A `TaskExecutor` is a scene-tree node that owns one Keeper and a primitive
or compound task. A compound executor resolves one ordered method once, owns
one child executor at a time, and propagates child completion or failure. Only
the active primitive leaf applies configured input. Fixtures and tests can
therefore instantiate an executor directly without constructing the AI. The
executor does not provide path generation, alternative methods, replanning, or
backtracking.

The project borrows HTN's useful hierarchical vocabulary without adopting formal
planner completeness, search semantics, partial ordering, method-effect
semantics, or alternative-method backtracking. The exact source-file layout and
the TypeScript data types are not frozen yet.

DataCollectorAI does not depend on or register APIs with ViDot. The Mod's Move,
Pickup, type-directed Drop, Gadget Chamber activation, and Laser attack
fixtures, tests, and assertions live under `test/`; tests value-import their
fixtures, and ViDot compiles that module graph outside the production output
root. ViKeeper supplies the shared Dome Keeper process launch policy.

Build the generated runtime files with:

```bash
pnpm run build
```

Run only the Gadget Chamber activation proof with:

```bash
mise run domekeeper:vidot:test -- test/activate_gadget_chamber.test.ts
```

Run all automated MoveTo, Pickup, Drop, Gadget Chamber activation, and Laser
attack proofs with
`mise run domekeeper:vidot:test`. Generate `recordings/move.avi` for visual
inspection with `mise run domekeeper:vidot:record`.

## Lower v0 collection

`mise run lower-v0:collect` runs eight seeded scenarios for each ADR-0005
instruction. Targets and independent starts are sampled in x=-2..2, y=0..2,
at least two tiles apart. The map uses the existing Move fixture as its base.
Each mineral spawn has a dirt tile directly below it. An extra dirt row supports
the lowest spawn positions without replacing the outer boundary.
Pickup collection waits for the mineral to settle and checks that it stays in its spawn cell.
Laser scenarios use the
game's seeded monster wave.
Gadget Chamber anchors use x=-2..1, y=0..1 so their 2-by-2 footprint fits inside the map.

Drop scenarios start with 3–8 carried minerals near the Keeper.
The seed determines the mineral types, count, and carrying order.
Each load contains the requested type and at least one other type, with repeated types permitted.
The task releases one mineral of the requested type and retains every other original object.
Session metadata includes the ordered mineral definitions. Pickup scenarios still start with a distant loose mineral.

The recorder stores completed video frame indices, held actions, and input and task transitions.
It does not capture screenshots or force rendering. After recording, the offline extractor
creates RGB PNG files and validates frame/action alignment before it promotes successful Sessions.
Successful Sessions enter `data/lower-v0/sessions`; failed attempts remain under `.incomplete`.
Collection uses ViKeeper's Movie
Maker flow and writes `recordings/lower-v0.avi`. It leaves `test_name` empty
to omit the debug overlay, and requires one Dome.
The collection window cannot take focus. Movie fixtures disable automatic pause
on focus loss. TaskExecutor flushes configured input events before it restores
the game's focus guard.
Each decision uses the last completed render before its input change.
Missing or stale renders fail collection instead of entering the dataset.

Map entry count determines how many loadout Domes are instantiated. The sampling
region stays below the Dome cellar collision shapes. See the
[training subproject](../../models/lower-v0/README.md) for model commands.

### Terms

- `Quark Action` - The stateless, frame-scoped control result resolved by an
  active primitive task, such as `Move`, `Activate`, `Pickup`, or `Drop`. I
  don't want to use `Atomic Action` because the Atom is not the smallest unit
  in physics.
