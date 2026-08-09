# ViDot

This document owns the confirmed design for ViDot, a Godot integration for
Vitest. ViDot works with editable Godot projects; an example Godot project
proves the integration before DataCollectorAI and Dome Keeper provide its first
project-specific use case.

## Problem and Outcome

Vitest can test pure TypeScript behavior, but it cannot by itself prove that a
gameplay action works inside Godot. We need tests that can prepare a real game
state, call ordinary project methods, wait for engine events, inspect the final
state, and report through the existing Vitest workflow.

ViDot supplies only the missing Godot boundary. Vitest continues to own test
collection, filtering, watch mode, scheduling, assertions, and reporting. The
initial outcome is a small example project that proves Autoload injection and
removal, Godot process creation and destruction, the loopback WebSocket bridge,
and the `get`, `set`, `call`, `waitForProperty`, and `waitForSignal` commands.

## Runtime Topology

Test and fixture modules execute in Node.js. They are not compiled into the game
and do not form a test Mod.

```text
Vitest worker                       editable Godot process
(one test file)                     (one process for that file)

test + explicitly imported fixture
        │
        └── @vidot/vitest ── WebSocket ── ViDot Autoload
                                                   │
                                                   ├── project nodes and methods
                                                   └── DataCollectorAI methods
```

`@vidot/vitest` extends the native Vitest `test` API with a file-scoped `vidot`
fixture. Tests import it directly and receive a ready client without starting or
stopping Godot themselves. ViDot begins as an unpublished monorepo package. It
does not provide global test APIs, a standalone CLI, or a separate configuration
file. A project imports `setupViDot` from the side-effect-free
`@vidot/vitest/setup` entry point once through Vitest `globalSetup`; ViDot then
injects the Autoload for the test session and lazily owns one Godot process for
each test file that uses the fixture.

Vitest's file isolation is also ViDot's process isolation:

- one file-scoped `vidot` fixture owns one Godot process;
- tests inside that file run sequentially and share the process;
- fixture teardown is automatic between tests;
- different files may run in parallel in separate Godot processes;
- same-file concurrent tests are unsupported because they would compete for one
  game state and input owner.

An ordinary assertion failure does not automatically invalidate the process. If
fixture cleanup succeeds and the bridge remains healthy, Vitest may run the next
test in the file. A Godot crash, bridge disconnect, or teardown failure
invalidates the environment and aborts the remaining tests in that file. Other
test files remain independent.

## Temporary Autoload

ViDot's engine runtime is a TypeScript-authored Autoload compiled to GDScript
with `typescript-to-gdscript`. The generated `.gd` file is ignored in the source
repository and included in the built package through `package.files`; test
projects do not need tstogd.

At the start of a Vitest session, ViDot places the runtime file in the editable
Godot project and adds its Autoload entry to `project.godot`. At session end it
removes its exact Autoload entry from the current project file before removing
the runtime file. It does not restore a whole-file snapshot, so unrelated
project-setting edits made during a watch session are preserved. ViDot is not a
Dome Keeper Mod and is not permanently installed in the project.

A hard kill cannot run process cleanup. The injected runtime must therefore be
inert when ViDot's launch arguments and session are absent, and the next ViDot
session must reconcile a previous interrupted injection before starting. This
makes an interrupted test run recoverable without making residual injection a
normal installation mechanism.

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

- Autoload injection before launch and removal after shutdown;
- automatic file-scoped Godot startup, bridge readiness, and process cleanup;
- `get`, `set`, and `call` round trips;
- one frame-bounded `waitForProperty` completion;
- one signal-first `waitForSignal` completion.

The example proves the generic bridge without requiring a Dome Keeper install,
decompiled project, Mod, map fixture, or gameplay API.

## Fixtures and Project Tests

A fixture is Node.js code that uses the bridge to prepare and later unload a
known game state. A Dome Keeper fixture can, for example, ask existing project
methods to load one map definition and expose the target needed by a test.

Fixture modules are explicitly imported by their tests. ViDot does not glob a
fixture registry or compile fixtures into Godot. Project-specific tests and
fixtures live with the project or Mod being tested; DataCollectorAI's fixtures
therefore remain with DataCollectorAI rather than in a generic ViDot package or
a separate `data-collector-ai-tests` package.

The exact fixture function signatures and map-loading hooks are intentionally
deferred. Automatic teardown is not deferred: a fixture must release its state
after each test, whether the test passes or fails.

## Later Dome Keeper Proof

The smallest end-to-end proof contains:

- one explicitly imported fixture with one map definition;
- one Move Quark Action executed through DataCollectorAI's `TaskExecutor`;
- one completion signal subscribed before execution;
- one final assertion that the character coordinate is inside the target tile;
- automatic fixture teardown while retaining the same Godot process for the
  next test in the file.

A Quark Action remains a pure function that returns an expected control state.
It has no lifecycle. `TaskExecutor` applies the control state and owns action
completion or failure.

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
- the fixture function signature and first DataCollectorAI map-loading hook;
- the DataCollectorAI methods and lifecycle signals needed by the Move proof.
