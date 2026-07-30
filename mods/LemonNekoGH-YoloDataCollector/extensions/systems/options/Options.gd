extends "res://systems/options/Options.gd"

const RECORDING_ARG := "--airi-recording-dir="


func updateWindowMode(force: bool = false) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(RECORDING_ARG):
			return
	super(force)


func updateVsync() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(RECORDING_ARG):
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			return
	super()
