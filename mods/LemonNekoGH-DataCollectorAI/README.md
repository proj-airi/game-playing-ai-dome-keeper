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

The current action hierarchy keeps frame control separate from task state
without fixing the future Lower Agent interface:

- `Move` is a stateless Quark Action that returns the directional input for the
  current frame. The current `MoveTo` task may own an arbitrary map coordinate
  and resolve `Move` each frame until the target is reached. Coordinates are
  useful for the privileged runtime and controlled tests but are not a promised
  student-model input.
- `MovePath` is not a confirmed task. Introduce a path-consuming compound task
  only after a concrete caller and behavior require one; a future student model
  may instead act from frame history and uncertain relative target direction.
- `Activate`, `Pickup`, and `Drop` are separate Quark Actions. They resolve the
  configured `ui_select`, `keeper1_pickup`, and `keeper1_drop` actions
  respectively. Their default physical bindings may overlap, but Dome Keeper
  allows them to be rebound independently.
- `ActivateTarget`, `PickupTarget`, and `DropCargo` own target selection,
  one-shot timing, and completion observation. Their Quark Actions do not retain
  state or decide whether the gameplay operation succeeded.

The first vertical slice exposes `/root/DataCollectorAI` as an ordinary Godot
runtime node. `start_move_to(target: Vector2i)` accepts an arbitrary target
coordinate, while `current_tile()` reports the current `Vector2i` and `reset()`
releases active input. `MoveToTask` owns the target and completion predicate;
it resolves `Move` every physics frame, while `TaskExecutor` changes the
configured held action only when the required direction changes. Tests
subscribe to `task_completed` or `task_failed` before starting the task. The
initial `TaskExecutor` deliberately does not provide path generation, pickup,
interaction, or compound-task behavior.

The project borrows HTN's useful hierarchical vocabulary without adopting formal
planner completeness, search semantics, partial ordering, method-effect
semantics, or alternative-method backtracking. The exact source-file layout and
the TypeScript data types are not frozen yet.

DataCollectorAI does not depend on or register APIs with ViDot. Its Move test,
controlled Dome Keeper fixture, and assertions live under `test/`; generated
test GDScript is ignored and never installed under the production output root.
ViKeeper supplies the shared Dome Keeper process launch policy.

Build the generated runtime files with:

```bash
pnpm run build
```

Run the automated MoveTo proof with `mise run domekeeper:vidot:test`. Generate
`recordings/move.avi` for visual inspection with
`mise run domekeeper:vidot:record`.

### Terms

- `Quark Action` - The stateless, frame-scoped control result resolved by an
  active primitive task, such as `Move`, `Activate`, `Pickup`, or `Drop`. I
  don't want to use `Atomic Action` because the Atom is not the smallest unit
  in physics.
