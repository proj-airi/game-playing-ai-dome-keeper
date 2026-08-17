import type { _Example } from './src/main.ts'
import { describe, expect, test } from '@vidot/vitest/test'

describe('editable Godot project', () => {
  const expectedValue = 7

  test('runs a callback without context', () => {
    expect(expectedValue).toBe(7)
  })

  test('runs inside the project', async (context) => {
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
