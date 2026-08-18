export class _MoveQuarkAction extends RefCounted {
  static resolve(current: Vector2i, target: Vector2i): string {
    if (current.x < target.x)
      return 'ui_right'
    if (current.x > target.x)
      return 'ui_left'
    if (current.y < target.y)
      return 'ui_down'
    if (current.y > target.y)
      return 'ui_up'

    return ''
  }
}
