export class _AimLaserQuarkAction extends RefCounted {
  static resolve(weapon: LaserWeapon, target: Monster): string {
    const center = target.getCenter()
    const aim = Vector2(
      center.x - weapon.global_position.x,
      center.y - weapon.global_position.y,
    )
    const forward = Vector2.UP.rotated(weapon.rotation)
    let error = forward.angle_to(aim)

    if (aim.x < 0.0 && error > CONST.PI_HALF)
      error -= CONST.PI_HALF * 4.0
    else if (aim.x > 0.0 && error < -CONST.PI_HALF)
      error += CONST.PI_HALF * 4.0

    if (error > 0.0)
      return 'ui_right'
    if (error < 0.0)
      return 'ui_left'

    return ''
  }
}
