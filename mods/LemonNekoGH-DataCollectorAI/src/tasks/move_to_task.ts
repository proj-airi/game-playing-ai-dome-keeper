import { _MoveQuarkAction } from '../quark_actions/move_quark_action.ts'

export class _MoveToTask extends RefCounted {
  private target = Vector2i.ZERO

  initialize(target: Vector2i): void {
    this.target = target
  }

  failure(_keeper: Keeper): string {
    return ''
  }

  is_complete(_keeper: Keeper, current: Vector2i): boolean {
    return current.x === this.target.x && current.y === this.target.y
  }

  resolve_action(_keeper: Keeper, current: Vector2i): string {
    return _MoveQuarkAction.resolve(current, this.target)
  }
}
