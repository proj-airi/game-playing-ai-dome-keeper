extends Node

const CAPTURE_INTERVAL := 0.5
const OUTPUT_DIR := "user://yolo_data"
const TARGET_SIZE := Vector2i(640, 640)
const PAD_COLOR := Color(0.447, 0.447, 0.447, 1.0)
const IMAGES_PER_SEGMENT := 60
const SEGMENT_CYCLE := 6
const TRAIN_SEGMENTS := 4
const TARGETS_PER_NO_TARGET := 5

enum RecordingLifecycle { MANUAL, WAITING_FOR_RUN, ACTIVE, STOPPING }

const CLASS_PLAYER := 0
const CLASS_DOME := 1
const CLASS_IRON := 2
const CLASS_COBALT := 3
const CLASS_WATER := 4
const CLASS_ENEMY := 5
const DATASET_NAMES := [
	"player_engineer",
	"dome_laser",
	"ore_iron",
	"ore_cobalt",
	"ore_water",
	"enemy",
]

var collection_active := false
var yolo_capture_active := false
var yolo_timer: Timer
var capture_index := 0
var session_dir := ""
var targets_since_no_target := 0
var capture_size_logged := false
var teacher: Node
var recording_lifecycle := RecordingLifecycle.MANUAL

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ModLoaderLog.debug("YOLO Data Collector Node Initiated!", "YOLO Data Collector")


func _ready() -> void:
	if teacher != null and bool(teacher.call(&"is_recording_configured")):
		recording_lifecycle = RecordingLifecycle.WAITING_FOR_RUN


func _process(_delta: float) -> void:
	if recording_lifecycle != RecordingLifecycle.WAITING_FOR_RUN:
		return
	if not is_instance_valid(StageManager.currentStage):
		return
	if not StageManager.currentStage is LandingStage and not StageManager.currentStage is LevelStage:
		recording_lifecycle = RecordingLifecycle.STOPPING
		push_error(
			"Recording startup reached unsupported stage: "
			+ str(StageManager.currentStage.name)
		)
		get_tree().quit(1)
		return
	if not _recording_run_ready():
		return
	if start_collection():
		recording_lifecycle = RecordingLifecycle.ACTIVE
		return
	recording_lifecycle = RecordingLifecycle.STOPPING
	get_tree().quit(1)

func _enter_tree() -> void:
	ModLoaderLog.debug("Collector entered tree. Inside: " + str(is_inside_tree()), "YOLO Data Collector")
	get_tree().node_added.connect(_on_tree_node_added)


func _exit_tree() -> void:
	if teacher != null:
		teacher.call(&"stop")
	if get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	ModLoaderLog.debug("Collector exited tree.", "YOLO Data Collector")


func _on_tree_node_added(node: Node) -> void:
	if node.name != &"PauseMenu":
		return
	if teacher != null and bool(teacher.call(&"is_recording_configured")):
		return

	var menu_panel := node.get_node_or_null("MenuPanel")
	var menu := node.get_node_or_null("MenuPanel/VBoxContainer")
	if menu_panel == null or menu == null:
		return

	menu_panel.add_to_group("yolo_pause_menu")
	call_deferred("_add_pause_menu_button", node)


func _add_pause_menu_button(pause_menu: Node) -> void:
	if not is_instance_valid(pause_menu):
		return

	var menu_panel := pause_menu.get_node_or_null("MenuPanel")
	var menu := pause_menu.get_node_or_null("MenuPanel/VBoxContainer")
	if menu_panel == null or menu == null:
		return
	if menu.get_node_or_null("ButtonYoloCollect") != null:
		return

	var button := Button.new()
	button.name = "ButtonYoloCollect"
	button.add_to_group("yolo_collection_button")
	button.text = _collection_button_text()
	button.theme = menu_panel.theme
	button.focus_neighbor_right = NodePath(
		"../../../BippinbitsBox/VBoxContainer/ButtonDiscord"
	)
	menu.add_child(button)
	button.pressed.connect(_on_collection_button_pressed.bind(button))


func _on_collection_button_pressed(button: Button) -> void:
	if collection_active:
		stop_collection()
	else:
		start_collection()

	if is_instance_valid(button):
		button.text = _collection_button_text()


func _collection_button_text() -> String:
	if collection_active:
		return "Stop Teacher Collection"
	return "Start Teacher Collection"


