# ViDot

This document owns ViDot's frozen Godot-native target contract. That target is
not implemented yet; the checked-in package is its temporary predecessor.

## Problem and Intended Outcome

Vitest can provide the TypeScript test authoring experience and outer test-run
orchestration, but a Node.js test body cannot execute Godot APIs or GDScript
semantics. ViDot must let developers author Vitest-shaped tests in TypeScript
while collecting and executing those tests inside the real Godot runtime.

The intended result is a Vitest integration, not a second user-facing test
runner. Vitest owns its CLI, file discovery, watch mode, file scheduling, filter
inputs, reporters, and final result presentation. Godot owns test-module
evaluation, the dynamically collected test tree, selection within that tree,
hooks, assertions, test bodies, and engine waits.

## Runtime Topology

```text
Vitest
  |-- discovers and schedules files, supplies filters, watches, and reports
  `-- ViDot custom pool
       `-- thin Node.js worker adapter
            |-- compiles one TypeScript test module
            |-- launches one fresh Godot process for that file
            |-- passes launch-time collection and selection inputs
            `-- maps one-way structured Godot events into Vitest tasks
                 `-- Godot runner
                      |-- loads and evaluates the compiled test module
                      |-- dynamically collects the test tree
                      |-- applies the supported Vitest selection semantics
                      `-- runs hooks, assertions, and test bodies
```

The Node.js adapter uses Vitest's documented `PoolRunnerInitializer` and the
`init` scaffold from `vitest/worker`. It manages compilation, process lifecycle,
and task/result translation. Godot collects and executes the test bodies.

ViDot uses the custom-pool boundary even though Vitest documents it as advanced
and experimental. The initial implementation targets Vitest 4.1.10. Its supported
minor must be pinned when the adapter is implemented, and a Vitest minor upgrade
requires a focused compatibility run against ViDot's collection, filtering,
hook, and reporting fixtures.

One fresh game process owns one test file. Tests in that file run sequentially
and share module, Autoload, and scene-tree state, matching ordinary same-file
test isolation. Different files may run in separate processes according to
Vitest scheduling. Same-file `test.concurrent` is not part of the first slice.
Shared game processes are not an initial abstraction; revisit them only if
measured startup time becomes a problem.

## Supported Baselines

The first implementation and acceptance proof target editable Godot projects
using Godot 4.3.1, including ViKeeper's recovered Dome Keeper project. This is a
documented, tested baseline rather than a runtime version gate. ViDot does not
preflight, reject, or branch on the Godot version. Later Godot versions may work,
but the project does not guarantee them. Ordinary conversion, startup, and
runtime failures expose real incompatibility.

Released-game execution is outside the initial scope.

ViDot does not define a second general TypeScript or module-compatibility
matrix. Apart from the test-module transformations described below, the
language and import surface is exactly what the selected `tstogd` version can
convert. ViDot does not add speculative prechecks for unsupported syntax or
imports.

## Startup State and Project Ownership

ViDot does not automatically enter the tested project's original main scene.
The runner starts with the original project settings and Autoloads plus its own
empty test scene. Tests or a project-specific integration explicitly instantiate
the scenes they need.

ViKeeper owns Dome Keeper startup behavior. If a Dome Keeper test needs the real
game main scene, ViKeeper starts it. ViDot does not know which game is running
and does not acquire a game-specific scene API.

ViDot must not require a Mod, GDExtension, permanent ViDot Autoload, production
source change, or ViDot-aware production API.

## Compilation Boundary

Test authors use Vitest-shaped TypeScript:

```ts
import { expect, test } from '@vidot/test'

