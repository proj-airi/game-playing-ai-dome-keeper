# Dome Keeper status dashboard

A small Vue 3, TypeScript, and Vite dashboard using `@proj-airi/ui` and UnoCSS.

```sh
bun run --cwd packages/status-dashboard dev
```

## Live

Live mode polls `GET /api/status` once per second. The Vite development plugin reads `airi-dome-keeper-status.json` from the operating system's temporary directory, so no second frontend process is needed.

An unavailable producer snapshot is `{ "available": false, "run_time_seconds": 0 }`; status cards render only for an available run.

## Replay

Start a recorded run with `mise run godot:record`; pass `-- --fps 60` to override the default 30 FPS. The mise task writes each session under `recordings/` in the repository root.

Replay mode consumes full-snapshot events and synchronizes them to the manually selected MP4 with `movie_frame / fixed_fps`. It supports play/pause, previous and next event, movie scrubbing, playback speed, and transition reasons.

Replay is manual-only: select a replay JSON, then its MP4. The Vite bridge serves only the Live status file and never discovers or serves recorded sessions.

```sh
bun run --cwd packages/status-dashboard typecheck
bun run --cwd packages/status-dashboard build
```

References: [@proj-airi/ui](https://www.npmjs.com/package/@proj-airi/ui), [Vue TypeScript guide](https://vuejs.org/guide/typescript/overview.html), [Vite plugin API](https://vite.dev/guide/api-plugin.html#configureserver), [UnoCSS Vite integration](https://unocss.dev/integrations/vite).