func set_teacher(value: Node) -> void:
	teacher = value
	teacher.connect(&"failed", _on_teacher_failed)
	teacher.connect(&"recording_finished", _on_recording_finished)


func start_collection() -> bool:
	if collection_active:
		return true
	if teacher != null and not bool(teacher.call(&"start")):
		return false
	collection_active = true
	if teacher != null and bool(teacher.call(&"is_recording_configured")):
		return true
	yolo_capture_active = true
	_start_new_session()
	if yolo_timer == null:
		yolo_timer = Timer.new()
		yolo_timer.wait_time = CAPTURE_INTERVAL
		yolo_timer.one_shot = false
		add_child(yolo_timer)
		yolo_timer.timeout.connect(_capture_frame)
	yolo_timer.start()
	_capture_frame()
	return true


func stop_collection() -> bool:
	var teacher_stopped := true
	if teacher != null:
		teacher_stopped = bool(teacher.call(&"stop"))
	if not collection_active:
		return teacher_stopped
	collection_active = false
	if yolo_timer:
		yolo_timer.stop()
	if not yolo_capture_active:
		return teacher_stopped
	yolo_capture_active = false
	_open_session_dir()
	return teacher_stopped


func _recording_run_ready() -> bool:
	return StageManager.isInLevel() and Level.initialized and bool(Level.stage.keeperInputStarted)


func _on_recording_finished() -> void:
	if recording_lifecycle != RecordingLifecycle.ACTIVE:
		return
	recording_lifecycle = RecordingLifecycle.STOPPING
	call_deferred("_finish_configured_recording")


func _finish_configured_recording() -> void:
	if stop_collection():
		get_tree().quit(0)


func _on_teacher_failed(_reason: String) -> void:
	var configured_recording := recording_lifecycle == RecordingLifecycle.ACTIVE
	var stopped := stop_collection()
	if configured_recording:
		recording_lifecycle = RecordingLifecycle.STOPPING
		if stopped:
			get_tree().quit(1)
	for button in get_tree().get_nodes_in_group("yolo_collection_button"):
		button.text = _collection_button_text()


func _start_new_session() -> void:
	capture_index = 0
	targets_since_no_target = 0
	capture_size_logged = false
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	session_dir = OUTPUT_DIR.path_join("session_" + timestamp)
	_ensure_split_dirs("images")
	_ensure_split_dirs("labels")
	_write_data_yaml()

func _capture_frame() -> void:
	if GameWorld.paused or _is_pause_menu_visible():
		return
	var viewport := get_viewport()
	if viewport == null:
		return

	var image := viewport.get_texture().get_image()
	if image == null:
		return

	var view_size = viewport.get_visible_rect().size
	var original_image_size = image.get_size()
	var view_to_image_scale = Vector2(
		original_image_size.x / max(view_size.x, 1.0),
		original_image_size.y / max(view_size.y, 1.0)
	)
	var letterbox_params = _letterbox_params(original_image_size, TARGET_SIZE)
	var scale: float = letterbox_params.scale
	var offset: Vector2 = letterbox_params.offset
	if not capture_size_logged:
		var texture_size = viewport.get_texture().get_size() if viewport.get_texture() != null else Vector2.ZERO
		ModLoaderLog.debug(
			"Capture sizes view=" + str(view_size)
			+ " texture=" + str(texture_size)
			+ " image=" + str(original_image_size)
			+ " view_to_image_scale=" + str(view_to_image_scale)
			+ " target=" + str(TARGET_SIZE)
			+ " scale=" + str(scale)
			+ " offset=" + str(offset),
			"YOLO Data Collector"
		)
		capture_size_logged = true

	var labels := _collect_labels(view_size, view_to_image_scale, scale, offset, Vector2(TARGET_SIZE))
	var has_target = _has_target_labels(labels)
	if not has_target and targets_since_no_target < TARGETS_PER_NO_TARGET:
		return

	var basename = "frame_%06d" % capture_index
	var split = _current_split()
	var images_dir = session_dir.path_join("images").path_join(split)
	var labels_dir = session_dir.path_join("labels").path_join(split)
	var image_path = images_dir.path_join(basename + ".png")
	var label_path = labels_dir.path_join(basename + ".txt")

	var letterbox = _letterbox_image(image, TARGET_SIZE)
	var output_image: Image = letterbox.image
	if output_image.save_png(image_path) != OK:
		return
	if not _save_labels(label_path, labels):
		DirAccess.remove_absolute(image_path)
		return
	targets_since_no_target = targets_since_no_target + 1 if has_target else 0
	capture_index += 1

