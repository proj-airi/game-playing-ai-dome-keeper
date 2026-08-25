import type { _ActivateGadgetChamberTest } from './fixtures/activate_gadget_chamber_test.ts'
import { expect, test } from '@vidot/vitest'
import { _TaskExecutor } from '../src/task_executor.ts'
import { _ActivateGadgetChamber } from '../src/tasks/activate_gadget_chamber.ts'

const testName = 'activates a Gadget Chamber and carries its new Gadget'

test(testName, async (context) => {
  const testRoot = OS.get_environment('VIKEEPER_TEST_ROOT')
  const fixturePath = testRoot.path_join('runtime/activate_gadget_chamber_test.gd')
  const fixture = context.instantiate<_ActivateGadgetChamberTest>(fixturePath)
  if (fixture === null)
    return

  fixture.test_name = testName
  context.tree.root.add_child(fixture)
  const ready = await context.waitUntil(
    () => fixture.startup_error !== '' ? true : fixture.chamber_ready,
    60_000,
  )
  if (!expect(ready).toBe(true))
    return
  if (!expect(fixture.startup_error).toBe(''))
    return
  if (!expect(fixture.fixture_landmarks.size()).toBe(1))
    return

  const chamber = fixture.fixture_landmarks[0] as Chamber
  if (!expect(chamber.currentState).toBe(Chamber.State.OPEN))
    return
  if (!expect(chamber.drop_type).toBe(CONST.GADGET))
    return

  const keeper = Keepers.local.first()
  if (!expect(is_instance_valid(keeper)).toBe(true))
    return
  if (!expect(Level.map.getTileCoord(keeper.global_position)).toEqual(fixture.keeper_start))
    return

  const executor = new _TaskExecutor()
  fixture.add_child(executor)
  const task = new _ActivateGadgetChamber()
  task.initialize(chamber)
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
  if (!expect(chamber.currentState).toBe(Chamber.State.EMPTY))
    return
  if (!expect(Input.is_action_pressed('ui_select')).toBe(false))
    return

  let carriesGadget = false
  for (const candidate of keeper.carriedCarryables) {
    if (candidate instanceof Drop && candidate.type === CONST.GADGET)
      carriesGadget = true
  }

  expect(carriesGadget).toBe(true)
})
