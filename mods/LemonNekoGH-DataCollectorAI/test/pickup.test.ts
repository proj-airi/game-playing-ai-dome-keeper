import type { _PickupTest } from './fixtures/pickup_test.ts'
import { expect, test } from '@vidot/vitest'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _PickupTargetTask } from '../src/tasks/pickup_target_task.ts'

const testName = 'moves to, focuses, and picks up a Drop'

test(testName, async (context) => {
  const testRoot = OS.get_environment('VIKEEPER_TEST_ROOT')
  const fixturePath = testRoot.path_join('runtime/pickup_test.gd')
  const fixture = context.instantiate<_PickupTest>(fixturePath)
  if (fixture === null)
    return

  fixture.test_name = testName
  context.tree.root.add_child(fixture)
  const ready = await context.waitUntil(
    () => fixture.startup_error !== '' ? true : fixture.fixture_ready,
    60_000,
  )
  if (!expect(ready).toBe(true))
    return
  if (!expect(fixture.startup_error).toBe(''))
    return
  if (!expect(fixture.fixture_drops.size()).toBe(1))
    return

  const target = fixture.fixture_drops[0]
  if (!expect(target.type).toBe(CONST.IRON))
    return
  if (!expect(target.isCarried()).toBe(false))
    return
  const settled = await context.waitUntil(
    () => target.sleeping,
    5_000,
  )
  if (!expect(settled).toBe(true))
    return
  if (!expect(Level.map.getTileCoord(target.global_position)).toEqual(fixture.pickup_target_position))
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

  const keeper = Keepers.local.first()
  if (!expect(is_instance_valid(keeper)).toBe(true))
    return
  if (!expect(Level.map.getTileCoord(keeper.global_position)).toEqual(fixture.pickup_start))
    return
  const executor = new _TaskExecutor()
  fixture.add_child(executor)
  const task = new _PickupTargetTask()
  task.initialize(target)
  fixture.watch_task(executor)
  if (!expect(executor.start(keeper, task)).toBe(''))
    return

  const finished = await context.waitUntil(
    () => fixture.task_finished,
    15_000,
  )
  if (!expect(finished).toBe(true))
    return
  if (!expect(fixture.task_failure).toBe(''))
    return
  if (!expect(fixture.target_was_focussed).toBe(true))
    return
  if (!expect(target.isCarried()).toBe(true))
    return

  expect(keeper.carriedCarryables.has(target)).toBe(true)
})
