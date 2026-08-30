import type { FixtureScenario } from '@vikeeper/vitest'
import type { _TaskExecutor } from '../../src/task_executor.ts'
import { _Fixture } from '@vikeeper/vitest'

export class _DropByTypeTest extends _Fixture {
  drop_presses = 0
  drop_releases = 0
  expected_position = Vector2i(1, 0)
  keeper_start = Vector2i(0, 0)
  released_drops: Drop[] = []
  task_failure = ''
  task_finished = false
  wrong_position = Vector2i(3, 0)

  private scenario: FixtureScenario = {
    drops: [
      { position: this.wrong_position, type: CONST.SAND },
      { position: this.expected_position, type: CONST.IRON },
    ],
    landmarks: [],
    map: {
      map_data: [
        { type: Data.TILE_EMPTY, position: Vector2i(-1, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(3, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(4, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(3, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(4, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(3, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(4, 1) },
      ],
      left_top: Vector2i(-1, -1),
      bottom_right: Vector2i(4, 1),
    },
  }

  protected get_scenario(): FixtureScenario {
    return this.scenario
  }

  protected on_fixture_ready(keeper: Keeper): void {
    keeper.global_position = Level.map.getTilePos(this.keeper_start)
    keeper.move = Vector2.ZERO
    keeper.moveDirectionInput = Vector2.ZERO

    for (const drop of this.fixture_drops)
      Level.drops.network_pickup(drop, keeper.playerId)
  }

  _input(event: InputEvent): void {
    if (!this.fixture_ready || !(event instanceof InputEventKey) || event.echo)
      return
    if (!InputMap.event_is_action(event, 'keeper1_drop'))
      return

    if (event.pressed)
      this.drop_presses += 1
    else
      this.drop_releases += 1
  }

  watch_task(executorNode: Node): void {
    const executor = executorNode as _TaskExecutor
    this.task_failure = ''
    this.task_finished = false
    executor.task_completed.connect(this._task_completed)
    executor.task_failed.connect(this._task_failed)
  }

  _physics_process(_delta: float): void {
    if (!this.fixture_ready)
      return

    const keeper = Keepers.local.first()
    if (!is_instance_valid(keeper))
      return

    for (const drop of this.fixture_drops) {
      if (!drop.isCarriedBy(keeper) && !this.released_drops.has(drop))
        this.released_drops.append(drop)
    }
  }

  private _task_completed(): void {
    this.task_finished = true
  }

  private _task_failed(reason: string): void {
    this.task_failure = reason
    this.task_finished = true
  }
}
