import type { FixtureScenario } from '@vikeeper/vitest'
import type { _TaskExecutor } from '../../src/task_executor.ts'
import { _Fixture } from '@vikeeper/vitest'

export class _MoveTest extends _Fixture {
  move_start = Vector2i(-1, 0)
  move_target = Vector2i(1, 1)
  task_failure = ''
  task_finished = false

  private scenario: FixtureScenario = {
    drops: [],
    landmarks: [],
    map: {
      map_data: [
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
      bottom_right: Vector2i(2, 2),
    },
    keeper_position: this.move_start,
  }

  protected get_scenario(): FixtureScenario {
    return this.scenario
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

  private _task_completed(): void {
    this.task_finished = true
  }

  private _task_failed(reason: string): void {
    this.task_failure = reason
    this.task_finished = true
  }
}
