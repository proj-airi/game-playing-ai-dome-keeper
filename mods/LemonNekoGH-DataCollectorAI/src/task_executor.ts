export class _TaskExecutor extends RefCounted {
  private elapsed: float = 0
  private binding: InputEventKey | null = null
  private targetX: int = 0
  private targetY: int = 0

  start(currentX: int, currentY: int, targetX: int, targetY: int): string {
    if (absi(targetX - currentX) + absi(targetY - currentY) !== 1)
      return 'Move requires one adjacent target tile'

    const action = gd.eval<string>('preload("res://mods-unpacked/LemonNekoGH-DataCollectorAI/quark_actions/move_quark_action.gd").resolve(currentX, currentY, targetX, targetY)')
    const binding = this._binding(action)
    if (binding === null)
      return `Missing keyboard binding for action: ${action}`

    this.binding = binding
    this.targetX = targetX
    this.targetY = targetY
    this.elapsed = 0
    this._dispatch(binding, true)

    return ''
  }

  step(delta: float): string {
    this.elapsed += delta
    if (this.elapsed >= 3)
      return 'Move did not reach the target tile within 3 seconds'

    return ''
  }

  is_complete(currentX: int, currentY: int): boolean {
    return currentX === this.targetX && currentY === this.targetY
  }

  cancel(): void {
    const binding = this.binding
    if (binding === null)
      return

    this.binding = null
    this._dispatch(binding, false)
  }

  private _dispatch(binding: InputEventKey, pressed: boolean): void {
    const event = gd.as(binding.duplicate(), InputEventKey)
    event.pressed = pressed
    gd.eval('InputSystem.game_not_in_focus = false')
    Input.parse_input_event(event)
    gd.eval('InputSystem.game_not_in_focus = not DisplayServer.window_is_focused()')
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
