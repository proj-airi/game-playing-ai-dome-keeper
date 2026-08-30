import type { FixtureScenario } from '@vikeeper/vitest'
import type { _TaskExecutor } from '../../src/task_executor.ts'
import { _Fixture } from '@vikeeper/vitest'

export class _PickupTest extends _Fixture {
  pickup_start = Vector2i(-1, 0)
  pickup_target_position = Vector2i(1, 0)
  target_was_focussed = false
  task_failure = ''
  task_finished = false

  private scenario: FixtureScenario = {
    drops: [
      { position: this.pickup_target_position, type: CONST.IRON },
    ],
    landmarks: [],
    map: {
      map_data: [
        { type: Data.TILE_EMPTY, position: Vector2i(-2, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 0) },
      ],
      left_top: Vector2i(-2, -1),
      bottom_right: Vector2i(2, 1),
    },
  }

  protected get_scenario(): FixtureScenario {
    return this.scenario
  }

  protected on_fixture_ready(keeper: Keeper): void {
    keeper.global_position = Level.map.getTilePos(this.pickup_start)
    keeper.move = Vector2.ZERO
    keeper.moveDirectionInput = Vector2.ZERO
  }

  watch_task(executorNode: Node): void {
    const executor = executorNode as _TaskExecutor
    this.task_failure = ''
    this.task_finished = false
    const watchingCompletion = executor.task_completed.is_connected(this._task_completed)
    if (watchingCompletion)
      executor.task_completed.disconnect(this._task_completed)
    const watchingFailure = executor.task_failed.is_connected(this._task_failed)
    if (watchingFailure)
      executor.task_failed.disconnect(this._task_failed)
    executor.task_completed.connect(this._task_completed)
    executor.task_failed.connect(this._task_failed)
  }

  _physics_process(_delta: float): void {
    if (this.fixture_drops.is_empty())
      return

    const target = this.fixture_drops[0]
    const keeper = Keepers.local.first()
    if (is_instance_valid(keeper) && keeper.focussedCarryable === target)
      this.target_was_focussed = true
  }

  private _task_completed(): void {
    this.task_finished = true
  }

  private _task_failed(reason: string): void {
    this.task_failure = reason
    this.task_finished = true
  }
}
