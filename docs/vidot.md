# ViDot

This document owns ViDot's current implementation boundary and the frozen
replacement design. The replacement design is confirmed but not implemented.
The checked-in package still contains the earlier WebSocket prototype until the
replacement reaches an end-to-end proof.

## Problem and Intended Outcome

Vitest can discover, schedule, filter, watch, and report TypeScript tests, but a
Node.js test body cannot execute Godot APIs or GDScript semantics. ViDot must let
developers author tests in TypeScript while collecting and executing those
tests inside the real Godot runtime.

The intended result is a Vitest integration, not a second user-facing test
runner. Vitest owns its CLI, file discovery, filtering, watch mode, scheduling,
and reporters. Godot owns test-module evaluation, the collected test tree,
hooks, assertions, test bodies, and engine waits.

## Current Prototype

The checked-in `@vidot/vitest` package currently starts an editable-project
mirror, installs a temporary Autoload, and lets Node.js tests control Godot over
a loopback WebSocket with `get`, `set`, `call`, `waitForProperty`, and
`waitForSignal`. The example and current ViKeeper Move proof exercise this
prototype.

This prototype established process lifecycle and a real-game integration, but
it is not the target API. In particular, synchronous-looking remote-node
facades, worker-backed synchronous RPC, WebSocket abstraction libraries, and
more remote wait methods are superseded directions. The replacement should
delete the bridge instead of layering another facade over it.

## Frozen Replacement Topology

```text
Vitest
  ├── discovers, filters, schedules, watches, and reports test files
  └── ViDot custom pool
       └── one fresh Godot process per test file
            ├── loads the original project settings and Autoloads
            ├── starts the ViDot runner instead of the original main scene
            ├── preloads and evaluates the compiled test module
            ├── builds the test tree inside Godot
            └── runs hooks, assertions, and test bodies inside Godot
```

ViDot uses Vitest's custom-pool boundary even though that API is documented as
advanced and experimental. The repository must pin the supported Vitest minor
version, and a Vitest minor upgrade requires a focused ViDot integration check.

One fresh game process owns one test file. Tests in that file run sequentially
and share module, Autoload, and scene-tree state, matching ordinary same-file
test isolation. Different files may run in separate processes according to
Vitest scheduling. Same-file `test.concurrent` is not part of the first slice.
Shared game processes are not an initial abstraction; revisit them only if
measured startup time becomes a problem.

## Startup State and Project Ownership

ViDot does not automatically enter the tested project's original main scene.
The runner starts with the original project settings and Autoloads plus its own
empty test scene. Tests or a project-specific integration explicitly instantiate
the scenes they need.

ViKeeper owns Dome Keeper startup behavior. If a Dome Keeper test needs the real
game main scene, ViKeeper starts it. ViDot does not know which game is running
and does not acquire a game-specific scene API.

ViDot must not require a Mod, GDExtension, permanent Autoload, source change, or
ViDot-aware production API. It must also avoid modifying the installed game.
Exported-game runs therefore operate on an isolated copy or equivalent
disposable launch artifact.

## Release-Game Bootstrap Evidence

A stock Godot 4.6.2 release export was used to probe the no-source boundary:

- editor-only or extended `--script`, `--path`, and `--main-pack` launch paths
  are not a reliable entry point for stock release templates;
- replacing the original PCK with a bootstrap PCK loses project settings that
  must be available during engine initialization, including original Autoload
  startup, so PCK replacement is not the target design;
- placing `override.cfg` beside the exported project binary can replace
  `application/run/main_scene` while preserving the original PCK, project
  settings, and Autoloads;
- a small loose `res://` runner beside the original PCK started successfully,
  observed the original Autoload and its initialized state, printed its result,
  and exited;
- the same release probe passed after the original editable project source and
  external probe source were removed.

This establishes feasibility, not the final packaging implementation. The
repository's supported Godot 4.3 game build still needs the same end-to-end
validation. Projects that disable settings overrides, signed bundles that reject
the disposable-copy strategy, platform sandboxes, and complex PCK layouts remain
explicit compatibility boundaries.

## Compilation Boundary

Test authors use Vitest-shaped TypeScript:

```ts
import { expect, test } from '@vidot/test'

test('moves the player', async () => {
  // Executed inside Godot after conversion to GDScript.
  expect(currentTile).toEqual(targetTile)
})
```

`typescript-to-gdscript` (`tstogd`) remains the TypeScript-to-GDScript
converter. ViDot does not implement a second general TypeScript compiler. It
adds the smallest test-specific front end needed to wrap a source module in a
generated class, bind the virtual `@vidot/test` API, preserve source locations,
and lower test-only control flow before invoking tstogd.

