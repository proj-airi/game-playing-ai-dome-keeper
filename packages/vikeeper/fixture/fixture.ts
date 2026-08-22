export interface MapTile {
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

export interface FixtureScenario {
  keeper_position: Vector2i
  map: {
    left_top: Vector2i
    bottom_right: Vector2i
    map_data: MapTile[]
  }
}

export class _Fixture extends Node {
  fixture_ready = false
  startup_error = ''
  test_map_selected = false

  private landingSkipped = false
  private positioningStarted = false

  _ready(): void {
    this.process_mode = Node.PROCESS_MODE_ALWAYS
    if (!OS.has_feature('editor')) {
      this._fail('The fixture requires the Dome Keeper Editor')

      return
    }

    const editorConfig = load<DomeEditorConf>('res://addons/dome_editor_ext/dome_editor_conf.tres') as DomeEditorConf | null
    const gameScene = load<PackedScene<Node>>('res://game/Game.tscn') as PackedScene<Node> | null
    if (editorConfig === null || gameScene === null) {
      this._fail('The fixture could not load the editor configuration or game scene')

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
    if (this.startup_error !== '' || this.fixture_ready)
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
      this._fail('The fixture could not position the local Keeper')

      return
    }

    if (!this.positioningStarted) {
      this.positioningStarted = true
      keeper.global_position = map.getTilePos(this.get_scenario().keeper_position)
      keeper.move = Vector2.ZERO
      keeper.moveDirectionInput = Vector2.ZERO

      return
    }

    const current: Vector2i = map.getTileCoord(keeper.global_position)
    const keeperPosition = this.get_scenario().keeper_position
    const positioned = current.x === keeperPosition.x && current.y === keeperPosition.y
    if (!positioned)
      return

    this.on_fixture_ready(keeper)
    this.fixture_ready = true
    this.set_process(false)
  }

  _exit_tree(): void {
    const connected = StageManager.stage_started.is_connected(this._load_test_map)
    if (connected)
      StageManager.stage_started.disconnect(this._load_test_map)
  }

  protected get_scenario(): FixtureScenario {
    this._fail('The fixture must provide a scenario')

    return {
      keeper_position: Vector2i.ZERO,
      map: {
        map_data: [],
        left_top: Vector2i.ZERO,
        bottom_right: Vector2i.ZERO,
      },
    }
  }

  protected on_fixture_ready(_keeper: Keeper): void {}

  protected _fail(reason: string): void {
    if (this.startup_error !== '')
      return

    this.startup_error = reason
    this.set_process(false)
    push_error(reason)
  }

  private _write_movie_options(): boolean {
    const options = FileAccess.open('user://options.txt', FileAccess.WRITE)
    if (options === null) {
      this._fail('The fixture could not configure its movie window')

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
      this._fail('The fixture could not create the official MapData')

      return
    }

    const map = mapScene.instantiate()
    const dirt = Data.TILE_DIRT_START
    const verySoft = Data.HARDNESS_VERY_SOFT
    const scenarioMap = this.get_scenario().map

    for (let y = scenarioMap.left_top.y; y <= scenarioMap.bottom_right.y; y += 1) {
      for (let x = scenarioMap.left_top.x; x <= scenarioMap.bottom_right.x; x += 1) {
        const cell = Vector2i(x, y)
        const position = Vector2(x, y)

        map.set_biomev(cell, 0)
        map.set_hardnessv(position, verySoft)
        map.set_resourcev(position, dirt)
      }
    }

    for (const entry of scenarioMap.map_data)
      map.set_resourcev(Vector2(entry.position.x, entry.position.y), entry.type)

    levelStartData.tileData = map
    this.test_map_selected = true
  }
}
