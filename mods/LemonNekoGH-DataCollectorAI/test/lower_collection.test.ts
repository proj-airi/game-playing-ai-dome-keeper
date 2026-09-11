/* eslint-disable object-shorthand -- tstogd requires explicit dictionary values. */
import type { FixtureDrop } from '@vikeeper/vitest'
import { expect, test } from '@vidot/vitest'
import { _LowerSession } from '../src/lower_session.ts'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _AttackMonsterTask } from '../src/tasks/attack_monster_task.ts'
import { _AttackMonsterTest } from './fixtures/attack_monster_test.ts'
import { _LowerScenario } from './fixtures/lower_scenario.ts'

test('collects seeded Lower v0 Sessions', async (context) => {
  context.tree.root.unfocusable = true
  const count = int(OS.get_environment('LOWER_V0_COUNT'))
  const firstSeed = int(OS.get_environment('LOWER_V0_SEED'))
  const names = ['iron', 'cobalt', 'water', 'gadget_chamber', 'monster']
  const types: FixtureDrop['type'][] = [CONST.IRON, CONST.SAND, CONST.WATER]
  for (let run = 0; run < count; run += 1) {
    for (let instruction = 0; instruction < 8; instruction += 1) {
      const seed = firstSeed + run * 8 + instruction
      const state = GameWorld.devState as Dictionary<string, unknown>
      state.lockedSeed = seed
      const taskName = instruction < 3 ? 'pickup' : instruction < 6 ? 'drop' : instruction === 6 ? 'activate' : 'attack'
      const target = names[instruction < 6 ? instruction % 3 : instruction - 3]
      const fixture = new _LowerScenario()
      const attack = new _AttackMonsterTest()
      const node = instruction === 7 ? attack : fixture
      if (instruction !== 7)
        fixture.configure(taskName, types[instruction % 3], seed)
      context.tree.root.add_child(node)
      const ready = await context.waitUntil(() => node.startup_error !== ''
        || (instruction === 7 ? attack.attack_ready : fixture.ready_for_task()), 60_000)
      if (!expect(ready).toBe(true) || !expect(node.startup_error).toBe(''))
        return
      if (!expect(Level.getDomes().size()).toBe(1))
        return
      if (taskName === 'pickup') {
        const drop = fixture.fixture_drops[0]
        const settled = await context.waitUntil(() => drop.sleeping, 5_000)
        if (!expect(settled).toBe(true)
          || !expect(Level.map.getTileCoord(drop.global_position)).toEqual(fixture.target)) {
          return
        }
      }
      const keeper = Keepers.local.first()
      const laserTask = new _AttackMonsterTask()
      if (attack.laser !== null && attack.monster !== null)
        laserTask.initialize(attack.laser, attack.monster)
      const task = instruction === 7 ? laserTask : fixture.task()
      const recorder = new _LowerSession()
      node.add_child(recorder)
      const scenario = {
        seed: seed,
        map_fixture: instruction === 7 ? 'attack' : 'move-supported-mixed-cargo',
        drops: fixture.scenario.drops,
        task: taskName,
        target: target,
        start: { x: fixture.start.x, y: fixture.start.y },
        position: { x: fixture.target.x, y: fixture.target.y },
      }
      if (!expect(recorder.begin(OS.get_environment('LOWER_V0_DATASET_DIR'), taskName, target, scenario)).toBe(''))
        return
      const executor = new _TaskExecutor()
      node.add_child(executor)
      executor.recorder = recorder
      executor.task_completed.connect(attack._task_completed)
      executor.task_failed.connect(attack._task_failed)
      const error = executor.start(keeper, task)
      if (!expect(error).toBe(''))
        return
      const finished = await context.waitUntil(() => attack.task_finished, 30_000)
      if (!finished) {
        push_error(`Lower timeout: ${taskName}/${target} seed=${seed} keeper=${keeper.global_position} paused=${GameWorld.paused} focused=${DisplayServer.window_is_focused()} held=${recorder.held}`)
        for (const drop of fixture.fixture_drops)
          push_error(`Lower target: ${drop.global_position}`)
      }
      executor.cancel()
      const success = bool(finished && attack.task_failure === '')
      const promotion = recorder.finish(success)
      if (!expect(attack.task_failure).toBe('') || !expect(finished).toBe(true) || !expect(promotion).toBe(''))
        return
      print(`Lower Session: ${taskName}/${target} seed=${seed} ${fixture.start} -> ${fixture.target}`)
      node.queue_free()
      await node.tree_exited
      if (instruction !== 7)
        attack.free()
      else
        fixture.free()
    }
  }
})
