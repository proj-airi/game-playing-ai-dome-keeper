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

  static resolve_position(current: Vector2, target: Vector2): string {
    const delta = Vector2(target.x - current.x, target.y - current.y)
    if (delta.length_squared() <= 16.0)
      return ''
    if (absf(delta.x) > absf(delta.y))
      return delta.x > 0.0 ? 'ui_right' : 'ui_left'

    return delta.y > 0.0 ? 'ui_down' : 'ui_up'
  }
}
