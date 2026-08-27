export class _PickupQuarkAction extends RefCounted {
  static resolve(keeper: Keeper, target: Carryable): string {
    return keeper.focussedCarryable === target ? 'keeper1_pickup' : ''
  }
}
