export interface PrimitiveTask extends RefCounted {
  is_complete: (current: Vector2i) => boolean
  resolve_action: (current: Vector2i) => string
}

export class _TaskExecutor extends RefCounted {
  private binding: InputEventKey | null = null
  private heldAction = ''
  private task: PrimitiveTask | null = null

  start(task: PrimitiveTask, current: Vector2i): string {
    this.task = task
    return this._apply(task.resolve_action(current))
  }

  step(current: Vector2i): string {
    const task = this.task
    if (task === null)
      return 'TaskExecutor has no active task'

    return this._apply(task.resolve_action(current))
  }

  is_complete(current: Vector2i): boolean {
    const task = this.task
    return task !== null && task.is_complete(current)
  }

  cancel(): void {
    this.task = null
    this._release()
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
