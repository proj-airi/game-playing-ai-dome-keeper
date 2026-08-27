import type { CompoundTask, Task } from './task.ts'
import { _DropUntilTypeTask } from './drop_until_type_task.ts'
import { _PickupTargetTask } from './pickup_target_task.ts'
import { _CompoundTask } from './task.ts'

export class _DropByType extends _CompoundTask implements CompoundTask {
  private expectedType = ''
  private initialCargo: Carryable[] = []
  private initialized = false

  initialize(expectedType: string): void {
    this.expectedType = expectedType
    this.initialCargo.clear()
    this.initialized = true
  }

  begin(keeper: Keeper, _current: Vector2i): string {
    if (!this.initialized)
      return 'DropByType requires an expected Drop type'

    let hasExpectedType = false
    this.initialCargo.clear()
    for (const candidate of keeper.carriedCarryables) {
      if (!(candidate instanceof Carryable))
        continue

      this.initialCargo.append(candidate)
      if (candidate instanceof Drop && candidate.type === this.expectedType)
        hasExpectedType = true
    }

    return hasExpectedType
      ? ''
      : `Keeper does not carry a Drop of type: ${this.expectedType}`
  }

  failure(keeper: Keeper): string {
    for (const cargo of this.initialCargo) {
      if (!is_instance_valid(cargo))
        return 'An initially carried object was freed during DropByType'
    }
    if (!this._matches_final_cargo(keeper))
      return 'DropByType did not restore the initial cargo identities'

    return ''
  }

  is_complete(keeper: Keeper, _current: Vector2i): boolean {
    return this._matches_final_cargo(keeper)
  }

  resolve_method(_keeper: Keeper, _current: Vector2i): Task[] {
    const method: Task[] = []
    const drop = new _DropUntilTypeTask()
    drop.initialize(this.expectedType)
    method.append(drop)

    for (const initial of this.initialCargo) {
      if (initial instanceof Drop && initial.type === this.expectedType)
        continue

      const pickup = new _PickupTargetTask()
      pickup.initialize(initial)
      method.append(pickup)
    }

    return method
  }

  private _matches_final_cargo(keeper: Keeper): boolean {
    const currentCargo: Carryable[] = []
    for (const candidate of keeper.carriedCarryables) {
      if (candidate instanceof Carryable)
        currentCargo.append(candidate)
    }
    if (currentCargo.size() !== this.initialCargo.size() - 1)
      return false

    let missingExpected = 0
    for (const initial of this.initialCargo) {
      if (currentCargo.has(initial))
        continue
      if (!is_instance_valid(initial)
        || !(initial instanceof Drop)
        || initial.type !== this.expectedType) {
        return false
      }

      missingExpected += 1
    }
    if (missingExpected !== 1)
      return false

    for (const current of currentCargo) {
      if (!this.initialCargo.has(current))
        return false
    }

    return true
  }
}
