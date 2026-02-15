extends Node

const MOD_DIR := "LemonNekoGH-YoloDataCollector"
const LOG_NAME := "LemonNekoGH-YoloDataCollector:Main"

var mod_dir_path := ""
var extensions_dir_path := ""
var collector: Node


func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)

	install_script_extensions()


func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.path_join("extensions")
	ModLoaderMod.install_script_extension(
		extensions_dir_path.path_join("stages/title/TitleStage.gd")
	)
	ModLoaderMod.install_script_extension(
		extensions_dir_path.path_join("content/pause/PauseMenu.gd")
	)
	ModLoaderMod.install_script_extension(
		extensions_dir_path.path_join("content/techtree/TechTreePopup.gd")
	)


func _ready() -> void:
	ModLoaderLog.info("Ready", LOG_NAME)
	if collector == null:
		var script_path = mod_dir_path.path_join("yolo_collector.gd")
		var collector_script = load(script_path)
		if collector_script == null:
			ModLoaderLog.error("Failed to load collector script: " + script_path, LOG_NAME)
			return
		collector = collector_script.new()
		collector.name = "YoloDataCollector"
		get_tree().get_root().call_deferred("add_child", collector)
