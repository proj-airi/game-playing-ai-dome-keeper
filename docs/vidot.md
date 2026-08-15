# ViDot

This document owns ViDot's frozen Godot-native target contract. That target is
not implemented yet. The previous loopback WebSocket RPC predecessor has been
deliberately removed so its transport and API cannot become the default design.
The basic ViDot and ViKeeper Godot fixture assets remain, but neither fixture is
currently runnable; the new adapter will reconnect them.

## Problem and Intended Outcome

Vitest provides the TypeScript test authoring experience and outer test-run
orchestration, but a Node.js test body cannot execute Godot APIs or GDScript
semantics. ViDot lets developers author Vitest-shaped tests in TypeScript while
collecting and executing those tests inside the real Godot runtime.

The result is a Vitest integration, not a second user-facing test runner. Vitest
owns its CLI, candidate test-file discovery, watch mode, scheduling, filter
inputs, reporters, and final result presentation. Godot alone evaluates test
modules, dynamically collects and selects their test trees, runs hooks and test
bodies, and waits on engine state.

## Runtime Topology

```text
Vitest
  `-- ViDot custom pool
       `-- Node.js adapter
            |-- compiles the candidate TypeScript test modules
            |-- launches a Godot runner with the file list and raw filters
            `-- mirrors Godot's emitted tree and results into Vitest reporting

Godot runner
  |-- starts the target selected by the Vitest project configuration
  |    |-- an editable Godot project directory
  |    `-- a standalone unencrypted PCK
  |-- keeps the target's project settings and original Autoloads
  `-- for each candidate test file
       |-- loads and evaluates the compiled test module
       |-- dynamically collects the authoritative test tree
       |-- applies the supported Vitest selection semantics
       |-- runs the selected hooks, assertions, and test bodies
       `-- releases the module instance and the collected tree
```

The Node.js adapter uses Vitest's documented `PoolRunnerInitializer` and the
`init` scaffold from `vitest/worker` only for the worker protocol. It does not
use Vitest's built-in `runBaseTests`, evaluate a test module, collect a test
tree, or select tests. It compiles modules, manages the Godot process, and
rehydrates Godot's already-collected tree as Vitest reporting records.

ViDot uses the custom-pool boundary even though Vitest documents it as advanced
and experimental. The initial implementation targets Vitest 4.1.10. Its
supported minor must be pinned when the adapter is implemented, and a Vitest
minor upgrade requires focused Godot-side collection, selection, hook, and
reporting compatibility tests.

The initial pool runs with file isolation disabled and one worker so Vitest can
provide all candidate files in one request. One Godot process handles those
files sequentially against the configured target. This batching choice does not
merge their test modules: each file receives a fresh module instance and
collected tree. Process-level file isolation and cross-file parallelism are not
initial requirements.

## Supported Baselines

Each Vitest project configuration selects one target: an editable Godot project
directory or a standalone unencrypted PCK. Both target forms are supported for
Godot 4.3.1. A later Godot version may work, but the project does not guarantee
it. ViDot does not preflight, reject, or branch on the engine version; ordinary
startup, load, and runtime failures expose real incompatibility.

PCKs embedded in an executable and encrypted PCKs are outside the initial
scope. Released games with a separate unencrypted `.pck` are inside it.

ViDot does not define a second general TypeScript or module-compatibility
matrix. Apart from its test-module transformations, the language and import
surface is exactly what the selected `tstogd` version can convert. ViDot does
not add speculative prechecks for unsupported syntax or imports.

## Target Configuration and Project Ownership

The target is selected in Vitest's project configuration, not by a separate
ViDot CLI or by individual test files. The adapter starts Godot against the
configured project directory or starts the configured PCK as the main pack. A
PCK remains the process's target until that runner exits.

The target identifies the base Godot project or game; it does not absorb the
production Mod or other application-specific component being tested. The user
or an upper wrapper defines how those components participate in target startup;
ViDot does not define a generic Mod API, packaging format, or loader protocol.
ViKeeper is the first such wrapper. It accepts the Mod project as a ViKeeper
input and helps prepare Dome Keeper startup before handing the resolved target
configuration to ViDot.

Both launch modes use the target's project settings and original Autoload
configuration. ViDot starts its test runner instead of automatically entering
the target's original main scene. ViKeeper owns Dome Keeper-specific startup
and explicitly constructs the game scene and dependencies required by a test.
ViDot begins collection only after the `SceneTree` has initialized and the
target's original Autoloads have entered it. It does not acquire a game-specific
scene API.

ViDot must not permanently modify the configured project, target PCK, or
installed game. It must not require a ViDot Mod, Autoload, GDExtension,
production source change, or ViDot-aware production API inside the target game.
This boundary does not prohibit a user or wrapper from loading the production
Mod under test through the target's ordinary startup path.

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
during collection. A top-level failure is a collection failure for that file.
Everything else, including ordinary expressions, control flow, relative
imports, and tstogd limitations such as currently unsupported `try`, `catch`,
`finally`, and `throw`, follows tstogd directly. ViDot does not invent alternate
semantics for those constructs.

