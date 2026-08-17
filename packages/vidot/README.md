# ViDot

`@vidot/vitest` runs Vitest-shaped TypeScript tests inside an editable Godot
project. Godot owns collection and execution; Vitest owns file discovery and
reporting.

Run the repository proof with:

```bash
mise run vidot:test
```

The package runner is authored in TypeScript, generated during `build`, and
included by `prepack`. See [`docs/vidot.md`](../../docs/vidot.md) for the current
API and configuration.

The Godot test context can instantiate external GDScript fixtures and perform
frame-driven bounded waits; the complete contract is documented there.
