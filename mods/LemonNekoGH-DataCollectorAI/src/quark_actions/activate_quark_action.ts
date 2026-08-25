export class _ActivateQuarkAction extends RefCounted {
  static resolve(keeper: Keeper, target: Node2D): string {
    if (!is_instance_valid(target))
      return ''

    return keeper.focussedUsable === target ? 'ui_select' : ''
  }
}
