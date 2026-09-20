import { describe, expect, test } from '@vidot/vitest'
import { _Example } from './src/main.ts'

describe('editable Godot project', () => {
  const expectedValue = 7

  test('runs inside the project', async (context) => {
    const importedScene = new _Example()
    context.tree.root.add_child(importedScene)
    expect(importedScene.increment(1)).toBe(1)
    importedScene.queue_free()

    const scriptPath = ProjectSettings.globalize_path('res://scripts/main.gd')
    const scene = context.instantiate<_Example>(scriptPath)
    if (!expect(scene !== null).toBe(true) || scene === null)
      return

    context.tree.root.add_child(scene)

    expect(scene.increment(2)).toBe(2)

    scene.set_later(expectedValue)
    expect(await context.waitUntil(() => scene.value === expectedValue, 500)).toBe(true)
    expect(scene.value).toBe(expectedValue)
  })
})
