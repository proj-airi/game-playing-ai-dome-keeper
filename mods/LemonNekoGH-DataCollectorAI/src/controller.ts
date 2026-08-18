import { _TaskExecutor } from './task_executor.ts'
import { _MoveToTask } from './tasks/move_to_task.ts'

export class _DataCollectorAI extends Node {
  move_to_ready = false
  task_completed = gd.signal()
  task_failed = gd.signal<[reason: string]>()

  private executor: _TaskExecutor | null = null
  private keeper: Keeper | null = null
  private lastError = ''

  _ready(): void {
    this.process_mode = Node.PROCESS_MODE_ALWAYS
    this.set_physics_process(false)
    print('DATA_COLLECTOR_AI_READY')
  }

  _process(_delta: float): void {
    if (this.executor === null)
      this.move_to_ready = this._level_ready()
  }

  _physics_process(_delta: float): void {
    if (this.executor === null)
      return
    const keeper = this.keeper
    if (keeper === null || !is_instance_valid(keeper)) {
      this._finish_failed('Keeper was freed during MoveTo')

      return
    }

    const tile = this._tile(keeper)
    if (this.executor.is_complete(tile)) {
      this.executor.cancel()
      this._clear_task()
      this.task_completed.emit()

      return
    }

    const error = this.executor.step(tile)
    if (error !== '')
      this._finish_failed(error)
  }

  start_move_to(target: Vector2i): boolean {
    if (this.executor !== null)
      return this._reject('Another task is already active')
    if (!this._level_ready())
      return this._reject('MoveTo requires one active local keyboard Engineer in a loaded level')

    const keeper = Keepers.local.first()
    if (!is_instance_valid(keeper))
      return this._reject('The local Keeper is unavailable')

    const tile = this._tile(keeper)
    const task = new _MoveToTask()
    task.initialize(target)
    const executor = new _TaskExecutor()
    const error = executor.start(task, tile)
    if (error !== '') {
      executor.cancel()

      return this._reject(error)
    }

    this.executor = executor
    this.keeper = keeper
    this.lastError = ''
    this.move_to_ready = false
    this.set_physics_process(true)

    return true
  }

  current_tile(): Vector2i {
    if (!this._level_ready()) {
      push_error('MoveTo current_tile requires one active local keyboard Engineer in a loaded level')

      return Vector2i.ZERO
    }

    const keeper = Keepers.local.first()
    if (!is_instance_valid(keeper)) {
      push_error('MoveTo current_tile could not access the local Keeper')

      return Vector2i.ZERO
    }

    return this._tile(keeper)
  }

  get_last_error(): string {
    return this.lastError
  }

  reset(): void {
    if (this.executor !== null)
      this.executor.cancel()
    this._clear_task()
    this.lastError = ''
  }

  _exit_tree(): void {
    this.reset()
  }

  private _clear_task(): void {
    this.set_physics_process(false)
    this.executor = null
    this.keeper = null
    this.move_to_ready = false
  }

  private _finish_failed(reason: string): void {
    if (this.executor !== null)
      this.executor.cancel()
    this._clear_task()
    this.lastError = reason
    this.task_failed.emit(reason)
  }

  private _level_ready(): boolean {
    const levelStage = Level.stage as LevelStage | null

    return StageManager.isInLevel()
      && Level.initialized
      && Level.map !== null
      && levelStage !== null
      && levelStage.keeperInputStarted
      && Keepers.local.getCount() === 1
      && Keepers.local.first().techId === 'keeper1'
      && !Options.useGamepad(Keepers.local.first().deviceId)
  }

  private _reject(reason: string): boolean {
    this.lastError = reason

    return false
  }

  private _tile(keeper: Keeper): Vector2i {
    const tile: Vector2i = Level.map.getTileCoord(keeper.global_position)
    return tile
  }
}