## Collection, Selection, Execution, and Cleanup

ViDot does not statically infer a test tree from the TypeScript AST. Static
inference would diverge for registration performed by loops, conditions,
computed names, and ordinary top-level code.

Godot loads each generated test module in turn. Calls to `describe`, `test`, and
the hook registrars build the authoritative tree in the Godot runner. Godot
alone interprets `.only` and `.skip` and applies name, location, and task
selection to the collected tree. There is no Node-side test registration,
recollection, or in-tree filtering.

The generated module instance remains alive throughout its file so hooks and
tests share module state. Scenes instantiated for a test belong to that test's
cleanup boundary and are released after `afterEach`. After `afterAll`, Godot
releases the module instance and clears that file's hooks and collected tree,
then loads the next file. The configured project or PCK, its settings, and its
original Autoloads remain alive for the runner process.

Test and hook callbacks receive an explicit ViDot context. Its first required
field is `tree`, the real Godot `SceneTree`. Additional context fields are added
only when a real test requires them.

Godot emits its authoritative collected tree and results as one-way structured
process-output events. The adapter mirrors that structure into Vitest's worker,
task, and reporter records; it does not infer or alter the tree.

## Vitest API Compatibility

ViDot preserves Vitest semantics wherever GDScript and the selected tstogd
version can represent them. Any deferred or unsupported boundary is documented
explicitly rather than silently assigned different behavior.

The first compatibility slice contains:

- `test` and `describe`;
- `beforeAll`, `beforeEach`, `afterEach`, and `afterAll`;
- `.skip` and `.only`;
- `expect`, `expect.soft`, and `.not`;
- the value, collection, and numeric matchers exercised by the initial proofs;
- asynchronous test bodies and ordinary Godot signal or frame waits;
- callback context with `tree`.

Matcher behavior preserves Vitest behavior whenever the underlying values
permit it. The first exact matcher inventory comes from the acceptance proofs;
ViDot does not build unused matchers merely to complete a broad API surface.

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
suite according to the targeted Vitest lifecycle. A collection failure
invalidates the remaining tests in that file, after which the runner cleans the
file boundary and continues with the next file.

If the active test times out or Godot crashes, the Node.js adapter terminates
that runner process. The active test and every remaining test in its file fail.
The adapter starts the same configured target in a replacement runner for files
that had not started. Coroutine cancellation and in-process recovery are
deferred until there is evidence that they are needed.

Godot runtime errors and assertion failures must map back to original TypeScript
locations. ViDot therefore composes its original-to-wrapper mapping with
tstogd's wrapper-to-GDScript source map. The exact map representation, stack
normalization, and diagnostic formatting are implementation details, not a
reason to expose generated wrapper locations to users.

## Initial Acceptance

Implementation starts by reproducing only the required Vitest API and writing
the custom-pool adapter. The first proof runs the same small fixture through an
editable project configuration and a standalone unencrypted PCK configuration.
It must demonstrate:

- selecting exactly one target form in Vitest's project configuration;
- starting either target without permanently modifying the project or PCK;
- TypeScript test-module wrapping through unmodified tstogd;
- module evaluation and dynamic test-tree collection only inside Godot;
- raw selection inputs and Godot-side filtering;
- identical Godot-side collection, selection, execution, and cleanup semantics
  for both target forms;
- at least two test files collected and executed sequentially in one process;
- scene cleanup after each test and module/tree cleanup after each file;
- shared module state across hooks and tests within one file;
- direct normal and soft assertion semantics, including `afterEach` after a
  failure;
- callback context exposing the real `SceneTree`;
- one asynchronous Godot signal or frame wait;
- structured tree and result delivery to native Vitest reporting;
- original TypeScript source attribution;
- process restart after a timeout while an unstarted later file still runs;
- no ViDot Mod, Autoload, GDExtension, or permanent target mutation.

The next proof starts the owned Dome Keeper PCK and migrates the existing
ViKeeper Move test. ViKeeper accepts the DataCollectorAI Mod project, prepares
the Dome Keeper-specific startup, and requires the real game Mod Loader to
validate and load the Mod without ViDot defining how Mods are packaged or
located. Code that the selected tstogd version cannot convert is adapted instead
of receiving alternate ViDot language semantics. ViKeeper owns Mod preparation,
game startup, scene construction, and teardown; DataCollectorAI keeps its
assertions next to the Mod source.

## Remaining Implementation Details

The remaining choices are local implementation work and should be resolved by
the smallest end-to-end proof rather than another product-design round:

- the generated wrapper's concrete AST and source-map representation;
- the structured output prefix and payload schema, including malformed output;
- placement of the runner and generated test modules for both target forms;
- the concrete Vitest configuration shape for selecting one editable project
  directory or standalone unencrypted PCK;
- the narrow wrapper boundary through which a user supplies target-specific
  startup behavior without adding application concepts to ViDot.
