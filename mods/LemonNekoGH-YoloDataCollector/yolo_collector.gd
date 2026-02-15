extends Node

const CAPTURE_INTERVAL := 0.5
const OUTPUT_DIR := "user://yolo_data"

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

var yolo_collecting := false
var yolo_timer: Timer
var capture_index := 0
var session_dir := ""

func _init() -> void:
	ModLoaderLog.debug("YOLO Data Collector Node Initiated!", "YOLO Data Collector")

func is_collecting() -> bool:
	return yolo_collecting


func _enter_tree() -> void:
	ModLoaderLog.debug("Collector entered tree. Inside: " + str(is_inside_tree()), "YOLO Data Collector")


func _exit_tree() -> void:
	ModLoaderLog.debug("Collector exited tree.", "YOLO Data Collector")


func start_collection() -> void:
	if yolo_collecting:
		return
	yolo_collecting = true
	_start_new_session()
	if yolo_timer == null:
		yolo_timer = Timer.new()
		yolo_timer.wait_time = CAPTURE_INTERVAL
		yolo_timer.one_shot = false
		add_child(yolo_timer)
		yolo_timer.timeout.connect(_capture_frame)
	yolo_timer.start()
	_capture_frame()


func stop_collection() -> void:
	if not yolo_collecting:
		return
	yolo_collecting = false
	if yolo_timer:
		yolo_timer.stop()
	_open_session_dir()


func _start_new_session() -> void:
	capture_index = 0
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	session_dir = OUTPUT_DIR.path_join("session_" + timestamp)
	var images_dir = session_dir.path_join("images")
	var labels_dir = session_dir.path_join("labels")
	DirAccess.make_dir_recursive_absolute(images_dir)
	DirAccess.make_dir_recursive_absolute(labels_dir)
	_write_data_yaml()


func _capture_frame() -> void:
	if _is_pause_menu_visible():
		return
	var viewport := get_viewport()
	if viewport == null:
		return

	var image := viewport.get_texture().get_image()
	if image == null:
		return

	var basename = "frame_%06d" % capture_index
	capture_index += 1

	var images_dir = session_dir.path_join("images")
	var labels_dir = session_dir.path_join("labels")
	var image_path = images_dir.path_join(basename + ".png")
	var label_path = labels_dir.path_join(basename + ".txt")

	var size = viewport.get_visible_rect().size
	var labels := _collect_labels(size)

	image.save_png(image_path)
	_save_labels(label_path, labels)


func _is_pause_menu_visible() -> bool:
	# PauseMenu path is unstable across versions, so we use a group marker instead.
	for node in get_tree().get_nodes_in_group("yolo_pause_menu"):
		if node is CanvasItem and node.is_visible_in_tree():
			return true
	return false


func _collect_labels(view_size: Vector2) -> Array:
	var labels := []

	for keeper in Keepers.getAll():
		var rect = _rect_for_sprite(keeper)
		_append_label(labels, CLASS_PLAYER, rect, view_size)

	if Level.dome:
		var rect = _rect_for_sprite(Level.dome)
		_append_label(labels, CLASS_DOME, rect, view_size)

	for monster in get_tree().get_nodes_in_group("monster"):
		var rect = _rect_for_sprite(monster)
		_append_label(labels, CLASS_ENEMY, rect, view_size)

	if Level.map and Level.map.tilesByType:
		for tile in Level.map.tilesByType.get(CONST.IRON, []):
			var rect = _rect_for_tile(tile)
			_append_label(labels, CLASS_IRON, rect, view_size)
		for tile in Level.map.tilesByType.get(CONST.SAND, []):
			var rect = _rect_for_tile(tile)
			_append_label(labels, CLASS_COBALT, rect, view_size)
		for tile in Level.map.tilesByType.get(CONST.WATER, []):
			var rect = _rect_for_tile(tile)
			_append_label(labels, CLASS_WATER, rect, view_size)

	return labels


func _append_label(labels: Array, class_id: int, rect: Rect2, view_size: Vector2) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1:
		return

	var x_min = clamp(rect.position.x, 0.0, view_size.x)
	var y_min = clamp(rect.position.y, 0.0, view_size.y)
	var x_max = clamp(rect.position.x + rect.size.x, 0.0, view_size.x)
	var y_max = clamp(rect.position.y + rect.size.y, 0.0, view_size.y)

	if x_max <= x_min or y_max <= y_min:
		return

	var x_center = ((x_min + x_max) * 0.5) / view_size.x
	var y_center = ((y_min + y_max) * 0.5) / view_size.y
	var width = (x_max - x_min) / view_size.x
	var height = (y_max - y_min) / view_size.y

	labels.append([class_id, x_center, y_center, width, height])


func _save_labels(path: String, labels: Array) -> void:
	var lines: Array[String] = []
	for item in labels:
		lines.append("%d %.6f %.6f %.6f %.6f" % [item[0], item[1], item[2], item[3], item[4]])

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
		file.close()


func _write_data_yaml() -> void:
	if session_dir.is_empty():
		return

	var yaml_path = session_dir.path_join("data.yaml")
	if FileAccess.file_exists(yaml_path):
		return

	var lines: Array[String] = []
	lines.append("path: .")
	lines.append("train: images")
	lines.append("val: images")
	lines.append("nc: %d" % DATASET_NAMES.size())
	lines.append("names:")
	for name in DATASET_NAMES:
		lines.append("  - %s" % name)

	var file = FileAccess.open(yaml_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
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
