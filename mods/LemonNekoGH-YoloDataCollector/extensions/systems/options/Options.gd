extends "res://systems/options/Options.gd"

const RECORDING_ARG := "--airi-recording-dir="


func loadOptions() -> void:
	super()
	if _recording_requested():
		pauseWhenOutOfFocus = false


func updateWindowMode(force: bool = false) -> void:
	if _recording_requested():
		return
	super(force)


func updateVsync() -> void:
	if _recording_requested():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		return
	super()


func _recording_requested() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(RECORDING_ARG):
			return true
	return false
