import { _ActivateQuarkAction } from '../quark_actions/activate_quark_action.ts'
import { _MoveQuarkAction } from '../quark_actions/move_quark_action.ts'

export class _ActivateUsable extends RefCounted {
  private activated = false
  private target: Node2D | null = null

  initialize(target: Node2D): void {
    this.target = target
  }

  failure(_keeper: Keeper): string {
    const target = this.target
    if (target === null || !is_instance_valid(target))
      return 'Usable target was freed before activation'

    return ''
  }

  is_complete(_keeper: Keeper, _current: Vector2i): boolean {
    return this.activated
  }

  resolve_action(keeper: Keeper, current: Vector2i): string {
    const target = this.target
    if (target === null || !is_instance_valid(target))
      return ''

    const action = _ActivateQuarkAction.resolve(keeper, target)
    if (action !== '') {
      this.activated = true

      return action
    }

    const targetTile: Vector2i = Level.map.getTileCoord(target.global_position)
    const tileAction = _MoveQuarkAction.resolve(current, targetTile)
    if (tileAction !== '')
      return tileAction

    return _MoveQuarkAction.resolve_position(keeper.global_position, target.global_position)
  }
}
