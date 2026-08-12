interface TaskExecutorContract extends RefCounted {
  cancel: () => void
  is_complete: (currentX: int, currentY: int) => boolean
  start: (currentX: int, currentY: int, targetX: int, targetY: int) => string
  step: (delta: float) => string
}

export class _DataCollectorAI extends Node {
  move_ready = false
  task_completed = gd.signal()
  task_failed = gd.signal<[reason: string]>()

  private executor: TaskExecutorContract | null = null
  private keeper: Node2D | null = null
  private lastError = ''

  _ready(): void {
    this.process_mode = Node.PROCESS_MODE_ALWAYS
    this.set_physics_process(false)
    print('DATA_COLLECTOR_AI_READY')
  }

  _process(_delta: float): void {
    if (this.executor === null)
      this.move_ready = this._level_ready()
  }

  _physics_process(delta: float): void {
    if (this.executor === null)
      return
    const keeper = this.keeper
    if (keeper === null || !is_instance_valid(keeper)) {
      this._finish_failed('Keeper was freed during Move')

      return
    }

    const tile = this._tile(keeper)
    if (this.executor.is_complete(tile.x, tile.y)) {
      this.executor.cancel()
      this._clear_task()
      this.task_completed.emit()

      return
    }

    const error = this.executor.step(delta)
    if (error !== '')
      this._finish_failed(error)
  }

  start_move(targetX: int, targetY: int): boolean {
    if (this.executor !== null)
      return this._reject('Another task is already active')
    if (!this._level_ready())
      return this._reject('Move requires one active local keyboard Engineer in a loaded level')

    const keeper = gd.eval<Node2D>('Keepers.local.first()')
    if (!is_instance_valid(keeper))
      return this._reject('The local Keeper is unavailable')

    const tile = this._tile(keeper)
    const executor = gd.eval<TaskExecutorContract>('preload("res://mods-unpacked/LemonNekoGH-DataCollectorAI/task_executor.gd").new()')
    const error = executor.start(tile.x, tile.y, targetX, targetY)
    if (error !== '')
      return this._reject(error)

    this.executor = executor
    this.keeper = keeper
    this.lastError = ''
    this.move_ready = false
    this.set_physics_process(true)

    return true
  }

  current_tile(): int[] {
    if (!this._level_ready())
      return []

    const keeper = gd.eval<Node2D>('Keepers.local.first()')
    if (!is_instance_valid(keeper))
      return []

    const tile = this._tile(keeper)
    return [tile.x, tile.y]
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
    this.move_ready = false
  }

  private _finish_failed(reason: string): void {
    if (this.executor !== null)
      this.executor.cancel()
    this._clear_task()
    this.lastError = reason
    this.task_failed.emit(reason)
  }

  private _level_ready(): boolean {
    const ready = gd.eval<boolean>('StageManager.isInLevel() and Level.initialized and Level.map != null and Level.stage.keeperInputStarted and Keepers.local.getCount() == 1 and Keepers.local.first().techId == "keeper1" and not Options.useGamepad(Keepers.local.first().deviceId)')
    return ready
  }

  private _reject(reason: string): boolean {
    this.lastError = reason

    return false
  }

  private _tile(_keeper: Node2D): Vector2i {
    const tile = gd.eval<Vector2i>('Level.map.getTileCoord(_keeper.global_position)')
    return tile
  }
}
