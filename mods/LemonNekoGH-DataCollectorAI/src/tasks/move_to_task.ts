import { _MoveQuarkAction } from '../quark_actions/move_quark_action.ts'

export class _MoveToTask extends RefCounted {
  private target = Vector2i.ZERO

  initialize(target: Vector2i): void {
    this.target = target
  }

  is_complete(current: Vector2i): boolean {
    return current.x === this.target.x && current.y === this.target.y
  }

  resolve_action(_current: Vector2i): string {
    return _MoveQuarkAction.resolve(_current, this.target)
  }
}
