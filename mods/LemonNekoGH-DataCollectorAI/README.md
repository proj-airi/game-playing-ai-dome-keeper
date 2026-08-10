# LemonNekoGH-DataCollectorAI

The replacement TypeScript-authored Godot AI mod for AIRI. TypeScript is the
authoring layer; `tstogd convert` emits the GDScript that Godot loads from
`scripts/`, alongside the tracked mod manifest. It replaces
`LemonNekoGH-YoloDataCollector`.

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

Each executor owns its current method and method step. Only the active
primitive-task executor owns gameplay input.

The first vertical slice exposes `/root/DataCollectorAI` as an ordinary Godot
runtime node. It supports one adjacent-tile `start_move(x, y)` task, reports the
current tile through `current_tile()`, and releases active input through
`reset()`. Tests subscribe to `task_completed` or `task_failed` before starting
the task. The initial `TaskExecutor` deliberately does not provide pathfinding,
pickup, interaction, or compound-task behavior.

The project borrows HTN's useful hierarchical vocabulary without adopting formal
planner completeness, search semantics, partial ordering, or method-effect
semantics. The exact source-file layout and the TypeScript data types are not
frozen yet.

ViDot will test this Mod through ordinary Godot methods and signals exposed by
its runtime. DataCollectorAI does not depend on or register APIs with ViDot.
DataCollectorAI-specific Vitest files and their explicitly imported Node.js
fixtures remain with this Mod; the fixtures use ViDot's temporary Autoload and
loopback WebSocket bridge to prepare and inspect the game. Godot-only fixture
source lives under `test/godot/` and is compiled into a temporary ignored Mod
directory only while the integration test runs.

Run `mise run domekeeper:vidot:test` to start the dedicated Move test map and
verify one real adjacent-tile Move through the runtime facade. The map contains
one Engineer entry and a bounded open corridor. The test constructs it through
Dome Keeper's `MapData` methods instead of committing serialized TileMap data,
and it does not run procedural generation. The legacy YOLO Mod remains disabled.

Build the generated runtime files with:

```bash
bun run build
```

### Terms

- `Quark Action` - The basic action unit that can be executed by the AI,
  such as `move`, `pickup`, `interact`, etc. I don't want to use
  `Atomic Action` because the Atom is not the smallest unit in physics.
