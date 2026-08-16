import type { _Example } from './src/main.ts'
import { describe, expect, test } from '@vidot/vitest/test'

describe('editable Godot project', () => {
  const expectedValue = 7

  test('runs a callback without context', () => {
    expect(expectedValue).toBe(7)
  })

  test('runs inside the project', async (context) => {
    const scene = gd.eval<_Example>('load("res://main.tscn").instantiate()')
    context.tree.root.add_child(scene)

    expect(scene.increment(2)).toBe(2)

    scene.set_later(expectedValue)
    await scene.completed

    expect(scene.value).toBe(expectedValue)
  })
})
