extends Node

const MOD_DIR := "LemonNekoGH-YoloDataCollector"
const LOG_NAME := "LemonNekoGH-YoloDataCollector:Main"

var mod_dir_path := ""
var extensions_dir_path := ""


func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)

	install_script_extensions()


func install_script_extensions() -> void:
	extensions_dir_path = mod_dir_path.path_join("extensions")
	ModLoaderMod.install_script_extension(
		extensions_dir_path.path_join("stages/title/TitleStage.gd")
	)


func _ready() -> void:
	ModLoaderLog.info("Ready", LOG_NAME)
