import type { _DataCollectorAI } from '../../src/controller'

interface MapTile {
  type: typeof Data.TILE_EMPTY
  | typeof Data.TILE_GADGET
  | typeof Data.TILE_IRON
  | typeof Data.TILE_SAND
  | typeof Data.TILE_WATER
  | typeof Data.TILE_RELIC
  | typeof Data.TILE_SUPPLEMENT
  | typeof Data.TILE_RELIC_SWITCH
  | typeof Data.TILE_DIRT_START
  position: Vector2i
}

interface Map {
  left_top: Vector2i
  bottom_right: Vector2i
  map_data: MapTile[]
}

interface Scenario {
  keeper_position: Vector2i
  map: Map
}

export class _MoveTest extends Node {
  keeper_positioned = false
  move_start = Vector2i(-1, 0)
  move_target = Vector2i(1, 1)
  startup_error = ''
  task_failure = ''
  task_finished = false
  test_map_selected = false
  private landingSkipped = false
  private positioningStarted = false

  private scenario: Scenario = {
    map: {
      map_data: [
        { type: Data.TILE_EMPTY, position: Vector2i(0, -2) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, -1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 0) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 1) },
        { type: Data.TILE_EMPTY, position: Vector2i(-2, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(-1, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(0, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(1, 2) },
        { type: Data.TILE_EMPTY, position: Vector2i(2, 2) },
      ],
      left_top: Vector2i(-2, -2),
      bottom_right: Vector2i(2, 2),
    },
    keeper_position: Vector2i(0, 0),
  }

  _ready(): void {
    this.process_mode = Node.PROCESS_MODE_ALWAYS
    if (!OS.has_feature('editor')) {
      this._fail('The Move test requires the Dome Keeper Editor')

      return
    }

    const editorConfig = load<DomeEditorConf>('res://addons/dome_editor_ext/dome_editor_conf.tres') as DomeEditorConf | null
    const gameScene = load<PackedScene<Node>>('res://game/Game.tscn') as PackedScene<Node> | null
    if (editorConfig === null || gameScene === null) {
      this._fail('The Move test could not load the editor configuration or game scene')

      return
    }

    editorConfig.custom_play_pressed = true
    editorConfig.play_mode = CONST.ENTER_PLAY_MODE.Level
    editorConfig.nmb_of_players = CONST.ENTER_PLAYERS_NMB.ONE_PLAYER
    editorConfig.p1_keeper = 'keeper1'
    editorConfig.p1_dome = CONST.ENTER_DOME.DOME_1
    editorConfig.p1_primaryGadgetid = 'shield'
    editorConfig.game_mode = CONST.ENTER_GAME_MODE.RELIC
    editorConfig.multiplayer_mode = CONST.DEV_ENTER_MULTIPLAYER_MODE.SINGLE
    StageManager.stage_started.connect(this._load_test_map)

    if (OS.has_feature('movie') && !this._write_movie_options())
      return

    const game = gameScene.instantiate() as Node & Game
    game.devMode = false
    this.add_child(game)

    if (OS.has_feature('movie')) {
      const window = this.get_window()
      if (window.mode !== Window.MODE_WINDOWED || window.borderless)
        this._fail('Movie mode requires a decorated window')

      DisplayServer.window_move_to_foreground()
    }
  }

  _process(_delta: float): void {
    if (this.startup_error !== '' || this.keeper_positioned)
      return

    if (!this.landingSkipped) {
      const stage = StageManager.currentStage as LandingStage | null
      const landingReady = StageManager.isInLanding() && stage !== null && stage.allClientsReady()
      if (!landingReady)
        return

      this.landingSkipped = true
      const event = new InputEventKey()
      event.keycode = Key.KEY_ENTER
      event.pressed = true
      Input.parse_input_event(event)
      const release = gd.as(event.duplicate(), InputEventKey)
      release.pressed = false
      Input.parse_input_event(release)

      return
    }

    const levelStage = Level.stage as LevelStage | null
    const map = Level.map
    const levelReady = StageManager.isInLevel()
      && Level.initialized
      && map !== null
      && levelStage !== null
      && levelStage.keeperInputStarted
      && Keepers.local.getCount() === 1
    if (!levelReady)
      return

    const keeper = Keepers.local.first()
    if (!is_instance_valid(keeper)) {
      this._fail('The MoveTo test could not position the local Keeper')

      return
    }

    if (!this.positioningStarted) {
      this.positioningStarted = true
      keeper.global_position = map.getTilePos(this.move_start)
      keeper.move = Vector2.ZERO
      keeper.moveDirectionInput = Vector2.ZERO

      return
    }

    const current: Vector2i = map.getTileCoord(keeper.global_position)
    if (current.x !== this.move_start.x || current.y !== this.move_start.y)
      return

    this.keeper_positioned = true
    this.set_process(false)
  }

  _exit_tree(): void {
    const connected = StageManager.stage_started.is_connected(this._load_test_map)
    if (connected)
      StageManager.stage_started.disconnect(this._load_test_map)
  }

  watch_task(controllerNode: Node): void {
    const controller = controllerNode as _DataCollectorAI
    this.task_failure = ''
    this.task_finished = false
    const watchingCompletion = controller.task_completed.is_connected(this._task_completed)
    if (watchingCompletion)
      controller.task_completed.disconnect(this._task_completed)
    const watchingFailure = controller.task_failed.is_connected(this._task_failed)
    if (watchingFailure)
      controller.task_failed.disconnect(this._task_failed)
    controller.task_completed.connect(this._task_completed)
    controller.task_failed.connect(this._task_failed)
  }

  private _task_completed(): void {
    this.task_finished = true
  }

  private _task_failed(reason: string): void {
    this.task_failure = reason
    this.task_finished = true
  }

  private _write_movie_options(): boolean {
    const options = FileAccess.open('user://options.txt', FileAccess.WRITE)
    if (options === null) {
      this._fail('The Move test could not configure its movie window')

      return false
    }

    options.store_string(JSON.stringify({
      borderless: false,
      fullscreen: false,
      pauseWhenOutOfFocus: false,
      vsync: false,
    }))
    options.close()

    return true
  }

  private _load_test_map(): void {
    StageManager.stage_started.disconnect(this._load_test_map)
    const mapScene = load<PackedScene<MapData>>('res://content/map/MapData.tscn') as PackedScene<MapData> | null
    const stage = StageManager.currentStage as LandingStage | null
    const levelStartData = stage === null ? null : stage.levelStartData
    if (mapScene === null || levelStartData === null) {
      this._fail('The Move test could not create the official MapData')

      return
    }

    const map = mapScene.instantiate()
    const dirt = Data.TILE_DIRT_START
    const verySoft = Data.HARDNESS_VERY_SOFT

    for (let y = this.scenario.map.left_top.y; y <= this.scenario.map.bottom_right.y; y += 1) {
      for (let x = this.scenario.map.left_top.x; x <= this.scenario.map.bottom_right.x; x += 1) {
        const cell = Vector2i(x, y)
        const position = Vector2(x, y)

        map.set_biomev(cell, 0)
        map.set_hardnessv(position, verySoft)
        map.set_resourcev(position, dirt)
      }
    }

    for (const entry of this.scenario.map.map_data)
      map.set_resourcev(Vector2(entry.position.x, entry.position.y), entry.type)

    levelStartData.tileData = map
    this.test_map_selected = true
  }

  private _fail(reason: string): void {
    if (this.startup_error !== '')
      return

    this.startup_error = reason
    this.set_process(false)
    push_error(reason)
  }
}
