export interface PrimitiveTask extends RefCounted {
  failure: (keeper: Keeper) => string
  is_complete: (keeper: Keeper, current: Vector2i) => boolean
  resolve_action: (keeper: Keeper, current: Vector2i) => string
}

export class _TaskExecutor extends Node {
  task_completed = gd.signal()
  task_failed = gd.signal<[reason: string]>()

  private binding: InputEventKey | null = null
  private heldAction = ''
  private keeper: Keeper | null = null
  private task: PrimitiveTask | null = null

  _ready(): void {
    this.process_mode = Node.PROCESS_MODE_ALWAYS
    this.set_physics_process(false)
  }

  _physics_process(_delta: float): void {
    const error = this._step()
    if (error !== '')
      this._finish_failed(error)
  }

  _exit_tree(): void {
    this.cancel()
  }

  start(keeper: Keeper, task: PrimitiveTask): string {
    if (this.task !== null)
      return 'TaskExecutor already has an active task'
    if (!is_instance_valid(keeper))
      return 'TaskExecutor requires an active Keeper'

    this.task = task
    this.keeper = keeper
    const error = this._step()
    if (error !== '') {
      this.cancel()

      return error
    }

    this.set_physics_process(this.task !== null)

    return ''
  }

  cancel(): void {
    this.set_physics_process(false)
    this.task = null
    this.keeper = null
    this._release()
  }

  private _step(): string {
    const keeper = this.keeper
    const task = this.task
    if (keeper === null || !is_instance_valid(keeper))
      return 'Keeper was freed during task execution'
    if (task === null)
      return 'TaskExecutor has no active task'
    if (Level.map === null)
      return 'TaskExecutor requires a loaded level map'

    const current: Vector2i = Level.map.getTileCoord(keeper.global_position)
    if (task.is_complete(keeper, current)) {
      this._finish_completed()

      return ''
    }

    const failure = task.failure(keeper)
    if (failure !== '')
      return failure

    return this._apply(task.resolve_action(keeper, current))
  }

  private _finish_completed(): void {
    this.cancel()
    this.task_completed.emit()
  }

  private _finish_failed(reason: string): void {
    this.cancel()
    this.task_failed.emit(reason)
  }

  private _apply(action: string): string {
    if (action === this.heldAction)
      return ''

    this._release()
    if (action === '')
      return ''

    const binding = this._binding(action)
    if (binding === null)
      return `Missing keyboard binding for action: ${action}`

    this.binding = binding
    this.heldAction = action
    this._dispatch(binding, true)

    return ''
  }

  private _release(): void {
    const binding = this.binding
    this.binding = null
    this.heldAction = ''
    if (binding === null)
      return

    this._dispatch(binding, false)
  }

  private _dispatch(binding: InputEventKey, pressed: boolean): void {
    const event = gd.as(binding.duplicate(), InputEventKey)
    event.pressed = pressed
    InputSystem.game_not_in_focus = false
    Input.parse_input_event(event)
    InputSystem.game_not_in_focus = !DisplayServer.window_is_focused()
  }

  private _binding(action: string): InputEventKey | null {
    for (const event of InputMap.action_get_events(action)) {
      if (!(event instanceof InputEventKey))
        continue

      const binding = gd.as(event.duplicate(), InputEventKey)
      binding.device = 0
      binding.echo = false

      return binding
    }

    return null
  }
}
