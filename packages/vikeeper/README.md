# ViKeeper

ViKeeper wraps ViDot for Dome Keeper Mod tests. The caller supplies an editable
Dome Keeper project and the Mod-owned test root; ViKeeper does not locate
projects, inspect manifests, or contain Mod-specific fixtures.

```ts
pool: vikeeper({
  projectPath,
  testRoot,
  movie: process.env.VIDOT_MOVIE,
})
```

Tests run headlessly unless `movie` is provided. Movie mode uses a decorated
960×540 window at 30 FPS and requires Godot to produce a non-empty AVI. Each Mod
builds its fixtures outside its production runtime and loads them through
ViDot's `instantiate` context method.

`FixtureScenario` declares the Keeper start tile, map, and physical `drops`.
The base fixture spawns those Drops through the game's local drop system after
the level is ready, then exposes their real instances as `fixture_drops` for
test assertions and task setup.
