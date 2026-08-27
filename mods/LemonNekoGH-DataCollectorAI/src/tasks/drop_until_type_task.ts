import { _DropQuarkAction } from '../quark_actions/drop_quark_action.ts'

export class _DropUntilTypeTask extends RefCounted {
  private carriedBefore: Carryable[] = []
  private error = ''
  private expectedType = ''
  private initialized = false
  private phase = _DropUntilTypeTask.State.Ready

  initialize(expectedType: string): void {
    this.carriedBefore.clear()
    this.error = ''
    this.expectedType = expectedType
    this.initialized = true
    this.phase = _DropUntilTypeTask.State.Ready
  }

  failure(keeper: Keeper): string {
    if (!this.initialized)
      return 'DropUntilTypeTask requires an expected Drop type'
    if (this.error !== '')
      return this.error
    if (this.phase === _DropUntilTypeTask.State.Ready && !this._carries_expected_type(keeper))
      return `Keeper does not carry a Drop of type: ${this.expectedType}`

    return ''
  }

  is_complete(keeper: Keeper, _current: Vector2i): boolean {
    if (this.phase === _DropUntilTypeTask.State.AwaitingDetach)
      this._observe_detached(keeper)

    return this.phase === _DropUntilTypeTask.State.Complete
  }

  resolve_action(keeper: Keeper, _current: Vector2i): string {
    if (this.phase === _DropUntilTypeTask.State.Ready) {
      this._snapshot_carried_cargo(keeper)
      this.phase = _DropUntilTypeTask.State.Pressed

      return _DropQuarkAction.resolve()
    }

    if (this.phase === _DropUntilTypeTask.State.Pressed) {
      this.phase = _DropUntilTypeTask.State.AwaitingDetach

      return ''
    }

    return ''
  }

  private _carries_expected_type(keeper: Keeper): boolean {
    for (const candidate of keeper.carriedCarryables) {
      if (candidate instanceof Drop && candidate.type === this.expectedType)
        return true
    }

    return false
  }

  private _observe_detached(keeper: Keeper): void {
    let detached = false
    for (const candidate of this.carriedBefore) {
      if (!is_instance_valid(candidate)) {
        this.error = 'A carried object was freed while resolving Drop input'

        return
      }
      if (keeper.carriedCarryables.has(candidate))
        continue

      detached = true
      if (candidate instanceof Drop && candidate.type === this.expectedType) {
        this.carriedBefore.clear()
        this.phase = _DropUntilTypeTask.State.Complete

        return
      }
    }
    if (!detached)
      return

    this.carriedBefore.clear()
    this.phase = _DropUntilTypeTask.State.Ready
  }

  private _snapshot_carried_cargo(keeper: Keeper): void {
    this.carriedBefore.clear()
    for (const candidate of keeper.carriedCarryables) {
      if (candidate instanceof Carryable)
        this.carriedBefore.append(candidate)
    }
  }
}

// eslint-disable-next-line ts/no-namespace
export namespace _DropUntilTypeTask {
  export enum State {
    Ready,
    Pressed,
    AwaitingDetach,
    Complete,
  }
}
