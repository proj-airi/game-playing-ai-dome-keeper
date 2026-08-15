# ViKeeper

ViKeeper is the planned Dome Keeper-specific wrapper above ViDot. Its previous
adapter depended on ViDot's loopback WebSocket RPC implementation and has been
removed with that transport.

The Godot scene and TypeScript-authored runtime assets under `runtime/` remain
as a fixture, but no current test harness launches them. They model an Engineer
and Laser on a minimal map built with Dome Keeper's `MapData` API and keep that
game-specific setup outside the production DataCollectorAI Mod.

The fixture is currently non-runnable. The pending Godot-native adapter will
reconnect it, with ViKeeper owning Dome Keeper and Mod startup while generic
ViDot remains unaware of Mod packaging and loading. See
[`docs/vidot.md`](../../docs/vidot.md) for that target contract.
