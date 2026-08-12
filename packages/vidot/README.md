# ViDot

ViDot is a Godot integration for Vitest. The repository's
[`examples/basic-vidot`](../../examples/basic-vidot) project keeps its Godot
files, Vitest configuration, lifecycle setup, and test together. ViDot
installs the compiled Autoload only into an isolated project mirror and gives
each test file a file-scoped `vidot` fixture backed by one Godot process.

Run the example through the repository's pinned tools:

```bash
mise run vidot:test
```

Configure the editable project once from Vitest `globalSetup`:

```ts
import { setupViDot } from '@vidot/vitest/setup'

export default setupViDot(projectPath)
```

Pass `scene` when a project test owns a dedicated main scene instead of the
project's ordinary entry point:

```ts
export default setupViDot(projectPath, {
  scene: 'res://tests/integration_fixture.tscn',
})
```

Pass an AVI path as `movie` to run the same tests through Godot Movie Maker
instead of headless mode. ViDot uses a decorated 960×540 window at 30 FPS.

Tests use the file-scoped fixture without managing the Godot process:

```ts
test('completes later', async ({ vidot }) => {
  const completed = vidot.waitForSignal('/root/Example', 'completed')
  await vidot.call('/root/Example', 'set_later', [1])
  await completed
})
```
