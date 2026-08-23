import { _MoveQuarkAction } from '../quark_actions/move_quark_action.ts'
import { _PickupQuarkAction } from '../quark_actions/pickup_quark_action.ts'

export class _PickupTargetTask extends RefCounted {
  private target: Drop | null = null

  initialize(target: Drop): void {
    this.target = target
  }

  failure(keeper: Keeper): string {
    const target = this.target
    if (target === null || !is_instance_valid(target))
      return 'Pickup target was freed'
    if (target.absorbed)
      return 'Pickup target was absorbed'
    if (target.independent)
      return 'Pickup target became independent'
    if (target.isCarried() && !target.isCarriedBy(keeper))
      return 'Pickup target was carried by another actor'

    return ''
  }

  is_complete(keeper: Keeper, _current: Vector2i): boolean {
    const target = this.target
    if (target === null)
      return false

    return keeper.carriedCarryables.has(target)
  }

  resolve_action(keeper: Keeper, current: Vector2i): string {
    const target = this.target
    if (target === null)
      return ''
    const pickup = _PickupQuarkAction.resolve(keeper, target)
    if (pickup !== '')
      return pickup

    const targetTile: Vector2i = Level.map.getTileCoord(target.global_position)
    return _MoveQuarkAction.resolve(current, targetTile)
  }
}
