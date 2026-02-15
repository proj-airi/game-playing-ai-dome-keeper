extends "res://content/pause/PauseMenu.gd"

var yolo_button: Button


func _ready() -> void:
	super()
	# Use a group marker on the visible panel so the collector can detect it without relying on paths.
	var menu_panel := get_node_or_null("MenuPanel")
	if menu_panel != null:
		menu_panel.add_to_group("yolo_pause_menu")
	_setup_yolo_button()


func _exit_tree() -> void:
	var menu_panel := get_node_or_null("MenuPanel")
	if menu_panel != null:
		menu_panel.remove_from_group("yolo_pause_menu")


func _setup_yolo_button() -> void:
	var menu := get_node_or_null("MenuPanel/VBoxContainer")
	if menu == null:
		return

	yolo_button = Button.new()
	yolo_button.name = "ButtonYoloCollect"
	yolo_button.focus_neighbor_right = NodePath("../../../BippinbitsBox/VBoxContainer/ButtonDiscord")
	yolo_button.text = _yolo_button_text()
	var menu_panel := get_node_or_null("MenuPanel")
	if menu_panel != null:
		yolo_button.theme = menu_panel.theme
	menu.add_child(yolo_button)
	yolo_button.pressed.connect(_toggle_yolo_collection)


func _toggle_yolo_collection() -> void:
	var collector = _get_collector()
	if collector == null:
		return

	if collector.is_collecting():
		collector.stop_collection()
	else:
		collector.start_collection()

	if yolo_button:
		yolo_button.text = _yolo_button_text()


func _yolo_button_text() -> String:
	var collector = _get_collector()
	return "Stop YOLO Data Collection" if collector != null and collector.is_collecting() else "Start YOLO Data Collection"


func _get_collector() -> Node:
	return get_tree().get_root().get_node_or_null("YoloDataCollector")
