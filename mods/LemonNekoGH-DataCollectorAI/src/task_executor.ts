export class _TaskExecutor extends RefCounted {
  private action = ''
  private targetX: int = 0
  private targetY: int = 0

  start(currentX: int, currentY: int, targetX: int, targetY: int): string {
    if (absi(targetX - currentX) + absi(targetY - currentY) !== 1)
      return 'Move requires one adjacent target tile'

    this.targetX = targetX
    this.targetY = targetY
    return this.step(currentX, currentY)
  }

  step(currentX: int, currentY: int): string {
    if (currentX === this.targetX && currentY === this.targetY) {
      this._hold('')

      return ''
    }

    const action = gd.eval<string>('preload("res://mods-unpacked/LemonNekoGH-DataCollectorAI/quark_actions/move_quark_action.gd").resolve(currentX, currentY, self.targetX, self.targetY)')
    if (!this._hold(action))
      return `Missing keyboard binding for action: ${action}`

    return ''
  }

  is_complete(currentX: int, currentY: int): boolean {
    return currentX === this.targetX && currentY === this.targetY
  }

  cancel(): void {
    this._hold('')
  }

  private _hold(action: string): boolean {
    if (action === this.action)
      return true
    if (this.action !== '')
      this._emit(this.action, false)
    if (action === '') {
      this.action = action

      return true
    }

    const event = this._binding(action)
    if (event === null) {
      this.action = ''

      return false
    }

    event.pressed = true
    gd.eval('InputSystem.game_not_in_focus = false')
    Input.parse_input_event(event)
    this.action = action

    return true
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

  private _emit(action: string, pressed: boolean): void {
    const event = this._binding(action)
    if (event === null)
      return

    event.pressed = pressed
    gd.eval('InputSystem.game_not_in_focus = false')
    Input.parse_input_event(event)
  }
}
