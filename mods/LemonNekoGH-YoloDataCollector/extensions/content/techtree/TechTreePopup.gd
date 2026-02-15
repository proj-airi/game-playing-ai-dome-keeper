extends "res://content/techtree/TechTreePopup.gd"


func _ready() -> void:
	super()
	# Mark upgrade popup as a capture-blocking overlay.
	add_to_group("yolo_pause_menu")


func _exit_tree() -> void:
	remove_from_group("yolo_pause_menu")
