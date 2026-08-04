extends Node

const MOD_DIR := "LemonNekoGH-YoloDataCollector"
const LOG_NAME := "LemonNekoGH-YoloDataCollector:Main"
const GAME_SCENE_PATH := "res://game/Game.tscn"
const GAME_SCRIPT_PATH := "res://game/Game.gd"
const CHECKPOINT_LOAD_ARG := "--airi-checkpoint-load="
const LEVEL_SEED_ARG := "--airi-level-seed="

var mod_dir_path := ""
var extensions_dir_path := ""
var collector: Node
var teacher: Node
var launch_config: DomeEditorConf


func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
	ModLoaderMod.extend_scene(GAME_SCENE_PATH, _configure_direct_normal_run)
	install_script_extensions()


func _configure_direct_normal_run(scene: Node) -> Node:
	var loading := false
	var level_seed := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(CHECKPOINT_LOAD_ARG):
			loading = true
		elif argument.begins_with(LEVEL_SEED_ARG):
			level_seed = argument.trim_prefix(LEVEL_SEED_ARG)
	if not OS.has_feature("editor"):
		return scene
	if FileAccess.file_exists("user://dev-mode"):
		ModLoaderLog.error(
			"Cannot start a normal run while user://dev-mode exists",
			LOG_NAME
		)
		return null

	var scene_script_value: Variant = scene.get_script()
	if not scene_script_value is Script:
		ModLoaderLog.error("Game scene does not have a valid script", LOG_NAME)
		return null
	var scene_script: Script = scene_script_value
	if scene_script.resource_path != GAME_SCRIPT_PATH:
		ModLoaderLog.error("Game scene no longer uses the expected script", LOG_NAME)
		return null
	var config_resource: Resource = load(Const.EDITOR_CONF_PATH)
	if not config_resource is DomeEditorConf:
		ModLoaderLog.error("Dome editor configuration has an unexpected type", LOG_NAME)
		return null
	launch_config = config_resource

	launch_config.custom_play_pressed = true
	launch_config.play_mode = (
		Const.ENTER_PLAY_MODE.Title
		if loading
		else Const.ENTER_PLAY_MODE.Level
	)
	scene.set(&"devMode", false)
	if not level_seed.is_empty():
		if not level_seed.is_valid_int():
			ModLoaderLog.error("Invalid level seed: " + level_seed, LOG_NAME)
			return null
		var seed_setter = load(mod_dir_path.path_join("level_seed.gd")).new()
		seed_setter.level_seed = int(level_seed)
		scene.add_child(seed_setter)
		seed_setter.owner = scene
	ModLoaderLog.info("Configured a direct level launch with normal run rules", LOG_NAME)
	return scene


func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.path_join("extensions")
	ModLoaderMod.install_script_extension(
		extensions_dir_path.path_join("game/GameWorld.gd")
	)
	ModLoaderMod.install_script_extension(
		extensions_dir_path.path_join("content/techtree/TechTreePopup.gd")
	)
	ModLoaderMod.install_script_extension(
		extensions_dir_path.path_join("systems/options/Options.gd")
	)


func _ready() -> void:
	ModLoaderLog.info("Ready", LOG_NAME)
	if collector == null:
		var collector_path = mod_dir_path.path_join("yolo_collector.gd")
		var teacher_path = mod_dir_path.path_join("rule_teacher.gd")
		var collector_script = load(collector_path)
		var teacher_script = load(teacher_path)
		if collector_script == null:
			ModLoaderLog.error("Failed to load collector script: " + collector_path, LOG_NAME)
			return
		if teacher_script == null:
			ModLoaderLog.error("Failed to load teacher script: " + teacher_path, LOG_NAME)
			return
		collector = collector_script.new()
		teacher = teacher_script.new()
		collector.call(&"set_teacher", teacher)
		collector.add_child(teacher)
		get_tree().get_root().call_deferred("add_child", collector)
