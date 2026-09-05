import type { FixtureScenario } from '@vikeeper/vitest'
import { _Fixture } from '@vikeeper/vitest'

export class _AttackMonsterTest extends _Fixture {
  attack_ready = false
  laser: LaserWeapon | null = null
  monster: Monster | null = null
  monster_exited = false
  monster_killed = false
  station: DomeStation | null = null
  task_failure = ''
  task_finished = false

  private battleStarted = false
  private manager: Monsters | null = null
  private setupStarted = false
  private stage: LevelStage | null = null
  private scenario: FixtureScenario = {
    drops: [],
    landmarks: [],
    map: {
      bottom_right: Vector2i.ZERO,
      left_top: Vector2i.ZERO,
      map_data: [{ type: Data.TILE_EMPTY, position: Vector2i.ZERO }],
    },
  }

  protected get_scenario(): FixtureScenario {
    return this.scenario
  }

  protected on_fixture_ready(keeper: Keeper): void {
    if (!(Level.mode instanceof Relichunt)) {
      this._fail('Attack fixture requires Relic Hunt mode')

      return
    }

    const dome = Level.getDome(keeper.teamId)
    let station: DomeStation | null = null
    for (const candidateStation of dome.stations) {
      for (const weapon of candidateStation.getControlledWeapons()) {
        if (!(weapon instanceof LaserWeapon) || weapon.inverse)
          continue
        if (this.laser !== null) {
          this._fail('Attack fixture requires exactly one normal Laser')

          return
        }
        this.laser = weapon
        station = candidateStation
      }
    }

    const manager = Level.monstersByTeamId.get(keeper.teamId) as Monsters | null
    const stage = Level.stage as LevelStage | null
    if (this.laser === null || station === null || manager === null || stage === null) {
      this._fail('Attack fixture could not find its Laser, monster manager, or Level')

      return
    }
    if (!is_instance_valid(manager) || !is_instance_valid(stage)) {
      this._fail('Attack fixture found invalid Level nodes')

      return
    }
    if (manager.disabled || !manager.monstersInWave.is_empty()) {
      this._fail('Attack fixture requires an enabled, empty monster manager')

      return
    }

    this.manager = manager
    this.stage = stage
    this.station = station
    Level.mode.runWeightOverride = 19.1
    Data.apply(`${keeper.teamId}.monsters.waveStrengthModifier`, 1.0)
    GameWorld.runStarted = true
    manager.spawnWave()
    if (manager.spawnPlan.size() !== 1) {
      this._fail(`Attack fixture generated ${manager.spawnPlan.size()} planned monsters instead of one`)

      return
    }

    this.setupStarted = true
  }

  _physics_process(_delta: float): void {
    const manager = this.manager
    const laser = this.laser
    const stage = this.stage
    const station = this.station
    if (this.startup_error !== '' || !this.setupStarted || this.attack_ready)
      return
    if (manager === null || laser === null || stage === null || station === null)
      return

    const keeper = Keepers.local.first()
    if (!is_instance_valid(keeper)) {
      this._fail('Attack fixture lost its Keeper during setup')

      return
    }
    if (manager.monstersInWave.size() > 1) {
      this._fail('Attack fixture spawned more than one monster')

      return
    }
    if (this.monster === null) {
      if (manager.monstersInWave.size() !== 1)
        return

      const monster = manager.monstersInWave[0]
      if (!(monster instanceof Monster)) {
        this._fail('Attack fixture did not spawn a Monster')

        return
      }

      this.monster = monster
      monster.died.connect(this._monster_died)
      if (OS.has_feature('movie'))
        monster.tree_exited.connect(this._monster_exited)
      station.synchronizer.stationAuthorityApproved(keeper.playerId)

      return
    }

    if (!keeper.isInsideStation || station.keeperInStation !== keeper)
      return
    if (!this.battleStarted) {
      if (!GameWorld.paused)
        return

      stage.startBattleInput(keeper, station)
      this.battleStarted = true

      return
    }

    if (!laser.started || !laser.inputReady)
      return

    this.attack_ready = true
    this.set_physics_process(false)
  }

  _task_completed(): void {
    this.task_finished = true
  }

  _task_failed(reason: string): void {
    this.task_failure = reason
    this.task_finished = true
  }

  private _monster_exited(): void {
    this.monster_exited = true
  }

  private _monster_died(): void {
    this.monster_killed = true
  }
}
