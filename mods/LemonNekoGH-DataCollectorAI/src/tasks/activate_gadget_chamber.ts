import type { CompoundTask, Task } from './task.ts'
import { _ActivateUsable } from './activate_usable.ts'
import { _CompoundTask } from './task.ts'

export class _ActivateGadgetChamber extends _CompoundTask implements CompoundTask {
  private chamber: Chamber | null = null
  private usable: Node2D | null = null

  initialize(chamber: Chamber): void {
    this.chamber = chamber
  }

  begin(_keeper: Keeper, _current: Vector2i): string {
    const chamber = this.chamber
    if (chamber === null || !is_instance_valid(chamber))
      return 'ActivateGadgetChamber requires an active Gadget Chamber'
    if (chamber.currentState !== Chamber.State.OPEN)
      return 'ActivateGadgetChamber requires an open Gadget Chamber'
    if (chamber.drop_type !== CONST.GADGET)
      return 'ActivateGadgetChamber requires a Chamber containing a Gadget'

    const usable = chamber.get_node_or_null('Usable') as Node2D | null
    if (usable === null || !is_instance_valid(usable))
      return 'Open Gadget Chamber did not expose its Usable'

    this.usable = usable

    return ''
  }

  failure(_keeper: Keeper): string {
    if (this.chamber === null || !is_instance_valid(this.chamber))
      return 'Gadget Chamber was freed during activation'

    return ''
  }

  is_complete(keeper: Keeper, _current: Vector2i): boolean {
    const chamber = this.chamber
    if (chamber === null || !is_instance_valid(chamber) || chamber.currentState !== Chamber.State.EMPTY)
      return false

    for (const candidate of keeper.carriedCarryables) {
      if (candidate instanceof Drop && candidate.type === CONST.GADGET)
        return true
    }

    return false
  }

  resolve_method(_keeper: Keeper, _current: Vector2i): Task[] {
    const usable = this.usable
    if (usable === null)
      return []

    const activate = new _ActivateUsable()
    activate.initialize(usable)

    return [activate]
  }
}
