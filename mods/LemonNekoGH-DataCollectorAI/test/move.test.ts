import { expect, test } from '@vidot/vitest'

const controller = '/root/DataCollectorAI'

test('moves the Engineer into one adjacent tile', async ({ vidot }) => {
  await vidot.waitForProperty(controller, 'move_ready', true, 60_000)
  try {
    expect(await vidot.get('/root/MoveTest', 'test_map_selected')).toBe(true)
    const current = await vidot.call(controller, 'current_tile') as number[]
    expect(current).toHaveLength(2)
    const target = [current[0] + 1, current[1]]
    const completed = vidot.waitForSignal(controller, 'task_completed', 15_000)

    expect(await vidot.call(controller, 'start_move', target)).toBe(true)
    try {
      await expect(completed).resolves.toBeNull()
    }
    catch (error) {
      const reason = await vidot.call(controller, 'get_last_error')
      throw new Error(`Move did not complete${reason ? `: ${reason}` : ''}`, { cause: error })
    }

    expect(await vidot.call(controller, 'current_tile')).toEqual(target)
    expect(await vidot.call(controller, 'get_last_error')).toBe('')
    await new Promise(resolve => setTimeout(resolve, 1_000))
    expect(await vidot.call(controller, 'current_tile')).toEqual(target)
  }
  finally {
    await vidot.call(controller, 'reset')
  }
})
