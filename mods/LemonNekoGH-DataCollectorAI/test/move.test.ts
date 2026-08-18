import type { _DataCollectorAI } from '../src/controller.ts'
import type { _MoveTest } from './fixtures/move_test.ts'
import { afterEach, expect, test } from '@vidot/vitest/test'

const controllerPath = 'DataCollectorAI'

afterEach((context) => {
  const controller = context.tree.root.get_node_or_null(controllerPath)
  if (controller !== null)
    controller.call('reset')
})

test('moves the Engineer to a non-adjacent underground tile', async (context) => {
  const testRoot = OS.get_environment('VIKEEPER_TEST_ROOT')
  const fixturePath = testRoot.path_join('runtime/move_test.gd')
  const fixture = context.instantiate<_MoveTest>(fixturePath)
  if (fixture === null)
    return

  context.tree.root.add_child(fixture)
  const hasController = await context.waitUntil(
    () => context.tree.root.has_node(controllerPath),
    5_000,
  )
  if (!expect(hasController).toBe(true))
    return

  const controllerNode = context.tree.root.get_node_or_null(controllerPath)
  if (!expect(controllerNode !== null).toBe(true) || controllerNode === null)
    return
  const controller = controllerNode as _DataCollectorAI

  const ready = await context.waitUntil(
    () => fixture.startup_error !== '' ? true : fixture.keeper_positioned ? controller.move_to_ready : false,
    60_000,
  )
  if (!expect(ready).toBe(true))
    return
  if (!expect(fixture.startup_error).toBe(''))
    return
  if (!expect(fixture.keeper_positioned).toBe(true))
    return
  if (!expect(controller.move_to_ready).toBe(true))
    return
  if (!expect(fixture.test_map_selected).toBe(true))
    return

  if (OS.has_feature('movie')) {
    DisplayServer.window_move_to_foreground()
    const focused = await context.waitUntil(
      () => DisplayServer.window_is_focused(),
      5_000,
    )
    if (!expect(focused).toBe(true))
      return
  }

  const current = controller.current_tile()
  if (!expect(current).toEqual(fixture.move_start))
    return

  fixture.watch_task(controller)
  if (!expect(controller.start_move_to(current)).toBe(true))
    return

  const alreadyThereFinished = await context.waitUntil(
    () => fixture.task_finished,
    5_000,
  )
  if (!expect(alreadyThereFinished).toBe(true))
    return
  if (!expect(fixture.task_failure).toBe(''))
    return
  if (!expect(controller.current_tile()).toEqual(current))
    return

  const target = fixture.move_target
  if (!expect(absi(target.x - current.x) + absi(target.y - current.y) > 1).toBe(true))
    return
  if (!expect(target.x !== current.x).toBe(true))
    return
  if (!expect(target.y !== current.y).toBe(true))
    return
  fixture.watch_task(controller)

  if (!expect(controller.start_move_to(target)).toBe(true))
    return

  const finished = await context.waitUntil(
    () => fixture.task_finished,
    15_000,
  )
  if (!expect(finished).toBe(true))
    return
  if (!expect(fixture.task_failure).toBe(''))
    return
  if (!expect(controller.get_last_error()).toBe(''))
    return

  if (!expect(controller.current_tile()).toEqual(target))
    return
  await context.tree.create_timer(1).timeout
  expect(controller.current_tile()).toEqual(target)
})