func _letterbox_image(image: Image, target_size: Vector2i) -> Dictionary:
	var src_size = image.get_size()
	if src_size.x <= 0 or src_size.y <= 0:
		return {"image": image, "scale": 1.0, "offset": Vector2.ZERO}

	var scale = min(
		float(target_size.x) / float(src_size.x),
		float(target_size.y) / float(src_size.y)
	)
	var resized_w = int(round(float(src_size.x) * scale))
	var resized_h = int(round(float(src_size.y) * scale))
	var resized_size = Vector2i(resized_w, resized_h)

	image.resize(resized_size.x, resized_size.y, Image.INTERPOLATE_BILINEAR)

	var output = Image.create(target_size.x, target_size.y, false, image.get_format())
	output.fill(PAD_COLOR)

	var offset_x = int((target_size.x - resized_size.x) / 2)
	var offset_y = int((target_size.y - resized_size.y) / 2)
	var offset = Vector2(float(offset_x), float(offset_y))

	output.blit_rect(image, Rect2i(Vector2i.ZERO, resized_size), Vector2i(offset_x, offset_y))
	return {"image": output, "scale": scale, "offset": offset}


func _letterbox_params(src_size: Vector2i, target_size: Vector2i) -> Dictionary:
	if src_size.x <= 0 or src_size.y <= 0:
		return {"scale": 1.0, "offset": Vector2.ZERO}

	var scale = min(
		float(target_size.x) / float(src_size.x),
		float(target_size.y) / float(src_size.y)
	)
	var resized_w = int(round(float(src_size.x) * scale))
	var resized_h = int(round(float(src_size.y) * scale))
	var offset_x = int((target_size.x - resized_w) / 2)
	var offset_y = int((target_size.y - resized_h) / 2)
	return {"scale": scale, "offset": Vector2(float(offset_x), float(offset_y))}


func _current_split() -> String:
	var segment_index := capture_index / IMAGES_PER_SEGMENT
	var cycle_index = segment_index % SEGMENT_CYCLE
	if cycle_index < TRAIN_SEGMENTS:
		return "train"
	if cycle_index == TRAIN_SEGMENTS:
		return "val"
	return "test"


func _ensure_split_dirs(root_name: String) -> void:
	var root_dir = session_dir.path_join(root_name)
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("train"))
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("val"))
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("test"))


func _is_pause_menu_visible() -> bool:
	# UI overlay paths are unstable across versions, so we use a group marker instead.
	for node in get_tree().get_nodes_in_group("yolo_pause_menu"):
		if node is CanvasItem and node.is_visible_in_tree():
			return true
	return false


func _collect_labels(
	view_size: Vector2,
	view_to_image_scale: Vector2,
	scale: float,
	offset: Vector2,
	target_size: Vector2
) -> Array:
	var labels := []

	for keeper in Keepers.getAll():
		var rect = _rect_for_sprite(keeper)
		_append_label(labels, CLASS_PLAYER, rect, view_size, view_to_image_scale, scale, offset, target_size)

	for dome in Level.getDomes():
		var rect = _rect_for_sprite(dome)
		_append_label(labels, CLASS_DOME, rect, view_size, view_to_image_scale, scale, offset, target_size)

	for monster in get_tree().get_nodes_in_group("monster"):
		var rect = _rect_for_sprite(monster)
		_append_label(labels, CLASS_ENEMY, rect, view_size, view_to_image_scale, scale, offset, target_size)

	if Level.map and Level.map.tilesByType:
		for tile in Level.map.tilesByType.get(CONST.IRON, []):
			var rect = _rect_for_tile(tile)
			_append_label(labels, CLASS_IRON, rect, view_size, view_to_image_scale, scale, offset, target_size)
		for tile in Level.map.tilesByType.get(CONST.SAND, []):
			var rect = _rect_for_tile(tile)
			_append_label(labels, CLASS_COBALT, rect, view_size, view_to_image_scale, scale, offset, target_size)
		for tile in Level.map.tilesByType.get(CONST.WATER, []):
			var rect = _rect_for_tile(tile)
			_append_label(labels, CLASS_WATER, rect, view_size, view_to_image_scale, scale, offset, target_size)

	return labels


