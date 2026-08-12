export class _MoveQuarkAction extends RefCounted {
  static resolve(currentX: int, currentY: int, targetX: int, targetY: int): string {
    if (currentX < targetX)
      return 'ui_right'
    if (currentX > targetX)
      return 'ui_left'
    if (currentY < targetY)
      return 'ui_down'
    if (currentY > targetY)
      return 'ui_up'

    return ''
  }
}
