export interface Task extends RefCounted {
  failure: (keeper: Keeper) => string
  is_complete: (keeper: Keeper, current: Vector2i) => boolean
}

export interface PrimitiveTask extends Task {
  resolve_action: (keeper: Keeper, current: Vector2i) => string
}

export interface CompoundTask extends Task {
  begin: (keeper: Keeper, current: Vector2i) => string
  resolve_method: (keeper: Keeper, current: Vector2i) => Task[]
}

export class _CompoundTask extends RefCounted {
  begin(_keeper: Keeper, _current: Vector2i): string {
    return ''
  }

  failure(_keeper: Keeper): string {
    return ''
  }

  is_complete(_keeper: Keeper, _current: Vector2i): boolean {
    return true
  }

  resolve_method(_keeper: Keeper, _current: Vector2i): Task[] {
    return []
  }
}
