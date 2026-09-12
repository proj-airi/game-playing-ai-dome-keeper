import type { FixtureDrop, FixtureScenario } from '@vikeeper/vitest'
import type { _TaskExecutor } from '../../src/task_executor.ts'
import type { Task } from '../../src/tasks/task.ts'
import { _Fixture } from '@vikeeper/vitest'
import { _ActivateGadgetChamber } from '../../src/tasks/activate_gadget_chamber.ts'
import { _DropByType } from '../../src/tasks/drop_by_type.ts'
import { _EnterMineTask } from '../../src/tasks/enter_mine_task.ts'
import { _PickupTargetTask } from '../../src/tasks/pickup_target_task.ts'

export class _LowerScenario extends _Fixture {
  instruction = 'pickup'
  resource = CONST.IRON
  enterStart = Vector2(-22, -35)
  start = Vector2i(-1, 0)
  target = Vector2i(1, 0)
  scenario: FixtureScenario = {
    drops: [],
    landmarks: [],
    map: {
      map_data: [
        { type: Data.TILE_EMPTY, position: Vector2i(0, -3) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, -2) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 2) },
      ],
      left_top: Vector2i(-2, -2),
      bottom_right: Vector2i(2, 3),
    },
  }

  task_failure = ''
  task_finished = false

  configure(instruction: string, resource: FixtureDrop['type'], seed: int): void {
    this.instruction = instruction
    this.resource = resource
    const random = new RandomNumberGenerator()
    random.seed = seed
    if (instruction === 'enter') {
      // Stay inside Dome 1's open interior while varying both alignment and
      // descent distance. The camera keeps its native in-dome rest position.
      this.enterStart = Vector2(
        random.randi_range(-36, 36),
        random.randi_range(-40, -8),
      )

      return
    }

    // Gadget Chamber anchors must leave room for their 2-by-2 footprint.
    const targetMax = instruction === 'activate' ? 1 : 2
    this.target = Vector2i(random.randi_range(-2, targetMax), random.randi_range(0, targetMax))
    this.start = Vector2i(random.randi_range(-2, 2), random.randi_range(0, 2))
    while (this.start.distance_to(this.target) < 2)
      this.start = Vector2i(random.randi_range(-2, 2), random.randi_range(0, 2))
    if (instruction === 'drop') {
      this.target = this.start
      const types: FixtureDrop['type'][] = [CONST.IRON, CONST.SAND, CONST.WATER]
      const count = random.randi_range(3, 8)
      this.scenario.drops.append({ type: resource, position: this.start })
      let other = resource
      while (other === resource)
        other = types[random.randi_range(0, 2)]
      this.scenario.drops.append({ type: other, position: this.start })
      for (let i = 2; i < count; i += 1)
        this.scenario.drops.append({ type: types[random.randi_range(0, 2)], position: this.start })
      for (let last = count - 1; last > 0; last -= 1) {
        const j = random.randi_range(0, last)
        const drop = this.scenario.drops[last]
        this.scenario.drops[last] = this.scenario.drops[j]
        this.scenario.drops[j] = drop
      }
    }
    else if (instruction === 'activate') {
      this.scenario.landmarks.append({ type: Data.TILE_GADGET, position: this.target })
    }
    else {
      this.scenario.drops.append({ type: resource, position: this.target })
    }
    for (const drop of this.scenario.drops) {
      this.scenario.map.map_data.append({
        type: Data.TILE_DIRT_START,
        position: Vector2i(drop.position.x, drop.position.y + 1),
      })
    }
  }

  protected get_scenario(): FixtureScenario {
    return this.scenario
  }

  protected on_fixture_ready(keeper: Keeper): void {
    if (this.instruction === 'enter') {
      const dome = Level.getDome(keeper.teamId)
      keeper.global_position = Vector2(
        dome.global_position.x + this.enterStart.x,
        dome.global_position.y + this.enterStart.y,
      )
      keeper.move = Vector2.ZERO
      keeper.moveDirectionInput = Vector2.ZERO

      return
    }

    keeper.global_position = Level.map.getTilePos(this.start)
    Level.viewports.getPlayerCam(keeper.playerId).global_position = keeper.global_position
    keeper.move = Vector2.ZERO
    keeper.moveDirectionInput = Vector2.ZERO
    if (this.instruction === 'drop') {
      for (let i = 0; i < this.fixture_drops.size(); i += 1) {
        const drop = this.fixture_drops[i]
        drop.global_position = Vector2(
          keeper.global_position.x + (i % 3 - 1) * 8,
          keeper.global_position.y + (floor(i / 3) - 1) * 8,
        )
        Level.drops.network_pickup(drop, keeper.playerId)
      }
    }
    if (this.instruction === 'activate') {
      const chamber = this.fixture_landmarks[0] as Chamber
      chamber.tileRevealed(chamber.coord)
      chamber.onExcavated()
    }
  }

  ready_for_task(): boolean {
    if (!this.fixture_ready)
      return false
    if (this.instruction === 'activate')
      return (this.fixture_landmarks[0] as Chamber).currentState === Chamber.State.OPEN
    return true
  }

  watch_task(executorNode: Node): void {
    const executor = executorNode as _TaskExecutor
    this.task_failure = ''
    this.task_finished = false
    executor.task_completed.connect(this._task_completed)
    executor.task_failed.connect(this._task_failed)
  }

  task(): Task {
    if (this.instruction === 'enter')
      return new _EnterMineTask()
    if (this.instruction === 'activate') {
      const task = new _ActivateGadgetChamber()
      task.initialize(this.fixture_landmarks[0] as Chamber)
      return task
    }
    if (this.instruction === 'drop') {
      const task = new _DropByType()
      task.initialize(this.resource)
      return task
    }
    const task = new _PickupTargetTask()
    task.initialize(this.fixture_drops[0])
    return task
  }

  private _task_completed(): void {
    this.task_finished = true
  }

  private _task_failed(reason: string): void {
    this.task_failure = reason
    this.task_finished = true
  }
}
