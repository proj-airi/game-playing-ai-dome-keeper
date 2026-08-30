import { expect, test } from '@vidot/vitest'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _AttackMonsterTask } from '../src/tasks/attack_monster_task.ts'
import { _AttackMonsterTest } from './fixtures/attack_monster_test.ts'

const testName = 'aims the Laser Dome and kills one monster'

test(testName, async (context) => {
  const fixture = new _AttackMonsterTest()
  fixture.test_name = testName
  context.tree.root.add_child(fixture)
  const fixtureReady = await context.waitUntil(
    () => fixture.startup_error !== '' ? true : fixture.fixture_ready,
    60_000,
  )
  if (!expect(fixtureReady).toBe(true))
    return
  if (!expect(fixture.startup_error).toBe(''))
    return

  const attackReady = await context.waitUntil(() => fixture.attack_ready, 30_000)
  if (!expect(attackReady).toBe(true))
    return

  const keeper = Keepers.local.first()
  const laser = fixture.laser
  const monster = fixture.monster
  const station = fixture.station
  if (!expect(is_instance_valid(keeper)).toBe(true))
    return
  if (!expect(laser !== null).toBe(true))
    return
  if (!expect(monster !== null).toBe(true))
    return
  if (!expect(station !== null).toBe(true))
    return
  if (laser === null || monster === null || station === null)
    return
  if (!expect(is_instance_valid(laser)).toBe(true))
    return
  if (!expect(is_instance_valid(monster)).toBe(true))
    return
  if (!expect(keeper.isInsideStation).toBe(true))
    return
  if (!expect(station.keeperInStation === keeper).toBe(true))
    return

  const executor = new _TaskExecutor()
  fixture.add_child(executor)
  const task = new _AttackMonsterTask()
  task.initialize(laser, monster)
  if (!expect(executor.start(keeper, task)).toBe(''))
    return

  const killed = await context.waitUntil(() => fixture.monster_killed, 30_000)
  if (!expect(killed).toBe(true))
    return

  if (OS.has_feature('movie')) {
    const exited = await context.waitUntil(() => fixture.monster_exited, 10_000)
    expect(exited).toBe(true)
  }
})
