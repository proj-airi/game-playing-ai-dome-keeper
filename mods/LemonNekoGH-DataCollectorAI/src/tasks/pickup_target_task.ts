import { _MoveQuarkAction } from '../quark_actions/move_quark_action.ts'
import { _PickupQuarkAction } from '../quark_actions/pickup_quark_action.ts'

export class _PickupTargetTask extends RefCounted {
  private target: Carryable | null = null

  initialize(target: Carryable): void {
    this.target = target
  }

  failure(_keeper: Keeper): string {
    const target = this.target
    if (target === null || !is_instance_valid(target))
      return 'Pickup target was freed'
    if (target instanceof Drop && target.absorbed)
      return 'Pickup target was absorbed'
    if (target.independent)
      return 'Pickup target became independent'

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
