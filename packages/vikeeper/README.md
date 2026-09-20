# ViKeeper

ViKeeper wraps ViDot for Dome Keeper Mod tests. The caller supplies an editable
Dome Keeper project; ViKeeper does not locate projects, inspect manifests, or
contain Mod-specific fixtures.

```ts
pool: vikeeper({
  projectPath,
  movie: process.env.VIDOT_MOVIE,
})
```

Tests run headlessly unless `movie` is provided. Movie mode uses a decorated
960×540 window at 30 FPS and requires Godot to produce a non-empty AVI. Each Mod
value-imports its fixtures from its tests. ViKeeper and each Mod fixture package
build as tstogd libraries. ViDot mounts the libraries under `tstogd_modules`
before Godot loads the tests.
The fixture adds a debug label only when `test_name` is nonempty.
Movie fixtures disable automatic pause on focus loss without activating the window.

Run `pnpm run build` to emit ViKeeper's fixture GDScript into the ignored
`dist/godot/` directory.

`FixtureScenario` declares the map, landmarks, and physical `drops`. The base
fixture spawns those Drops through the game's local drop system after the level
is ready, then exposes their real instances as `fixture_drops` for test
assertions and task setup. Each Mod fixture owns any Keeper positioning or
station-entry setup required by its scenario.
