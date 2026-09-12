import { expect, test } from '@vidot/vitest'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _LowerScenario } from './fixtures/lower_scenario.ts'

test('enters the mine from the dome', async (context) => {
  const fixture = new _LowerScenario()
  fixture.test_name = 'enters the mine from the dome'
  fixture.configure('enter', CONST.IRON, 20260921)
  const alternate = new _LowerScenario()
  alternate.configure('enter', CONST.IRON, 20260930)
  if (!expect(fixture.enterStart.x === alternate.enterStart.x).toBe(false)
    || !expect(fixture.enterStart.y === alternate.enterStart.y).toBe(false)) {
    alternate.free()

    return
  }
  alternate.free()
  context.tree.root.add_child(fixture)

  const ready = await context.waitUntil(() => fixture.startup_error !== '' || fixture.ready_for_task(), 60_000)
  if (!expect(ready).toBe(true) || !expect(fixture.startup_error).toBe(''))
    return

  const keeper = Keepers.local.first()
  if (!expect(keeper.isInsideDome).toBe(true) || !expect(keeper.isInsideStation).toBe(false))
    return

  const executor = new _TaskExecutor()
  fixture.add_child(executor)
  fixture.watch_task(executor)
  if (!expect(executor.start(keeper, fixture.task())).toBe(''))
    return

  const finished = await context.waitUntil(() => fixture.task_finished, 10_000)
  if (!finished) {
    const dome = Level.getDome(keeper.teamId)
    const collision = keeper.move_and_collide(Vector2.DOWN, true)
    const collider = collision === null ? null : collision.get_collider()
    const colliderPath = collider instanceof Node ? collider.get_path() : collider
    push_error(`EnterMine timeout: keeper=${keeper.global_position} dome=${dome.global_position} inside=${keeper.isInsideDome} input=${keeper.moveDirectionInput} move=${keeper.move} velocity=${keeper.velocity} tile=${Level.map.getTileCoord(keeper.global_position)} collider=${colliderPath}`)
  }
  if (!expect(finished).toBe(true) || !expect(fixture.task_failure).toBe(''))
    return
  if (!expect(keeper.isInsideDome).toBe(false))
    return
  expect(Input.is_action_pressed('ui_down')).toBe(false)
})
