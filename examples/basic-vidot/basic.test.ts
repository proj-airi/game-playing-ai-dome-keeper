import { expect, test } from '@vidot/vitest'

test('controls an example Godot project', async ({ vidot }) => {
  const node = '/root/Example'
  expect(await vidot.get(node, 'value')).toBe(0)
  expect(await vidot.set(node, 'value', 1)).toBe(1)
  expect(await vidot.call(node, 'increment', [1])).toBe(2)

  const property = vidot.waitForProperty(node, 'value', 3)
  await vidot.call(node, 'set_later', [3])
  await expect(property).resolves.toBe(3)

  const signal = vidot.waitForSignal(node, 'completed')
  await vidot.call(node, 'set_later', [4])
  await expect(signal).resolves.toBeNull()
  expect(await vidot.get(node, 'value')).toBe(4)

  await expect(vidot.waitForSignal(node, 'completed', 20)).rejects.toThrow('Timed out')
  expect(await vidot.get(node, 'value')).toBe(4)
})
