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

export interface FixtureDrop {
  position: Vector2i
  type: typeof CONST.IRON | typeof CONST.SAND | typeof CONST.WATER | typeof CONST.RELIC
}

export interface FixtureLandmark {
  position: Vector2i
  type: typeof Data.TILE_GADGET
}

interface DropSpawnData {
  position: Vector2
  team: string
  type: FixtureDrop['type']
}

export interface FixtureScenario {
  drops: FixtureDrop[]
  landmarks: FixtureLandmark[]
  map: {
    left_top: Vector2i
    bottom_right: Vector2i
    map_data: MapTile[]
  }
}

export class _Fixture extends Node {
  fixture_ready = false
  fixture_drops: Drop[] = []
  fixture_landmarks: Node2D[] = []
  startup_error = ''
  test_name = ''
  test_map_selected = false

  private landingSkipped = false

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

    if (OS.has_feature('movie')) {
      if (!this._write_movie_options())
        return

      const label = new Label()
      label.text = this.test_name
      label.set_anchors_and_offsets_preset(
        Control.PRESET_BOTTOM_RIGHT,
        Control.PRESET_MODE_MINSIZE,
        16,
      )
      label.add_theme_font_size_override('font_size', 24)
      label.add_theme_color_override('font_shadow_color', Color.BLACK)
      label.add_theme_constant_override('shadow_offset_x', 2)
      label.add_theme_constant_override('shadow_offset_y', 2)
      const overlay = new CanvasLayer()
      overlay.layer = 100
      overlay.add_child(label)
      this.add_child(overlay)
    }

    const game = this.get_tree().get_first_node_in_group('vidot-persistent-game')
    if (game === null) {
      const newGame = gameScene.instantiate() as Node & Game
      newGame.devMode = false
      newGame.add_to_group('vidot-persistent-game')
      this.get_tree().root.add_child(newGame)
    }
    else if (StageManager.isInLevel()) {
      Network.restart_run()
    }
    else {
      this._fail('The previous fixture did not reach a Level that can be restarted')

      return
    }

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
      this._fail('The fixture could not find the local Keeper')

      return
    }

    if (!this._spawn_fixture_landmarks())
      return

    if (!this._spawn_fixture_drops(keeper))
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
      drops: [],
      landmarks: [],
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

  private _spawn_fixture_drops(keeper: Keeper): boolean {
    const map = Level.map
    const drops = Level.drops
    if (map === null || drops === null) {
      this._fail('The fixture could not spawn its Drops before the level was ready')

      return false
    }

    for (const entry of this.get_scenario().drops) {
      const data: DropSpawnData = {
        position: map.getTilePos(entry.position),
        team: keeper.teamId,
        type: entry.type,
      }
      const carryable = drops.local_spawn(data as Dictionary)
      if (!(carryable instanceof Drop)) {
        this._fail('The fixture could not spawn a Drop')

        return false
      }

      this.fixture_drops.append(gd.as(carryable, Drop))
    }

    return true
  }

  private _spawn_fixture_landmarks(): boolean {
    const map = Level.map
    const landmarks = this.get_scenario().landmarks
    if (landmarks.is_empty() || !this.fixture_landmarks.is_empty())
      return true

    for (const entry of landmarks) {
      const scene = map.getSceneForTileType(entry.type)
      const landmark = scene === null
        ? null
        : map.addChamber(Vector2(entry.position.x, entry.position.y), scene)
      if (!(landmark instanceof Node2D)) {
        this._fail(`Fixture could not place a landmark at ${entry.position}`)

        return false
      }

      this.fixture_landmarks.append(landmark)
    }

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

    for (let mapY = scenarioMap.left_top.y - 1; mapY <= scenarioMap.bottom_right.y + 1; mapY += 1) {
      for (let mapX = scenarioMap.left_top.x - 1; mapX <= scenarioMap.bottom_right.x + 1; mapX += 1) {
        const cell = Vector2i(mapX, mapY)
        const position = Vector2(mapX, mapY)
        const isBoundary = mapX === scenarioMap.left_top.x - 1
          || mapX === scenarioMap.bottom_right.x + 1
          || mapY === scenarioMap.left_top.y - 1
          || mapY === scenarioMap.bottom_right.y + 1

        map.set_biomev(cell, 0)
        if (isBoundary) {
          map.set_hardnessv(position, Data.HARDNESS_INDESTRUCTIBLE)
          map.set_resourcev(position, Data.TILE_BORDER)
        }
        else {
          map.set_hardnessv(position, verySoft)
          map.set_resourcev(position, dirt)
        }
      }
    }

    for (const entry of scenarioMap.map_data)
      map.set_resourcev(Vector2(entry.position.x, entry.position.y), entry.type)

    levelStartData.tileData = map
    this.test_map_selected = true
  }
}