The test module and its runtime value dependencies must be convertible by
tstogd and resolvable in Godot. Type-only imports may be erased. Node-only value
imports do not run in a second environment and must fail closed during module
resolution, type checking, or conversion.

Ordinary convertible top-level code is allowed. Godot instantiates the generated
test module and evaluates its top level once during collection, as Vitest does
when it imports a test module. A top-level failure is a collection failure for
the file.

## Collection and Execution

ViDot does not statically infer the test tree from the TypeScript AST. Static
inference would diverge for registration performed by loops, conditions,
computed names, and ordinary top-level code.

Instead, the generated module calls Godot-side `describe`, `test`, and hook
registrars during module evaluation. The runner maintains the active suite
stack and builds the actual tree in Godot. Test callbacks are registered during
collection and invoked later during execution.

Godot emits the collected tree and test results through the launched process's
output. The custom pool maps those results into Vitest's task and reporter
lifecycle. This is not a request/response transport: there is no WebSocket,
remote-node client, runtime command channel, connection state machine, or
bidirectional control protocol. The exact structured-output envelope remains an
implementation decision.

## Vitest Compatibility Contract

ViDot should match Vitest semantics whenever the Godot runtime can support them.
Any deliberate omission must be documented as deferred rather than silently
assigned different behavior.

The first compatibility slice contains:

- `test` and `describe`;
- `beforeAll`, `beforeEach`, `afterEach`, and `afterAll`;
- `.skip` and `.only`;
- `expect`, `expect.soft`, and `.not`;
- the value, collection, and numeric matchers required by real project tests;
- asynchronous test bodies and ordinary Godot signal or frame waits.

Normal `expect` is fail-fast within the current test body. A failed assertion
stops the remaining body, marks the test failed, and still allows `afterEach`
cleanup and later tests to run. `expect.soft` records the failure and continues
the current body. A `beforeEach` failure skips the body but still enters cleanup;
an `afterEach` failure is attached to the same test result.

GDScript has no catchable exception equivalent suitable for implementing this
contract, and release builds cannot depend on `assert`. The test-specific
front end must therefore lower normal assertion statements into runner-aware
failure and early-return control flow while soft assertions only record the
failure. The exact lowering and diagnostics are still open implementation work.

Snapshots, mocks, spies, fake timers, custom matchers, data-driven test helpers,
retries, and concurrent tests are deferred until a real test requires them.
They are not permanent non-goals.

## Result and Failure Boundaries

An assertion failure invalidates only its test. Cleanup still runs, and later
tests in the same file may continue. A collection failure, Godot crash, runner
failure, or process teardown failure invalidates the remaining tests in that
file. Other files remain isolated in their own processes.

Godot runtime errors and assertion failures must be mapped back to TypeScript
source locations. The generated wrapper and tstogd output therefore need a
preserved source-location path; the concrete source-map representation and
error-attribution algorithm are not frozen yet.

## Initial Proof

The replacement's first proof should use a small editable Godot example before
ViKeeper consumes it. It must demonstrate:

- TypeScript test-module conversion through tstogd;
- module evaluation and test-tree collection inside Godot;
- one process per test file and deterministic teardown;
- normal and soft assertion semantics, including `afterEach` after failure;
- one asynchronous Godot signal or frame wait without a remote wait API;
- structured tree and result delivery to native Vitest reporting;
- no permanent project mutation, Autoload, Mod, GDExtension, or WebSocket.

The next Dome Keeper proof should migrate the existing Move test without adding
ViDot knowledge to DataCollectorAI. ViKeeper owns game startup and fixture-scene
construction; DataCollectorAI keeps the assertions next to the Mod.

## Open Decisions for the Next Design Session

- the generated wrapper shape and tstogd extension point;
- the exact first matcher list and equality rules;
- assertion early-return lowering and TypeScript source attribution;
- the custom-pool task/result adapter for the pinned Vitest version;
- the structured process-output envelope and malformed-output behavior;
- placement or packing of the runner, compiled modules, and fixture resources;
- editable-project and exported-project configuration APIs;
- isolated launch-copy behavior across supported desktop platforms;
- cancellation, per-test timeout, and hung-process behavior;
- the compatibility matrix for Godot 4.3, stock modern Godot, and released
  games with disabled overrides or integrity restrictions.

## Superseded Directions

- expanding the WebSocket request protocol;
- hiding asynchronous RPC behind a synchronous remote-node proxy;
- worker-thread and shared-memory transports for remote property access;
- `waitForProperty` and `waitForSignal` as remote client APIs;
- Eventa or another messaging abstraction for the removed bridge;
- static AST generation of the test tree;
- automatically starting the tested project's original main scene;
- sharing one game process between test files before performance evidence
  requires it.
