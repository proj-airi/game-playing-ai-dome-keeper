import { expect, test } from '@vidot/vitest'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _MoveToTask } from '../src/tasks/move_to_task.ts'
import { _MoveTest } from './fixtures/move_test.ts'

const testName = 'moves the Engineer to a non-adjacent underground tile'

test(testName, async (context) => {
  const fixture = new _MoveTest()
  fixture.test_name = testName
  context.tree.root.add_child(fixture)
  const ready = await context.waitUntil(
    () => fixture.startup_error !== '' || fixture.fixture_ready,
    60_000,
  )
  if (!expect(ready).toBe(true))
    return
  if (!expect(fixture.startup_error).toBe(''))
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
  const current: Vector2i = Level.map.getTileCoord(keeper.global_position)
  if (!expect(current).toEqual(fixture.move_start))
    return

  const executor = new _TaskExecutor()
  fixture.add_child(executor)
  const alreadyThereTask = new _MoveToTask()
  alreadyThereTask.initialize(current)
  fixture.watch_task(executor)
  if (!expect(executor.start(keeper, alreadyThereTask)).toBe(''))
    return

  const alreadyThereFinished = await context.waitUntil(
    () => fixture.task_finished,
    5_000,
  )
  if (!expect(alreadyThereFinished).toBe(true))
    return
  if (!expect(fixture.task_failure).toBe(''))
    return
  if (!expect(Level.map.getTileCoord(keeper.global_position)).toEqual(current))
    return

  const target = fixture.move_target
  if (!expect(absi(target.x - current.x) + absi(target.y - current.y) > 1).toBe(true))
    return
  if (!expect(target.x !== current.x).toBe(true))
    return
  if (!expect(target.y !== current.y).toBe(true))
    return

  const moveTask = new _MoveToTask()
  moveTask.initialize(target)
  fixture.watch_task(executor)
  if (!expect(executor.start(keeper, moveTask)).toBe(''))
    return

  const finished = await context.waitUntil(
    () => fixture.task_finished,
    15_000,
  )
  if (!expect(finished).toBe(true))
    return
  if (!expect(fixture.task_failure).toBe(''))
    return

  if (!expect(Level.map.getTileCoord(keeper.global_position)).toEqual(target))
    return
  await context.tree.create_timer(1).timeout
  expect(Level.map.getTileCoord(keeper.global_position)).toEqual(target)
})
