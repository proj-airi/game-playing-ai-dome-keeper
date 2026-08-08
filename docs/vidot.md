# ViDot

This document owns the confirmed design for ViDot, a Vitest-integrated Godot
automation and testing framework. ViDot is generic to editable Godot projects;
DataCollectorAI and Dome Keeper provide its first end-to-end use case.

## Problem and Outcome

Vitest can test pure TypeScript behavior, but it cannot by itself prove that a
gameplay action works inside Godot. We need tests that can prepare a real game
state, call ordinary project methods, wait for engine events, inspect the final
state, and report through the existing Vitest workflow.

ViDot supplies only the missing Godot boundary. Vitest continues to own test
collection, filtering, watch mode, scheduling, assertions, and reporting. The
initial outcome is one repeatable Dome Keeper test that executes a Move Quark
Action through `TaskExecutor` and confirms that the character reaches the target
tile.

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

`@vidot/vitest` re-exports the native Vitest API and adds access to the Godot
test context. Tests import it explicitly. ViDot begins as an unpublished
monorepo package. It does not initially provide global test APIs, a standalone
CLI, or a separate configuration file. A project registers ViDot through
`vitest.config.ts`; the exact configuration helper and test-context signatures
remain open until implementation shows what they need.

Vitest's file isolation is also ViDot's process isolation:

- one test file owns one Godot process;
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
with `typescript-to-gdscript`. The compiled `.gd` file is part of ViDot; test
projects do not need tstogd.

At the start of a Vitest session, ViDot places the runtime file in the editable
Godot project and adds its Autoload entry to `project.godot`. At session end it
removes the Autoload entry before removing the runtime file. ViDot is not a
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

The bridge uses JSON text frames and a small JSON-RPC-like request, response,
error, and event model. WebSocket frame boundaries replace custom TCP framing.
Exact command names and payload types remain implementation decisions, but the
protocol must provide these capabilities:

- initialize a session with an exact protocol version;
- resolve a Godot object by path;
- call a method with arguments;
- read or write a property;
- subscribe to a signal and deliver its occurrence as an event;
- return structured results and errors tied to request IDs.

`session.initialize` is the first client message. A version mismatch fails the
connection instead of being normalized. The server accepts one initialized
client and stops listening after that client is established.

The initial bridge is fixed to loopback and has no token or authentication.
Configurable hosts, LAN access, and authentication are deferred together; ViDot
must not expose this privileged bridge beyond loopback without revisiting that
boundary.

ViDot calls methods already exposed by the project's nodes. A project may add a
normal facade node when that makes its own API clearer, but it does not register
methods with ViDot. DataCollectorAI therefore does not know about or depend on
ViDot. Arbitrary source-code evaluation is not part of the protocol.

## Event-Driven Waiting

Gameplay completion waits are signal-first. A test registers the signal
subscription before triggering the action so a fast completion cannot be
missed. The Godot side connects a one-shot callback, forwards the occurrence as
a bridge event, and removes the subscription. The test then reads final game
state and asserts the observable postcondition.

Godot must still call `WebSocketPeer.poll()` from its process loop. That pumps
network events; it is not gameplay-condition polling. ViDot does not initially
provide an arbitrary state-polling `waitFor`. Its public waiting API and exact
signal callback adaptation remain open until the first real action identifies
the required shape.

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

## First Dome Keeper Proof

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

The ViDot Autoload is event-driven GDScript authored through tstogd. The initial
runtime avoids promises, `async` functions, and rest parameters. ViDot maintains
the missing `WebSocketPeer` declarations required by its supported Godot target
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
- permanent Autoload installation;
- exported-game testing, LAN control, or remote authentication in the initial
  version;
- an LLM or code-as-policy interface.

## Open Implementation Decisions

- the exact `vitest.config.ts` integration and `@vidot/vitest` context API;
- the exact protocol method names, payloads, and serialized Godot value subset;
- how the selected random port and bridge readiness are communicated to the
  Vitest worker;
- the fixture function signature and first DataCollectorAI map-loading hook;
- the DataCollectorAI methods and lifecycle signals needed by the Move proof.
