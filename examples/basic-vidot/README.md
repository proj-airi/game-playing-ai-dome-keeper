# Basic ViDot Example

This is ViDot's runnable editable-project proof. Both its scene behavior and
test are authored in TypeScript. tstogd compiles `src/main.ts` to the ignored
`scripts/main.gd`; ViDot compiles `basic.test.ts`, loads `main.tscn`, exercises
synchronous and signal-driven behavior inside Godot, and reports its
assertions through Vitest.

Run it from the repository root:

```bash
mise run vidot:test
```

The task builds the packaged runner and compiles the scene behavior before
starting Vitest. The test runner does not modify `project.godot` or install a
ViDot Autoload.
