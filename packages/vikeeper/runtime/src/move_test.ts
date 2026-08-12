export class _MoveTest extends Node {
  test_map_selected = false
  private landingSkipped = false

  _ready(): void {
    if (!OS.has_feature('editor')) {
      this._fail('The Move test requires the Dome Keeper Editor')

      return
    }

    const editorConfig = gd.eval<Resource | null>('load("res://addons/dome_editor_ext/dome_editor_conf.tres")')
    const gameScene = gd.eval<PackedScene | null>('load("res://game/Game.tscn")')
    if (editorConfig === null || gameScene === null) {
      this._fail('The Move test could not load the editor configuration or game scene')

      return
    }

    editorConfig.set('custom_play_pressed', true)
    editorConfig.set('play_mode', 0)
    editorConfig.set('nmb_of_players', 0)
    editorConfig.set('p1_keeper', 'keeper1')
    editorConfig.set('p1_dome', 0)
    editorConfig.set('p1_primaryGadgetid', 'shield')
    editorConfig.set('game_mode', 0)
    editorConfig.set('multiplayer_mode', 0)
    gd.eval('StageManager.stage_started.connect(self._load_test_map)')

    if (OS.has_feature('movie') && !this._write_movie_options())
      return

    const game = gameScene.instantiate()
    game.set('devMode', false)
    this.add_child(game)

    if (OS.has_feature('movie')) {
      const window = this.get_window()
      if (window.mode !== Window.MODE_WINDOWED || window.borderless)
        this._fail('Movie mode requires a decorated window')
    }
  }

  _process(_delta: float): void {
    if (this.landingSkipped)
      return

    const landingReady = gd.eval<boolean>('StageManager.currentStage is LandingStage and StageManager.currentStage.allClientsReady()')
    if (!landingReady)
      return

    this.landingSkipped = true
    const event = new InputEventKey()
    const keycode = gd.eval<int>('KEY_ENTER')
    event.keycode = keycode
    event.pressed = true
    Input.parse_input_event(event)
    const release = gd.as(event.duplicate(), InputEventKey)
    release.pressed = false
    Input.parse_input_event(release)
    this.set_process(false)
  }

  private _write_movie_options(): boolean {
    const options = FileAccess.open('user://options.txt', FileAccess.WRITE)
    if (options === null) {
      this._fail('The Move test could not configure its isolated movie window')

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
    gd.eval('StageManager.stage_started.disconnect(self._load_test_map)')
    const mapScene = gd.eval<PackedScene | null>('load("res://content/map/MapData.tscn")')
    const levelStartData = gd.eval<Resource | null>('StageManager.currentStage.levelStartData')
    if (mapScene === null || levelStartData === null) {
      this._fail('The Move test could not create the official MapData')

      return
    }

    const map = mapScene.instantiate()
    const border = gd.eval<number>('Data.TILE_BORDER')
    const indestructible = gd.eval<number>('Data.HARDNESS_INDESTRUCTIBLE')
    const verySoft = gd.eval<number>('Data.HARDNESS_VERY_SOFT')
    for (let y = -2; y <= 4; y += 1) {
      for (let x = -3; x <= 3; x += 1) {
        const cell = Vector2i(x, y)
        const isBorder = x === -3 || x === 3 || y === 4 || (y === -2 && x !== 0)
        map.call('set_biomev', cell, 0)
        map.call('set_hardnessv', cell, isBorder ? indestructible : verySoft)
        if (isBorder)
          map.call('set_resourcev', cell, border)
      }
    }

    levelStartData.set('tileData', map)
    this.test_map_selected = true
  }

  private _fail(reason: string): void {
    push_error(reason)
    this.get_tree().quit(1)
  }
}
