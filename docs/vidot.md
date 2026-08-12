# ViDot

This document owns the confirmed design for ViDot, a Godot integration for
Vitest. ViDot works with editable Godot projects; an example Godot project
proves the integration before ViKeeper composes it for the first Dome
Keeper-specific use case.

## Problem and Outcome

Vitest can test pure TypeScript behavior, but it cannot by itself prove that a
gameplay action works inside Godot. We need tests that can prepare a real game
state, call ordinary project methods, wait for engine events, inspect the final
state, and report through the existing Vitest workflow.

ViDot supplies only the missing Godot boundary. Vitest continues to own test
collection, filtering, watch mode, scheduling, assertions, and reporting. The
initial outcome is a small example project that proves mirror-only Autoload
installation, project isolation, Godot process creation and destruction, the loopback
WebSocket bridge, and the `get`, `set`, `call`, `waitForProperty`, and
`waitForSignal` commands.

## Runtime Topology

Test and fixture modules execute in Node.js. They are not compiled into the game
and do not form a test Mod.

```text
Vitest worker                       isolated Godot process
(one test file)                     (one process for that file)

test
        │
        ├── generic project: @vidot/vitest
        │
        └── Dome Keeper: @vikeeper/vitest ── @vidot/vitest ── WebSocket ── ViDot Autoload
                                                   │
                                                   ├── project nodes and methods
                                                   └── DataCollectorAI methods
```

`@vidot/vitest` extends the native Vitest `test` API with a file-scoped `vidot`
fixture. Tests import it directly and receive a ready client without starting or
stopping Godot themselves. ViDot begins as an unpublished monorepo package. It
does not provide global test APIs, a standalone CLI, or a separate configuration
file. A project imports `setupViDot` from the side-effect-free
`@vidot/vitest/setup` entry point once through Vitest `globalSetup`; setup only
provides validated launch configuration. The file-scoped fixture lazily creates
an isolated project mirror, installs the Autoload there, and owns one Godot
process for each test file that uses the fixture.

`setupViDot` may receive a fixed main scene owned by its caller. ViDot runs it
headlessly while continuing to own the project path, argument boundary, and
session. A caller may also provide project files mapped to `res://` targets;
ViDot validates those targets and copies the files only into the mirror.
ViKeeper uses these options for its Dome Keeper Move scene.

Vitest's file isolation is also ViDot's process isolation:

- one file-scoped `vidot` fixture owns one Godot process;
- each process owns an isolated temporary `user://` directory that teardown
  removes;
- tests inside that file run sequentially and share the process;
- project fixtures release their own state in per-test `finally` cleanup;
- ViDot automatically stops the file-scoped process after the file;
- files targeting different project directories may run in parallel, but files
  targeting the same directory must be serialized because the lightweight
  project mirror shares Godot's `.godot` import cache; ViKeeper enforces this
  for its single Dome Keeper project;
- same-file concurrent tests are unsupported because they would compete for one
  game state and input owner.

An ordinary assertion failure does not automatically invalidate the process. If
test cleanup succeeds and the bridge remains healthy, Vitest may run the next
test in the file. A Godot crash, bridge disconnect, or teardown failure
invalidates the environment and aborts the remaining tests in that file. Other
test files remain independent.

At file teardown, ViDot closes its WebSocket client. The initialized Autoload
then exits through `SceneTree.quit()` so Godot and Movie Maker can finish their
normal shutdown work. ViDot force-terminates the process only if that exit does
not complete within the bounded teardown wait.

## Temporary Autoload

ViDot's engine runtime is a TypeScript-authored Autoload compiled to GDScript
with `typescript-to-gdscript`. The generated `.gd` file is ignored in the source
repository and included in the built package through `package.files`; test
projects do not need tstogd.

When a file first uses the fixture, ViDot creates its isolated project mirror,
places the runtime file there, and adds the Autoload entry to the mirrored
`project.godot`. The editable source project is never modified. Process teardown
deletes the entire mirror and its isolated `user://` directory. ViDot is not a
Dome Keeper Mod and is never installed in the tested project.

A hard kill cannot run process cleanup. The deterministic mirror and `user://`
paths let the next ViDot run remove the interrupted session before starting.

This design supports editable Godot projects only. Exported or released games
are outside the initial scope.

## Bridge and Protocol

The Autoload hosts a WebSocket server backed by Godot's `TCPServer` and
`WebSocketPeer`. Each Godot process listens on a random loopback port:

```text
ws://127.0.0.1:<random-port>
```

The bridge uses JSON text frames and a small request, response, and error model.
WebSocket frame boundaries replace custom TCP framing. The protocol provides
these capabilities:

- initialize a session with an exact protocol version;
- resolve a Godot object by path;
- call a method with arguments;
- read or write a property;
- wait for a property to match an expected value;
- wait for a signal occurrence;
- return structured results and errors tied to request IDs.

`initialize` is the first client message. A version mismatch fails the
connection instead of being normalized. The server accepts one initialized
client and stops listening after that client is established.

The Autoload asks `TCPServer` for an ephemeral loopback port and prints a
session-bound readiness line. The Node side accepts that line only from Godot's
stdout, keeps stderr as bounded startup diagnostics, then performs the
WebSocket handshake and initialization. Both sides abandon an uninitialized
session after 30 seconds.

The initial bridge is fixed to loopback and has no token or authentication.
Configurable hosts, LAN access, and authentication are deferred together; ViDot
must not expose this privileged bridge beyond loopback without revisiting that
boundary.

ViDot calls methods already exposed by the project's nodes. A project may add a
normal facade node when that makes its own API clearer, but it does not register
methods with ViDot. DataCollectorAI therefore does not know about or depend on
ViDot. Arbitrary source-code evaluation is not part of the protocol.

