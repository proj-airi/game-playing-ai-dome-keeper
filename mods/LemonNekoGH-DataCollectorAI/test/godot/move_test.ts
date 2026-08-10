export class _MoveTest extends Node {
  test_map_selected = false

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

    const game = gameScene.instantiate()
    game.set('devMode', false)
    this.add_child(game)
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
