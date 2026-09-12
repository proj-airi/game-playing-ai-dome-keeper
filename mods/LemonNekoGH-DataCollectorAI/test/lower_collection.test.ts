/* eslint-disable object-shorthand -- tstogd requires explicit dictionary values. */
import type { FixtureDrop } from '@vikeeper/vitest'
import { expect, test } from '@vidot/vitest'
import { _LowerSession } from '../src/lower_session.ts'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _AttackMonsterTask } from '../src/tasks/attack_monster_task.ts'
import { _AttackMonsterTest } from './fixtures/attack_monster_test.ts'
import { _LowerScenario } from './fixtures/lower_scenario.ts'

test('collects seeded Lower v0 Sessions', async (context) => {
  const count = int(OS.get_environment('LOWER_V0_COUNT'))
  const firstSeed = int(OS.get_environment('LOWER_V0_SEED'))
  const pairs = [
    'pickup:iron',
    'pickup:cobalt',
    'pickup:water',
    'drop:iron',
    'drop:cobalt',
    'drop:water',
    'activate:gadget_chamber',
    'attack:monster',
    'enter:mine',
  ]
  const requestedPair = OS.get_environment('LOWER_V0_PAIR')
  const requestedInstruction = pairs.find(requestedPair)
  if (requestedPair !== '' && requestedInstruction < 0) {
    push_error(`Unsupported LOWER_V0_PAIR: ${requestedPair}`)
    return
  }
  const firstInstruction = requestedPair === '' ? 0 : requestedInstruction
  const instructionCount = requestedPair === '' ? pairs.size() : 1
  const names = ['iron', 'cobalt', 'water', 'gadget_chamber', 'monster', 'mine']
  const types: FixtureDrop['type'][] = [CONST.IRON, CONST.SAND, CONST.WATER]
  for (let run = 0; run < count; run += 1) {
    for (let slot = 0; slot < instructionCount; slot += 1) {
      const instruction = firstInstruction + slot
      const seed = firstSeed + run * 9 + instruction
      const state = GameWorld.devState as Dictionary<string, unknown>
      state.lockedSeed = seed
      const taskName = instruction < 3 ? 'pickup' : instruction < 6 ? 'drop' : instruction === 6 ? 'activate' : instruction === 7 ? 'attack' : 'enter'
      const target = instruction === 8 ? names[5] : names[instruction < 6 ? instruction % 3 : instruction - 3]
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
      if (instruction === 8) {
        const camera = Level.viewports.getPlayerCam(keeper.playerId) as KeeperCamera
        const cameraSettled = await context.waitUntil(
          () => camera.getCamDelta().length_squared() <= 1.0,
          5_000,
        )
        if (!expect(cameraSettled).toBe(true) || !expect(keeper.isInsideDome).toBe(true))
          return
      }

      const laserTask = new _AttackMonsterTask()
      if (attack.laser !== null && attack.monster !== null)
        laserTask.initialize(attack.laser, attack.monster)
      const task = instruction === 7 ? laserTask : fixture.task()
      const recorder = new _LowerSession()
      node.add_child(recorder)
      const scenario = {
        seed: seed,
        map_fixture: instruction === 7 ? 'attack' : instruction === 8 ? 'central-shaft-entry' : 'move-supported-mixed-cargo',
        drops: fixture.scenario.drops,
        task: taskName,
        target: target,
        start: instruction === 8
          ? { x: fixture.enterStart.x, y: fixture.enterStart.y }
          : { x: fixture.start.x, y: fixture.start.y },
        position: instruction === 8 ? 'mine' : { x: fixture.target.x, y: fixture.target.y },
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
      const start = instruction === 8 ? fixture.enterStart : fixture.start
      print(`Lower Session: ${taskName}/${target} seed=${seed} ${start} -> ${fixture.target}`)
      node.queue_free()
      await node.tree_exited
      if (instruction !== 7)
        attack.free()
      else
        fixture.free()
    }
  }
})
