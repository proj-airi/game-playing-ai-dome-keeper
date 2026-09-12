import { _MoveQuarkAction } from '../quark_actions/move_quark_action.ts'

// ADR-0006: this task covers only the bounded dome-to-mine transition.
export class _EnterMineTask extends RefCounted {
  failure(keeper: Keeper): string {
    if (keeper.isInsideStation)
      return 'EnterMineTask requires the Keeper outside a station'
    if (!is_instance_valid(Level.getDome(keeper.teamId)))
      return 'EnterMineTask requires the Keeper dome'

    return ''
  }

  is_complete(keeper: Keeper, _current: Vector2i): boolean {
    return !keeper.isInsideDome
  }

  resolve_action(keeper: Keeper, _current: Vector2i): string {
    const dome = Level.getDome(keeper.teamId)
    const horizontalDistance = dome.global_position.x - keeper.global_position.x
    if (absf(horizontalDistance) <= 8.0 && absf(keeper.move.x) > 2.0)
      return ''

    const waypoint = this._departureWaypoint(keeper, dome)
    if (waypoint === null)
      return ''

    return _MoveQuarkAction.resolve_position(keeper.global_position, waypoint)
  }

  private _departureWaypoint(keeper: Keeper, dome: Dome): any {
    const home = Vector2(
      dome.global_position.x + CONST.TILE_OFFSET.x,
      -GameWorld.TILE_SIZE + CONST.TILE_OFFSET.y,
    )
    const mapPoint = this._firstMapPoint(keeper, home)
    if (mapPoint === null)
      return null

    const shaftAtCurrentHeight = Vector2(dome.global_position.x, keeper.global_position.y)
    if (keeper.global_position.distance_squared_to(shaftAtCurrentHeight) > 16.0)
      return shaftAtCurrentHeight

    return mapPoint
  }

  private _firstMapPoint(keeper: Keeper, home: Vector2): any {
    for (const rawOffset of CONST.PATHFINDING_OFFSETS) {
      const offset = rawOffset as Vector2
      const from = Vector2(home.x + offset.x, home.y + offset.y)
      const path = Level.map.findPath(from, home, keeper.teamId)
      if (path !== null && !path.is_empty())
        return path[0] as Vector2
    }

    return null
  }
}
