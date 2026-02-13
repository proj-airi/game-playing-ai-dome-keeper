extends "res://stages/title/TitleStage.gd"

const MESSAGE := "YOLODataCollector Installed!"


func build(data: Array) -> void:
	super(data)

	var canvas: Node = get_node_or_null("Canvas")
	if canvas == null:
		print("Canvas is null")
		return

	if canvas.get_node_or_null("YoloDataCollectorLabel") != null:
		print("YoloDataCollectorLabel already exists")
		return

	print("Creating YoloDataCollectorLabel")
	var label := Label.new()
	label.name = "YoloDataCollectorLabel"
	label.text = MESSAGE
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = 16.0
	label.offset_top = 16.0
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var version_container: Node = get_node_or_null("Canvas/VersionContainer")
	if version_container != null:
		label.theme = version_container.theme

	canvas.add_child(label)