func _has_target_labels(labels: Array) -> bool:
	for item in labels:
		var class_id = item[0]
		if class_id == CLASS_ENEMY or class_id == CLASS_IRON or class_id == CLASS_COBALT or class_id == CLASS_WATER:
			return true
	return false


func _append_label(
	labels: Array,
	class_id: int,
	rect: Rect2,
	view_size: Vector2,
	view_to_image_scale: Vector2,
	scale: float,
	offset: Vector2,
	target_size: Vector2
) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1:
		return

	var x_min = clamp(rect.position.x, 0.0, view_size.x)
	var y_min = clamp(rect.position.y, 0.0, view_size.y)
	var x_max = clamp(rect.position.x + rect.size.x, 0.0, view_size.x)
	var y_max = clamp(rect.position.y + rect.size.y, 0.0, view_size.y)

	# Convert from view (logical) coordinates to image pixel coordinates.
	x_min *= view_to_image_scale.x
	x_max *= view_to_image_scale.x
	y_min *= view_to_image_scale.y
	y_max *= view_to_image_scale.y

	if x_max <= x_min or y_max <= y_min:
		return

	var x_min_s = x_min * scale + offset.x
	var y_min_s = y_min * scale + offset.y
	var x_max_s = x_max * scale + offset.x
	var y_max_s = y_max * scale + offset.y

	var x_center = ((x_min_s + x_max_s) * 0.5) / target_size.x
	var y_center = ((y_min_s + y_max_s) * 0.5) / target_size.y
	var width = (x_max_s - x_min_s) / target_size.x
	var height = (y_max_s - y_min_s) / target_size.y

	labels.append([class_id, x_center, y_center, width, height])


func _save_labels(path: String, labels: Array) -> bool:
	var lines: Array[String] = []
	for item in labels:
		lines.append("%d %.6f %.6f %.6f %.6f" % [item[0], item[1], item[2], item[3], item[4]])

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("\n".join(lines))
	file.close()
	return true


func _write_data_yaml() -> void:
	if session_dir.is_empty():
		return

	var yaml_path = session_dir.path_join("data.yaml")
	if FileAccess.file_exists(yaml_path):
		return

	var lines: Array[String] = []
	lines.append("path: .")
	lines.append("train: images/train")
	lines.append("val: images/val")
	lines.append("test: images/test")
	lines.append("nc: %d" % DATASET_NAMES.size())
	lines.append("names:")
	for name in DATASET_NAMES:
		lines.append("  - %s" % name)

	var file = FileAccess.open(yaml_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines) + "\n")
		file.close()


func _open_session_dir() -> void:
	if session_dir.is_empty():
		return
	if not DirAccess.dir_exists_absolute(session_dir):
		return
	var path = ProjectSettings.globalize_path(session_dir)
	if not path.is_empty():
		OS.shell_open(path)


func _rect_for_sprite(node: Node) -> Rect2:
	if node == null:
		return Rect2()

	var sprite = node.get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = node.find_child("Sprite2D", true, false)

	if sprite == null:
		return Rect2()
	if sprite is CanvasItem and not sprite.is_visible_in_tree():
		return Rect2()

	if not sprite.has_method("get_rect"):
		return Rect2()

	var rect = sprite.get_rect()
	return _transform_rect(rect, sprite.get_global_transform_with_canvas())


func _rect_for_tile(tile: Node) -> Rect2:
	if tile == null:
		return Rect2()

	var xform = tile.get_global_transform_with_canvas()
	var center = xform.origin
	var half = xform.basis_xform(Vector2(GameWorld.HALF_TILE_SIZE, GameWorld.HALF_TILE_SIZE)).abs()
	return Rect2(center - half, half * 2.0)


func _transform_rect(rect: Rect2, xform: Transform2D) -> Rect2:
	var p1 = xform * rect.position
	var p2 = xform * (rect.position + Vector2(rect.size.x, 0))
	var p3 = xform * (rect.position + Vector2(0, rect.size.y))
	var p4 = xform * (rect.position + rect.size)

	var min_x = min(p1.x, p2.x, p3.x, p4.x)
	var max_x = max(p1.x, p2.x, p3.x, p4.x)
	var min_y = min(p1.y, p2.y, p3.y, p4.y)
	var max_y = max(p1.y, p2.y, p3.y, p4.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
