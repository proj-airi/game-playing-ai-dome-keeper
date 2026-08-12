# ViKeeper

ViKeeper is the Dome Keeper-specific test adapter above
[`@vidot/vitest`](../vidot/README.md). It finds the decompiled project that
actually links the tested Mod and places its generated test scene under
`res://__vikeeper/` only inside ViDot's isolated project mirror.

Configure the adapter from Vitest:

```ts
export default setupViKeeper({
  modPath,
  movie: process.env.VIDOT_MOVIE,
  projectsPath,
  root,
})
```

The Mod manifest supplies the Mod ID used to inspect links; Godot Mod Loader
remains the owner of game-version compatibility. The current fixture starts an
Engineer and Laser directly on a minimal map built with Dome Keeper's `MapData`
API, then sends one ordinary Enter key event through the landing stage's native
skip path as soon as the map is ready. DataCollectorAI keeps its own controller
assertions and does not contain the game test scene.
