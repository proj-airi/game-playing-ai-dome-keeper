import type { _DropByTypeTest } from './fixtures/drop_by_type_test.ts'
import { expect, test } from '@vidot/vitest'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _DropByType } from '../src/tasks/drop_by_type.ts'

const testName = 'drops one requested type and repicks every mistakenly dropped item'

test(testName, async (context) => {
  const testRoot = OS.get_environment('VIKEEPER_TEST_ROOT')
  const fixturePath = testRoot.path_join('runtime/drop_by_type_test.gd')
  const fixture = context.instantiate<_DropByTypeTest>(fixturePath)
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
  if (!expect(fixture.fixture_drops.size()).toBe(2))
    return

  const keeper = Keepers.local.first()
  if (!expect(is_instance_valid(keeper)).toBe(true))
    return
  if (!expect(Level.map.getTileCoord(keeper.global_position)).toEqual(fixture.keeper_start))
    return

  const initialDrops: Drop[] = []
  for (const drop of fixture.fixture_drops) {
    if (!expect(drop.isCarriedBy(keeper)).toBe(true))
      return
    initialDrops.append(drop)
  }

  const wrongDrop = initialDrops[0]
  if (!expect(wrongDrop.type).toBe(CONST.SAND))
    return
  if (!expect(initialDrops[1].type).toBe(CONST.IRON))
    return
  if (!expect(wrongDrop.global_position.distance_to(keeper.global_position)
    > initialDrops[1].global_position.distance_to(keeper.global_position)).toBe(true)) {
    return
  }

  const executor = new _TaskExecutor()
  fixture.add_child(executor)
  const task = new _DropByType()
  task.initialize(CONST.IRON)
  fixture.watch_task(executor)
  if (!expect(executor.start(keeper, task)).toBe(''))
    return

  const finished = await context.waitUntil(
    () => fixture.task_finished,
    20_000,
  )
  if (!expect(finished).toBe(true))
    return
  if (!expect(fixture.task_failure).toBe(''))
    return
  if (!expect(fixture.drop_presses >= 2).toBe(true))
    return
  if (!expect(fixture.drop_releases).toBe(fixture.drop_presses))
    return
  if (!expect(Input.is_action_pressed('keeper1_drop')).toBe(false))
    return

  if (!expect(fixture.released_drops.size() >= 2).toBe(true))
    return
  if (!expect(fixture.released_drops[0]).toBe(wrongDrop))
    return
  if (!expect(fixture.released_drops[0].type).toBe(CONST.SAND))
    return

  let firstExpectedRelease = -1
  for (let index = 0; index < fixture.released_drops.size(); index += 1) {
    if (fixture.released_drops[index].type === CONST.IRON) {
      firstExpectedRelease = index
      break
    }
  }
  if (!expect(firstExpectedRelease > 0).toBe(true))
    return

  if (!expect(keeper.carriedCarryables.size()).toBe(initialDrops.size() - 1))
    return
  if (!expect(keeper.carriedCarryables.has(wrongDrop)).toBe(true))
    return

  let missingCount = 0
  let missingDrop: Drop | null = null
  for (const initial of initialDrops) {
    if (!keeper.carriedCarryables.has(initial)) {
      missingCount += 1
      missingDrop = initial
    }
  }
  if (!expect(missingCount).toBe(1))
    return
  if (!expect(missingDrop === null ? '' : missingDrop.type).toBe(CONST.IRON))
    return

  for (const released of fixture.released_drops) {
    if (released.type !== CONST.IRON && !expect(keeper.carriedCarryables.has(released)).toBe(true))
      return
  }
})
