import { _AimLaserQuarkAction } from '../quark_actions/aim_laser_quark_action.ts'
import { _FireLaserQuarkAction } from '../quark_actions/fire_laser_quark_action.ts'

export class _AttackMonsterTask extends RefCounted {
  private target: Monster | null = null
  private targetWasAlive = false
  private weapon: LaserWeapon | null = null

  initialize(weapon: LaserWeapon, target: Monster): void {
    this.weapon = weapon
    this.target = target
    this.targetWasAlive = false
  }

  failure(_keeper: Keeper): string {
    const weapon = this.weapon
    if (weapon === null || !is_instance_valid(weapon))
      return 'AttackMonsterTask requires an active Laser'
    if (!weapon.started || !weapon.inputReady)
      return 'AttackMonsterTask requires ready Laser battle input'

    const target = this.target
    if (target === null || !is_instance_valid(target))
      return 'Attack target was freed before it was observed alive'
    if (!target.alive() || target.dead)
      return 'Attack target was already dead'
    if (target.leaving)
      return 'Attack target left the battle'

    return ''
  }

  is_complete(_keeper: Keeper, _current: Vector2i): boolean {
    const target = this.target
    if (target === null)
      return false
    if (!is_instance_valid(target))
      return this.targetWasAlive
    if (target.alive() && !target.dead) {
      this.targetWasAlive = true

      return false
    }

    return this.targetWasAlive
  }

  resolve_action(_keeper: Keeper, _current: Vector2i): string {
    const target = this.target
    const weapon = this.weapon
    if (target === null || weapon === null)
      return ''

    const collider = this._first_collider(weapon)
    if (collider === target) {
      if (target.canBeHit() && !target.invulnerable)
        return _FireLaserQuarkAction.resolve()

      return ''
    }

    return _AimLaserQuarkAction.resolve(weapon, target)
  }

  private _first_collider(weapon: LaserWeapon): Node | null {
    for (const candidate of weapon.raycasts) {
      if (!(candidate instanceof RayCast2D) || !candidate.enabled)
        continue

      const collider = candidate.get_collider() as Node | null
      if (collider !== null)
        return collider
    }

    return null
  }
}
