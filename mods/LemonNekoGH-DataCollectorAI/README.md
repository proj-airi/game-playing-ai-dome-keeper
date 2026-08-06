# LemonNekoGH-DataCollectorAI

The replacement TypeScript-authored Godot AI mod for AIRI. TypeScript is the
authoring layer; `tstogd convert` emits the GDScript that Godot loads from
`scripts/`, alongside the tracked mod manifest. It replaces
`LemonNekoGH-YoloDataCollector`.

## Structure

- `src/planner/index.ts` - Planner for generating executable plans.
- `src/executor/task.ts` - Breaks plans into executable tasks.
- `src/executor/action.ts` - Executes the `Quark Action`s in a plan.

Build the generated runtime files with:

```bash
bun run build
```

### Terms

- `Quark Action` - The basic action unit that can be executed by the AI,
  such as `move`, `pickup`, `interact`, etc. I don't want to use
  `Atomic Action` because the Atom is not the smallest unit in physics.