test('moves the player', async ({ tree }) => {
  await tree.process_frame
  expect(currentTile).toEqual(targetTile)
})
```

`@vidot/vitest` is the Node.js host package for Vitest configuration and the
custom pool. `@vidot/test` is the virtual authoring API bound while compiling a
Godot-executed test module.

`typescript-to-gdscript` (`tstogd`) remains the TypeScript-to-GDScript
converter. ViDot does not implement a second general TypeScript compiler and
does not patch or fork tstogd. Its test-specific front end generates the
class-shaped TypeScript input that tstogd requires, then invokes tstogd through
its public `convertTsToGd` API.

The front end performs only the transformations required by the test-module
contract:

- bind the virtual `@vidot/test` API to Godot-side test registration and
  assertion operations;
- wrap module-level statements in a generated script class and hoist test and
  hook callbacks into a form tstogd can emit;
- preserve module initialization order and make mutable module bindings shared
  instance state for hooks and tests in the file;
- lower directly written assertion statements where GDScript needs explicit
  failure propagation;
- retain an original-TypeScript-to-wrapper mapping that can be composed with
  tstogd's wrapper-to-GDScript source map.

Godot instantiates one generated module object and evaluates its top level once
during collection. A top-level failure is a collection failure for the file.
Everything else, including ordinary expressions, control flow, relative
imports, and tstogd limitations such as currently unsupported `try`, `catch`,
`finally`, and `throw`, follows tstogd directly. ViDot does not invent alternate
semantics for those constructs.

## Collection, Selection, and Execution

ViDot does not statically infer the test tree from the TypeScript AST. Static
inference would diverge for registration performed by loops, conditions,
computed names, and ordinary top-level code.

Instead, Godot dynamically loads the generated test module. Calls to `describe`,
`test`, and the hook registrars build the actual tree in the Godot runner. Test
callbacks are registered during collection and invoked later during execution.
Mutable module state remains on the generated module instance throughout that
file's run.

The Node.js adapter passes the relevant Vitest selection inputs when it launches
the file process. After collection, Godot applies ViDot's implementation of the
supported `.only`, `.skip`, name, location, and task-selection behavior to the
tree it actually collected. There is no post-collection Node-to-Godot handshake.
When the pinned Vitest minor changes, maintenance must compare the relevant
upstream collection and filtering source and extend compatibility fixtures for
any changed behavior.

Test and hook callbacks receive an explicit ViDot context. Its first required
field is `tree`, the real Godot `SceneTree`. Additional context fields are added
only when a real test requires them.

Godot emits the collected tree and test results as one-way structured
process-output events. The custom pool maps those events into Vitest's worker,
task, and reporter lifecycle.

## Vitest API Compatibility

ViDot preserves Vitest semantics wherever GDScript and the selected tstogd
version can represent them. Any deferred or unsupported boundary is documented
explicitly rather than silently assigned different behavior.

The first compatibility slice contains:

- `test` and `describe`;
- `beforeAll`, `beforeEach`, `afterEach`, and `afterAll`;
- `.skip` and `.only`;
- `expect`, `expect.soft`, and `.not`;
- the value, collection, and numeric matchers exercised by the editable proof
  and ViKeeper Move test;
- asynchronous test bodies and ordinary Godot signal or frame waits;
- callback context with `tree`.

Matcher behavior should preserve Vitest behavior whenever the underlying values
permit it. The first exact matcher inventory comes from the two acceptance
proofs; ViDot should not build unused matchers merely to complete a broad API
surface.

Normal `expect` is fail-fast within the current test or hook callback. A failed
assertion stops the remaining callback. In a test body it marks that test failed
while still allowing applicable cleanup and later tests to run. `expect.soft`
records the failure and continues the callback. A `beforeEach` failure skips the
body but still enters cleanup; an `afterEach` failure is attached to the same
test result.

GDScript has no catchable exception equivalent suitable for implementing this
contract, and ViDot cannot use GDScript `assert` as its failure transport. The
test-specific front end therefore lowers normal assertions written directly in
a test or hook callback into runner-aware failure and early-return control flow.
Soft assertions only record the failure.

An `expect` call inside an arbitrary helper is undefined behavior. ViDot does
not inspect the call graph, reject such helpers, change their return types, or
add hidden propagation state. A helper that needs to report failure returns an
ordinary value or result, and its caller performs the guaranteed assertion
directly in the test or hook callback.

Snapshots, mocks, spies, fake timers, custom matchers, data-driven test helpers,
retries, and concurrent tests are deferred until a real test requires them.
They are not permanent non-goals.

## Results, Failures, and Timeouts

An assertion failure in a test body or per-test hook invalidates only the
affected test. Cleanup still runs, and later tests in the same file may
continue. Failures in `beforeAll` or `afterAll` are attributed to their owning
suite according to the targeted Vitest lifecycle. A collection failure, Godot
crash, runner failure, or process teardown failure invalidates the remaining
tests in that file. Other files remain isolated in their own processes.

The first timeout behavior is intentionally process-scoped. If the active test
exceeds its timeout, the Node.js adapter terminates that file's Godot process.
The timed-out test and every remaining test in that file fail; other file
processes are unaffected. Coroutine cancellation and recovery within the same
process are deferred until there is evidence that they are needed.

Godot runtime errors and assertion failures must map back to original TypeScript
locations. ViDot therefore composes its original-to-wrapper mapping with
tstogd's wrapper-to-GDScript source map. The exact map representation, stack
normalization, and diagnostic formatting are implementation details, not a
reason to expose generated wrapper locations to users.

## Initial Acceptance

Implementation starts by reproducing only the required Vitest API and writing
the custom-pool adapter. The first proof uses the small editable Godot example
and must demonstrate:

- TypeScript test-module wrapping through unmodified tstogd;
- module evaluation and dynamic test-tree collection inside Godot;
- launch-time selection inputs and Godot-side filtering without a handshake;
- shared module state across hooks and tests;
- direct normal and soft assertion semantics, including `afterEach` after a
  failure;
- callback context exposing the real `SceneTree`;
- one asynchronous Godot signal or frame wait;
- one process per test file, file-process termination on timeout, and
  deterministic teardown;
- structured tree and result delivery to native Vitest reporting;
- original TypeScript source attribution;
- no permanent project mutation or ViDot-installed Autoload, Mod, or
  GDExtension.

The next proof migrates the existing ViKeeper Move test, adapting code that the
selected tstogd version cannot convert instead of adding alternate ViDot
language semantics. ViKeeper owns game startup and fixture-scene construction;
DataCollectorAI keeps the assertions next to the Mod.

## Remaining Implementation Details

The remaining choices are local implementation work and should be resolved by
the smallest end-to-end proof rather than another product-design round:

- the generated wrapper's concrete AST and source-map representation;
- the structured output prefix and payload schema, including malformed output;
- placement of the runner, generated module, and editable-project fixtures;
- the minimal Vitest configuration surface for choosing an editable project.