## Waiting

ViDot exposes two distinct waits:

- `waitForSignal` resolves an object and signal by name, connects a one-shot
  callback, and completes when the signal occurs or the request times out. A
  test starts this wait before triggering the action so a synchronous or fast
  signal cannot be missed.
- `waitForProperty` reads one named property when the request arrives and once
  per process frame while that request remains pending. It completes when the
  property matches the requested JSON-compatible value or the request times
  out. It does not scan unrelated objects or properties.

Godot has no universal property-value change signal. Frame-bounded observation
is sufficient for sustained player-visible state: a value that changes and
changes back between rendered frames has no property state for a player or this
API to observe. Tests that care about the occurrence of a transient event use
`waitForSignal` instead.

Godot also calls `WebSocketPeer.poll()` from its process loop to pump network
events. This is separate from the bounded checks performed only for active
`waitForProperty` requests. ViDot does not evaluate arbitrary predicates or
source code in Godot.

## Initial Example Proof

The initial example lives in `examples/basic-vidot`. It is an editable Godot
project with one small node exposing a property, a synchronous method, and a
method that completes later and emits a signal. Its colocated Vitest coverage
proves:

- sandbox-only Autoload installation before launch and mirror removal after
  shutdown;
- automatic file-scoped Godot startup, bridge readiness, and process cleanup;
- isolated temporary `user://` selection and cleanup;
- `get`, `set`, and `call` round trips;
- one frame-bounded `waitForProperty` completion;
- one signal-first `waitForSignal` completion.

The example proves the generic bridge without requiring a Dome Keeper install,
decompiled project, Mod, map fixture, or gameplay API.

## Project Tests

ViDot does not glob a fixture registry, compile project tests into Godot, or
know which game is running.

ViKeeper owns the Dome Keeper-only half of this boundary: its Godot Move scene,
mirror-only placement under `res://__vikeeper/`, and later the shared readable
map-definition DSL. The current scene constructs a minimal map through Dome
Keeper's `MapData` methods before the landing stage can start procedural
generation. Once the landing stage reports that the map is ready, the scene
sends one ordinary Enter key event through the game's native skip path, then
lets the ordinary Level stage create the Engineer, input processor, map
collision, and configured input actions. Serialized TileMap cell arrays are not
test definitions.

The Vitest configuration provides ViKeeper with the Mod source and the root of
the local decompiled projects. ViKeeper derives the Mod ID from its manifest and
selects the unique project linking that exact source. The game's Mod Loader owns
manifest compatibility validation; test configuration does not repeat the
repository's game-version environment value or version rules.

DataCollectorAI keeps its Vitest assertions with the Mod. The test knows the
controller API but does not own the game scene. ViKeeper does not know
DataCollectorAI methods, and neither test layer is compiled into the production
Mod. The test releases an active action whether it passes or fails.

## Initial Dome Keeper Proof

The first end-to-end assertion lives with DataCollectorAI under `test/`, while
ViKeeper supplies its controlled game scene. Together they contain:

- one controlled Move test map;
- one Move Quark Action executed through DataCollectorAI's `TaskExecutor`;
- one completion signal subscribed before execution;
- one final assertion that the character reaches and remains inside the target
  tile after input release;
- automatic action reset and file-scoped process teardown.

The test map contains one Engineer entry, a bounded open corridor, and no
generated resources or landmarks. The bootstrap selects the editor's
ordinary single-player Engineer and Laser configuration in memory, installs
that map before landing can generate another one, and instantiates the normal
game scene. The legacy YOLO Mod remains disabled.

A Quark Action remains a pure function that returns an expected control state.
It has no lifecycle. `TaskExecutor` applies the control state and owns action
completion or failure.

The initial DataCollectorAI runtime facade is the ordinary project node
`/root/DataCollectorAI`. Its first slice exposes `move_ready`,
`start_move(target_x, target_y)`, `current_tile()`, `get_last_error()`, and
`reset()`, plus signal-first `task_completed` and `task_failed` lifecycle
signals. `Move` accepts one adjacent target tile only; pathfinding and compound
tasks remain outside this proof.

Later action tests should continue to assert player-visible outcomes:

- Pick up succeeds when the expected item is mounted on or carried by the
  character.
- Interact succeeds when a target such as a switch is open and no longer
  interactable.

Pure Quark Action resolution remains an ordinary Vitest unit test and does not
need Godot.

## tstogd Boundary and Verification

The ViDot Autoload is GDScript authored through tstogd. The initial runtime
avoids promises, `async` functions, and rest parameters. ViDot maintains the
missing `WebSocketPeer` declarations required by its supported Godot target
until upstream typings provide them.

The build and verification boundaries are distinct:

- `build` runs tstogd and emits the distributable `.gd` file;
- repository `check` makes the supported Godot executable load that generated
  script, because converter validation alone can miss target parser errors;
- ViDot's focused integration check starts Godot and completes one real
  WebSocket initialization and request round trip after bridge-runtime changes;
- consuming projects use the compiled `.gd` file and do not run tstogd.

The first implementation targets the repository's supported Dome Keeper Godot
4.3 build. If ViDot is later split out, its supported Godot-version matrix must
be decided and verified independently.

## Non-Goals

- replacing Vitest's collector, scheduler, assertions, reporters, or CLI;
- compiling test or fixture modules into GDScript;
- requiring a ViDot-aware API inside DataCollectorAI or another project;
- same-process concurrent gameplay tests;
- dynamic GDScript or arbitrary-code execution;
- automatic instrumentation of every Godot property write;
- permanent Autoload installation;
- exported-game testing, LAN control, or remote authentication in the initial
  version;
- an LLM or code-as-policy interface.

## Open Implementation Decisions

- the serialized Godot value subset beyond JSON-compatible values;
