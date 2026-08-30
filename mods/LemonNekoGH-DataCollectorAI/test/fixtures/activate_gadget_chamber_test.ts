import type { FixtureScenario } from '@vikeeper/vitest'
import type { _TaskExecutor } from '../../src/task_executor.ts'
import { _Fixture } from '@vikeeper/vitest'

export class _ActivateGadgetChamberTest extends _Fixture {
  chamber_ready = false
  chamber_position = Vector2i(1, 0)
  keeper_start = Vector2i(-2, 0)
  target_was_focussed = false
  task_failure = ''
  task_finished = false

  private scenario: FixtureScenario = {
    drops: [],
    landmarks: [
      { position: this.chamber_position, type: Data.TILE_GADGET },
    ],
    map: {
      map_data: [
        { type: Data.TILE_EMPTY, position: Vector2i(-2, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(3, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(3, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(3, 1) },
      ],
      left_top: Vector2i(-2, -1),
      bottom_right: Vector2i(3, 1),
    },
  }

  protected get_scenario(): FixtureScenario {
    return this.scenario
  }

  protected on_fixture_ready(keeper: Keeper): void {
    keeper.global_position = Level.map.getTilePos(this.keeper_start)
    keeper.move = Vector2.ZERO
    keeper.moveDirectionInput = Vector2.ZERO

    const chamber = this.fixture_landmarks[0] as Chamber
    chamber.tileRevealed(chamber.coord)
    chamber.onExcavated()
  }

  watch_task(executorNode: Node): void {
    const executor = executorNode as _TaskExecutor
    this.task_failure = ''
    this.task_finished = false
    executor.task_completed.connect(this._task_completed)
    executor.task_failed.connect(this._task_failed)
  }

  _physics_process(_delta: float): void {
    if (this.fixture_landmarks.is_empty())
      return

    const chamber = this.fixture_landmarks[0] as Chamber
    if (chamber.currentState === Chamber.State.OPEN)
      this.chamber_ready = true

    const usable = chamber.get_node_or_null('Usable')
    const keeper = Keepers.local.first()
    if (usable !== null && is_instance_valid(keeper) && keeper.focussedUsable === usable)
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
