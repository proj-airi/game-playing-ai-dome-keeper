extends Node

signal failed(reason: String)
signal recording_finished

const GADGET_CATALOG = preload("res://mods-unpacked/LemonNekoGH-YoloDataCollector/gadget_catalog.gd")
const SUPPLEMENT_CATALOG = preload("res://mods-unpacked/LemonNekoGH-YoloDataCollector/supplement_catalog.gd")

enum TaskType { SEARCH, MINE, INTERACT, ACQUIRE_RESOURCE, CLEANUP_RESOURCES, UPGRADE, DEFEND, RECOVER, CHOOSE_REWARD, WIDEN_SHAFT }
enum ExploreMode { DESCEND, BRANCH, BYPASS }
enum MiningOutcome { ACTIVE, BACKTRACK_PENDING, WAITING_WAVE, BLOCKED }
enum DescentFrontier { CLOSED, OPEN, UNSUPPORTED }
enum FrontierSearch { READY, WAITING_WAVE, BLOCKED }
enum UpgradeIntent { COMBAT, REPAIR, DRILL, MOBILITY, LASER_MOVE }
enum MobilityArm { SPEED, STRENGTH }
enum CaveTaskKind { NONE, SCANNER, DRONE, IRON_TREE, COBALT, WATER, MUSHROOM, PORTAL, HELMET }

const LOG_NAME := "YoloDataCollector:Teacher"
const STATUS_FILE := "airi-dome-keeper-status.json"
const RECORDING_ARG := "--airi-recording-dir="
const RECORDING_FPS_ARG := "--airi-recording-fps="
const CHECKPOINT_SESSION_ARG := "--airi-checkpoint-session="
const CHECKPOINT_LOAD_ARG := "--airi-checkpoint-load="
const CHECKPOINT_SAVE_ARG := "--airi-checkpoint-save"
const RECORDING_MOVIE := "recording.avi"
const RECORDING_RESOLUTION := Vector2i(1280, 720)
const CHECKPOINT_SIDECAR := "teacher.json"
const CHECKPOINT_FIELDS := [
	"pending_intents", "combat_attack_next", "mobility_arm",
	"drill_hits_by_coord", "wave_start_missing_health", "wave_start_max_health",
	"last_wave_health_loss", "wave_health_tracking", "caches", "shaft_widen_done",
]
const TASK_REF_FIELDS := [&"target", &"resource", &"gadget_drop", &"relic_chamber"]
const TICK := 0.1
const STATION_ENTRY_SECONDS := 2.0
const CARRY_PICKUP_SECONDS := 0.35
const ARTIFACT_UI_STEP_LIMIT := 40
const ARTIFACT_RECOVERY_LIMIT := 3
const INTERACTION_WAIT_LIMIT := 150
const MIN_SPEED_RATIO := 0.55
const WIDE_SHAFT_MIN_LOAD := 5
const STALL_SECONDS := 4.0
const INTERACTION_RADIUS_TILES := 10.0
const DEFAULT_REVEAL_DISTANCE := 1
const SCANNER_REVEAL_DISTANCE := 2
const SCANNER_CAVE_SCRIPT := "res://content/caves/scannercave/ScannerCave.gd"
const DRONE_CAVE_SCRIPT := "res://content/caves/dronecave/DroneCave.gd"
const IRON_TREE_CAVE_SCRIPT := "res://content/caves/treecave/IronTreeCave.gd"
const COBALT_CAVE_SCRIPT := "res://content/caves/cobaltcave/CobaltCave.gd"
const WATER_CAVE_SCRIPT := "res://content/caves/watercave/WaterCave.gd"
const MUSHROOM_CAVE_SCRIPT := "res://content/caves/mushroomcave/MushroomCave.gd"
const PORTAL_CAVE_SCRIPT := "res://content/caves/portalcave/PortalCave.gd"
const HELMET_CAVE_SCRIPT := "res://content/caves/helmetextensioncave/HelmetCave.gd"
const CAVE_KINDS_BY_SCRIPT := {
	SCANNER_CAVE_SCRIPT: CaveTaskKind.SCANNER,
	DRONE_CAVE_SCRIPT: CaveTaskKind.DRONE,
	IRON_TREE_CAVE_SCRIPT: CaveTaskKind.IRON_TREE,
	COBALT_CAVE_SCRIPT: CaveTaskKind.COBALT,
	WATER_CAVE_SCRIPT: CaveTaskKind.WATER,
	MUSHROOM_CAVE_SCRIPT: CaveTaskKind.MUSHROOM,
	PORTAL_CAVE_SCRIPT: CaveTaskKind.PORTAL,
	HELMET_CAVE_SCRIPT: CaveTaskKind.HELMET,
}
const RESOURCE_CAVE_REWARD_PATHS := {
	CaveTaskKind.IRON_TREE: [
		^"Sprites/Sprite4/Iron1", ^"Sprites/Sprite4/Iron2", ^"Sprites/Sprite4/Iron3",
		^"Sprites/Sprite4/Iron4", ^"Sprites/Sprite4/Iron5",
	],
	CaveTaskKind.COBALT: [^"Sprites/Sprite4/Cobalt1", ^"Sprites/Sprite4/Cobalt2"],
	CaveTaskKind.WATER: [
		^"Sprites/Sprite4/Water1", ^"Sprites/Sprite4/Water2", ^"Sprites/Sprite4/Water3",
	],
}
const RESOURCE_CAVE_DROP_TYPES := {
	CaveTaskKind.IRON_TREE: CONST.IRON,
	CaveTaskKind.COBALT: CONST.SAND,
	CaveTaskKind.WATER: CONST.WATER,
}
const SQUIDLEY_SCRIPT := "res://content/gadgets/droneyard/Squidley.gd"
const DRILL_HIT_INTENT_THRESHOLD := 5
const WAVE_NET_HEALTH_LOSS_RATIO_THRESHOLD := 0.15
const REPAIR_HEALTH_RESERVE_RATIO := 0.4
const NO_COORD := Vector2i(1 << 30, 1 << 30)
const ORE_TYPES: Array[String] = [CONST.IRON, CONST.SAND, CONST.WATER]
const ARTIFACT_CLEARANCE_TILE_TYPES: Array[String] = ["dirt", CONST.IRON, CONST.SAND, CONST.WATER]
const INTENT_CLASSES := [
	[UpgradeIntent.COMBAT, UpgradeIntent.REPAIR, UpgradeIntent.LASER_MOVE],
	[UpgradeIntent.DRILL, UpgradeIntent.MOBILITY],
]
const ATTACK_UPGRADES: Array[StringName] = [&"laserStrength1", &"laserStrength2", &"laserStrength3", &"laserStrength4"]
const LASER_MOVE_UPGRADES: Array[StringName] = [&"laserMove1", &"laserMove2", &"laserMove3"]
const HEALTH_UPGRADES: Array[StringName] = [&"dome1health1", &"dome1health2"]
const HEALTH_PATH: Array[StringName] = [&"domeHealthMeter", &"domesandrepair", &"dome1health1", &"dome1health2"]
const REPAIR_UPGRADES: Array[StringName] = [&"domeHealthMeter", &"domesandrepair"]
const DRILL_UPGRADES: Array[StringName] = [&"drill1", &"drill2", &"drill3", &"drill4"]
const SPEED_UPGRADES: Array[StringName] = [&"jetpackSpeed1", &"jetpackSpeed2", &"jetpackSpeed3", &"jetpackSpeed4"]
const CARRY_UPGRADES: Array[StringName] = [&"jetpackStrength1", &"jetpackStrength2", &"jetpackStrength3", &"jetpackStrength4"]
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_right", &"ui_down", &"ui_left"]
const CARDINAL_OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_select", &"ui_cancel",
	&"keeper1_pickup", &"keeper1_drop", &"dome_battle", &"dome_upgrades",
]

var running := false
var status_elapsed := 1.0
var status_path := ""
var recording_path := ""
var recording_fps := 0
var recording_file: FileAccess
var pending_recording_events: Array[Dictionary] = []
var recording_terminal := false
var recording_write_failed := false
var record_pending := false
var record_reason := ""
var laser_selected_monster: Variant = null
var laser_selected_monster_damageable: Variant = null
var laser_signed_angular_error: Variant = null
var laser_first_collider: Variant = null
var laser_first_collider_ray_index: Variant = null
var laser_selected_monster_ref: WeakRef
var laser_target: Monster
var previous_pause_when_out_of_focus := true
var previous_use_mouse_dome_gameplay := false
var tasks: Array[Dictionary] = []
var keeper: Keeper
var dome: Dome
var bindings := {}
var held := {}
var pending_intents := {}
var combat_attack_next := true
var mobility_arm := MobilityArm.SPEED
var drill_hits_by_coord := {}
var wave_start_missing_health := 0.0
var wave_start_max_health := 0.0
var last_wave_health_loss := 0.0
var wave_health_tracking := false
var observed_properties: Array[String] = []
var caches: Array[Vector2] = []
var shaft_widen_done := false
var tick_time := 0.0
var delay := 0.0
var pickup_failures := 0
var progress_action := StringName()
var progress_origin := Vector2.ZERO
var stalled := 0.0
var checkpoint_session_id := ""
var checkpoint_save_enabled := false
var checkpoint_load_pending := false
var checkpoint_state := {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	status_path = _temp_dir().path_join(STATUS_FILE)
	_configure_runtime()
	_write_status()

func is_checkpoint_load_pending() -> bool:
	return checkpoint_load_pending

func start() -> bool:
	if running:
		return true

	var error := _preflight()
	if error.is_empty():
		error = _load_bindings()
	if error.is_empty() and not recording_path.is_empty():
		error = _open_recording()
	if not error.is_empty():
		ModLoaderLog.error(error, LOG_NAME)
		return false

	previous_pause_when_out_of_focus = Options.pauseWhenOutOfFocus
	previous_use_mouse_dome_gameplay = Options.useMouseDomeGameplay
	Options.pauseWhenOutOfFocus = false
	Options.useMouseDomeGameplay = false
	InputSystem.game_not_in_focus = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pending_intents.clear()
	pending_intents[UpgradeIntent.COMBAT] = true
	pending_intents[UpgradeIntent.LASER_MOVE] = true
	pending_intents[UpgradeIntent.DRILL] = true
	combat_attack_next = _bought_count(ATTACK_UPGRADES) <= _bought_count(HEALTH_UPGRADES)
	mobility_arm = MobilityArm.SPEED
	drill_hits_by_coord.clear()
	tasks.clear()
	wave_health_tracking = _wave("wavepresent") or _wave("wavebattle")
	wave_start_max_health = _dome_max_health()
	wave_start_missing_health = maxf(wave_start_max_health - _dome_health(), 0.0)
	last_wave_health_loss = 0.0
	_sync_repair_intent()
	observed_properties.assign([
		"game.over",
		keeper.teamId + ".monsters.cycle", keeper.teamId + ".monsters.wavepresent",
		keeper.teamId + ".monsters.wavebattle",
		keeper.teamId + ".event.keepers.insidedome", keeper.teamId + ".dome.health",
		keeper.teamId + ".dome.maxhealth", keeper.teamId + ".inventory.iron",
		keeper.teamId + ".inventory.sand", keeper.teamId + ".inventory.water",
		keeper.teamId + ".laser.dps", keeper.teamId + ".laser.dpsmod",
		keeper.teamId + ".laser.movespeed", keeper.teamId + ".laser.movespeedmod",
		keeper.teamId + ".laser.movespeedwhilefiring",
		keeper.playerId + ".keeper1.maxSpeed", keeper.playerId + ".keeper1.speedLossPerCarry",
		keeper.playerId + ".keeper1.drillStrength",
		"map.revealdistance",
	])
	for property in observed_properties:
		Data.listen(self, property)
	running = true
	var search := _new_search_task("relic")
	search.resume_coord = Level.map.getTileCoord(_home_position())
	search.attempted_descent_origins[search.resume_coord] = true
	tasks.append(search)
	if _leaf() == "BattleInputProcessor" or _wave("wavepresent") or _wave("wavebattle"):
		tasks.append({"type": TaskType.DEFEND, "saw_wave": true})
	caches.clear()
	shaft_widen_done = false
	_reset_progress()
	if not checkpoint_state.is_empty():
		error = _restore_checkpoint(checkpoint_state)
		checkpoint_state.clear()
		if not error.is_empty():
			ModLoaderLog.error(error, LOG_NAME)
			stop()
			return false
	keeper.mined.connect(_on_mined)
	Level.drops.synchronizer.drop_picked_up.connect(_on_drop_picked_up)
	Level.monstersByTeamId[keeper.teamId].monsterSynchronizer.spawned.connect(_on_monster_spawned)
	GameWorld.upgradeBought.connect(_on_upgrade_bought)
	GameWorld.upgradeError.connect(_on_upgrade_error)
	ModLoaderLog.info("Started rule teacher", LOG_NAME)
	_reset_laser_aim()
	if not recording_path.is_empty():
		record_pending = false
		_record("session_started", "Teacher collection started", null)
	return true
func stop() -> bool:
	if not running:
		return not recording_write_failed
	InputSystem.game_not_in_focus = false
	_release_all()
	for property in observed_properties:
		Data.unlisten(self, property)
	observed_properties.clear()
	if is_instance_valid(keeper):
		if keeper.mined.is_connected(_on_mined):
			keeper.mined.disconnect(_on_mined)
		var monster_wave = Level.monstersByTeamId.get(keeper.teamId)
		if is_instance_valid(monster_wave) and is_instance_valid(monster_wave.monsterSynchronizer) and monster_wave.monsterSynchronizer.spawned.is_connected(_on_monster_spawned):
			monster_wave.monsterSynchronizer.spawned.disconnect(_on_monster_spawned)
	if is_instance_valid(Level.drops) and is_instance_valid(Level.drops.synchronizer) and Level.drops.synchronizer.drop_picked_up.is_connected(_on_drop_picked_up):
		Level.drops.synchronizer.drop_picked_up.disconnect(_on_drop_picked_up)
	if GameWorld.upgradeBought.is_connected(_on_upgrade_bought):
		GameWorld.upgradeBought.disconnect(_on_upgrade_bought)
	if GameWorld.upgradeError.is_connected(_on_upgrade_error):
		GameWorld.upgradeError.disconnect(_on_upgrade_error)
	var recording_flushed := _flush_recording()
	if recording_file != null:
		recording_file.close()
		recording_file = null
	running = false; keeper = null; tasks.clear()
	_reset_laser_aim()
	Options.pauseWhenOutOfFocus = previous_pause_when_out_of_focus
	Options.useMouseDomeGameplay = previous_use_mouse_dome_gameplay
	InputSystem.game_not_in_focus = not DisplayServer.window_is_focused()
	pending_recording_events.clear()
	return recording_flushed

func _process(delta: float) -> void:
	status_elapsed += delta
	if status_elapsed >= 1.0:
		status_elapsed = 0.0
		_write_status()
		_flush_recording()
	if not running:
		return
	var focus_was_lost: bool = bool(InputSystem.game_not_in_focus)
	InputSystem.game_not_in_focus = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if focus_was_lost:
		held.clear()
	if not StageManager.isInLevel() or not Level.initialized or not is_instance_valid(keeper):
		_fail("Teacher lost its supported game state")
		return
	_sync_repair_intent()
	var processor = InputSystem.getLastChild(keeper.deviceId)
	var reward_open := is_instance_valid(processor) and str(processor.name) == "GadgetChoiceInputProcessor"
	if reward_open and not _task_is(TaskType.CHOOSE_REWARD):
		_push_task({"type": TaskType.CHOOSE_REWARD}, "A mandatory artifact choice opened")
	if not running:
		return
	if _blocked():
		_release_all(); _reset_progress()
		return
	if keeper.isInsideStation and _leaf() == "StationInputProcessor":
		_tick_tasks(delta)
		return

	delay = maxf(delay - delta, 0.0)
	var active_type := _task_type()
	if active_type != TaskType.RECOVER and active_type != TaskType.UPGRADE and active_type != TaskType.DEFEND and active_type != TaskType.CHOOSE_REWARD:
		_track_progress(delta)
	if not running or delay > 0.0:
		return
	tick_time += delta
	if tick_time < TICK:
		return
	tick_time = 0.0
	_tick_tasks(delta)

func _physics_process(_delta: float) -> void:
	if not running or _task_type() != TaskType.DEFEND:
		_clear_laser_aim("Laser aiming became inactive")
		return
	if (
		delay > 0.0
		or not StageManager.isInLevel()
		or not Level.initialized
		or not is_instance_valid(keeper)
		or not is_instance_valid(dome)
	):
		_clear_laser_aim("Laser aiming lost the supported game state")
		_release_all()
		return
	if (
		_blocked()
		or not keeper.isInsideStation
		or not _wave("wavepresent")
		or _leaf() != "BattleInputProcessor"
	):
		_clear_laser_aim("Laser aiming input became unavailable")
		_release_all()
		return
	_aim()

func _configure_runtime() -> void:
	var directory := ""
	var recording_requested := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(RECORDING_ARG):
			recording_requested = true
			directory = argument.trim_prefix(RECORDING_ARG).simplify_path()
		elif argument.begins_with(RECORDING_FPS_ARG):
			recording_requested = true
			recording_fps = int(argument.trim_prefix(RECORDING_FPS_ARG))
		elif argument == CHECKPOINT_SAVE_ARG:
			checkpoint_save_enabled = true
		elif argument.begins_with(CHECKPOINT_SESSION_ARG):
			checkpoint_session_id = argument.trim_prefix(CHECKPOINT_SESSION_ARG)
		elif argument.begins_with(CHECKPOINT_LOAD_ARG):
			checkpoint_load_pending = true
			call_deferred(&"_load_checkpoint", argument.trim_prefix(CHECKPOINT_LOAD_ARG))
	if not recording_requested:
		return
	var movie := ProjectSettings.globalize_path(Engine.get_write_movie_path()).simplify_path()
	var window_size := get_window().size
	if (
		not directory.is_absolute_path()
		or not DirAccess.dir_exists_absolute(directory)
		or recording_fps <= 0
	):
		push_error("Recording directory and FPS are invalid")
		get_tree().quit(1)
	elif OS.has_feature("movie") and movie != directory.path_join(RECORDING_MOVIE):
		push_error("Movie Maker output does not match the recording session")
		get_tree().quit(1)
	elif OS.has_feature("movie") and window_size != RECORDING_RESOLUTION:
		push_error(
			"Recording window is %s instead of %s"
			% [str(window_size), str(RECORDING_RESOLUTION)]
		)
		get_tree().quit(1)
	elif not OS.has_feature("movie") and DisplayServer.get_name() != "headless" and window_size != RECORDING_RESOLUTION:
		push_error(
			"Configured windowed replay requires the recording resolution"
		)
		get_tree().quit(1)
	else:
		recording_path = directory.path_join("recording.jsonl")

func _load_checkpoint(checkpoint_id: String) -> void:
	var result = await SaveGame.loadGame(checkpoint_id, 0)
	var error := ""
	if result != OK:
		error = "Official save load failed for checkpoint " + checkpoint_id
	else:
		var file := FileAccess.open(
			"user://%s/%s" % [checkpoint_id, CHECKPOINT_SIDECAR],
			FileAccess.READ
		)
		if file == null:
			error = "Failed to open teacher checkpoint: " + error_string(FileAccess.get_open_error())
		else:
			var parsed = JSON.parse_string(file.get_as_text())
			if not parsed is Dictionary or int(parsed.get("version", 0)) != 5:
				error = "Teacher checkpoint is malformed or has an unsupported version"
			else:
				checkpoint_state = parsed
	if error.is_empty():
		checkpoint_load_pending = false
		return
	push_error(error)
	ModLoaderLog.error(error, LOG_NAME)
	get_tree().quit(1)

func is_recording_configured() -> bool:
	return not recording_path.is_empty()

func _open_recording() -> String:
	pending_recording_events.clear()
	recording_terminal = false
	recording_write_failed = false
	if FileAccess.file_exists(recording_path):
		return "Replay already exists for this recording session"
	recording_file = FileAccess.open(recording_path, FileAccess.WRITE)
	if recording_file == null:
		return "Failed to open replay: " + error_string(FileAccess.get_open_error())
	recording_file.store_line(JSON.stringify({"fixed_fps": recording_fps}))
	recording_file.flush()
	if recording_file.get_error() == OK:
		return ""
	var error := "Failed to write replay metadata: " + error_string(recording_file.get_error())
	recording_file.close()
	recording_file = null
	return error

func _checkpoint_snapshot() -> Dictionary:
	var values := {}
	for field in CHECKPOINT_FIELDS:
		values[field] = var_to_str(get(field))
	var saved_tasks: Array[String] = []
	for task in tasks:
		var saved: Dictionary = task.duplicate(true)
		saved.erase("scanner_receiver")
		for field in TASK_REF_FIELDS:
			if saved.has(field):
				saved[field] = _checkpoint_ref(saved[field])
		if saved.has("ignored"):
			var ignored: Array = []
			for value in saved.ignored:
				var ref = _checkpoint_ref(value)
				if ref != null:
					ignored.append(ref)
			saved.ignored = ignored
		saved_tasks.append(var_to_str(saved))
	return {"version": 5, "values": values, "tasks": saved_tasks}

func _restore_checkpoint(data: Dictionary) -> String:
	var values: Dictionary = data.get("values", {})
	for field in CHECKPOINT_FIELDS:
		if not values.has(field):
			return "Teacher checkpoint is missing state field: " + field
		set(field, str_to_var(values[field]))
	if not data.get("tasks") is Array or data.tasks.is_empty():
		return "Teacher checkpoint task stack is missing"
	tasks.clear()
	for encoded in data.tasks:
		var task = str_to_var(encoded)
		if not task is Dictionary or not task.has("type"):
			return "Teacher checkpoint task is malformed"
		for field in TASK_REF_FIELDS:
			if not task.has(field):
				continue
			var ref = task[field]
			task[field] = _restore_checkpoint_ref(ref)
			if ref != null and not is_instance_valid(task[field]):
				return "Official save did not restore task reference: " + str(field)
		if task.has("ignored"):
			var ignored := {}
			for ref in task.ignored:
				var object = _restore_checkpoint_ref(ref)
				if not is_instance_valid(object):
					return "Official save did not restore cleanup resource reference"
				ignored[object] = true
			task.ignored = ignored
		tasks.append(task)
	return ""

func _checkpoint_ref(value):
	if not is_instance_valid(value):
		return null
	if value is Drop:
		return ["drop", value.UID]
	if value is Chamber:
		return ["chamber", var_to_str(value.coord)]
	if value is Cave:
		return ["cave", var_to_str(value.coord)]
	return null

func _restore_checkpoint_ref(value):
	if not value is Array or value.size() != 2:
		return null
	if value[0] == "drop":
		return Level.drops.get_drop(int(value[1])) if Level.drops.has_drop(int(value[1])) else null
	var group := str(value[0])
	var coord = str_to_var(value[1])
	var candidates: Array[Node] = (
		Level.map.tiles_node.get_children()
		if group == "chamber"
		else get_tree().get_nodes_in_group(group)
	)
	for candidate in candidates:
		if group == "chamber" and not candidate is Chamber:
			continue
		if candidate.get("coord") == coord:
			return candidate
	return null

func _save_checkpoint(completed_waves: int) -> void:
	var checkpoint_id := "%s_wave_%d" % [checkpoint_session_id, completed_waves]
	SaveGame.saveGame(checkpoint_id, 0, true)
	for template in [
		SaveGame.SAVE_SLOT_FILE_TEMPLATE,
		SaveGame.SAVE_TILE_FILE_TEMPLATE,
		SaveGame.SAVE_TILE_FILE_REPLAY_TEMPLATE,
	]:
		if not FileAccess.file_exists(template % [checkpoint_id, 0]):
			_fail("Official save failed for checkpoint " + checkpoint_id)
			return
	var file := FileAccess.open("user://%s/%s" % [checkpoint_id, CHECKPOINT_SIDECAR], FileAccess.WRITE)
	if file == null:
		_fail("Failed to open teacher checkpoint: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(_checkpoint_snapshot(), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		_fail("Failed to write teacher checkpoint: " + error_string(error))
		return
	ModLoaderLog.info("Saved debug checkpoint " + checkpoint_id, LOG_NAME)

func _temp_dir() -> String:
	for variable in ["TMPDIR", "TEMP", "TMP"]:
		var path := OS.get_environment(variable)
		if not path.is_empty():
			return path
	return "/tmp"

func _write_status() -> void:
	var file := FileAccess.open(status_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write status: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(get_status_snapshot()))

func _queue_record(reason: String) -> void:
	if recording_file == null or recording_terminal or record_pending:
		return
	record_pending = true
	record_reason = reason
	await get_tree().process_frame
	record_pending = false
	_record("observation", record_reason, null)

func _record(type: String, reason: String, detail) -> void:
	if recording_file == null or recording_terminal:
		return
	pending_recording_events.append({
		"movie_frame": Engine.get_process_frames(), "type": type, "reason": reason,
		"detail": detail, "state": get_status_snapshot(),
	})

func _flush_recording() -> bool:
	if recording_write_failed:
		return false
	if recording_file == null or pending_recording_events.is_empty():
		return true
	var write_error := OK
	for event in pending_recording_events:
		recording_file.store_line(JSON.stringify(event))
		write_error = recording_file.get_error()
		if write_error != OK:
			break
	if write_error == OK:
		recording_file.flush()
		write_error = recording_file.get_error()
	if write_error != OK:
		push_error("Failed to write replay: " + error_string(write_error))
		recording_write_failed = true
		recording_file.close()
		recording_file = null
		get_tree().quit(1)
		return false
	pending_recording_events.clear()
	return true

func get_status_snapshot() -> Dictionary:
	if not running or not StageManager.isInLevel() or not Level.initialized or not is_instance_valid(keeper) or not is_instance_valid(dome):
		return {"available": false, "run_time_seconds": 0.0}

	var wave_time := _wave_time()
	var next_wave: Variant = maxf(wave_time, 0.0) if is_finite(wave_time) else null
	var next_upgrade := _next_upgrade_target(false)
	var next_upgrade_id: String = next_upgrade.get("id", "")
	var resolved_next: Variant = null if next_upgrade_id.is_empty() else {"id": next_upgrade_id, "cost": _status_upgrade_cost(next_upgrade_id)}
	return {
		"available": true,
		"run_time_seconds": maxf(float(GameWorld.runTime), 0.0),
		"teacher": {"tasks": _status_tasks()},
		"keeper": {
			"carried_resources": _status_carried_resources(),
			"carried_artifact": _status_carried_artifact(),
			"stats": _status_keeper_stats(),
		},
		"dome": {
			"health": {
				"current": _dome_health(),
				"maximum": _dome_max_health(),
				"level": _bought_count(HEALTH_UPGRADES),
			},
			"laser": _status_laser_stats(),
			"stored_resources": _status_stored_resources(),
		},
		"wave": {
			"number": int(Data.ofOr(keeper.teamId + ".monsters.cycle", 0)) + 1,
			"seconds_until_next": next_wave,
			"active_monsters": _status_active_monsters(),
		},
		"upgrades": {
			"pending_intents": _status_pending_intents(),
			"resolved_next": resolved_next,
		},
	}

func _status_carried_resources() -> Dictionary:
	var resources := {"iron": 0, "cobalt": 0, "water": 0}
	for drop in keeper.carriedCarryables:
		if not is_instance_valid(drop) or not drop is Drop or drop.carryableType != "resource":
			continue
		match drop.type:
			CONST.IRON: resources["iron"] += 1
			CONST.SAND: resources["cobalt"] += 1
			CONST.WATER: resources["water"] += 1
	return resources

func _status_carried_artifact():
	for drop in keeper.carriedCarryables:
		if drop is Drop and drop.type in [CONST.GADGET, CONST.POWERCORE, CONST.RELIC]:
			return str(drop.type)
	return null

func _status_stored_resources() -> Dictionary:
	return _status_resources(
		Data.getInventory(CONST.IRON, keeper.teamId), Data.getInventory(CONST.SAND, keeper.teamId), Data.getInventory(CONST.WATER, keeper.teamId))

func _status_upgrade_cost(id: String) -> Dictionary:
	var cost: Dictionary = GameWorld.upgrades[id].get("cost", {})
	return _status_resources(cost.get(CONST.IRON, 0), cost.get(CONST.SAND, 0), cost.get(CONST.WATER, 0))

func _status_resources(iron, cobalt, water) -> Dictionary:
	return {"iron": int(iron), "cobalt": int(cobalt), "water": int(water)}

func _status_keeper_stats() -> Dictionary:
	return {
		"movement_speed": {
			"base": float(Data.of(keeper.playerId + ".keeper1.maxSpeed")),
			"current": keeper.currentSpeed() * _speed_ratio_for_count(keeper.carriedCarryables.size(), _carry_loss()),
			"level": _bought_count(SPEED_UPGRADES),
		},
		"carry_strength": {
			"speed_loss_per_carry": _carry_loss(),
			"current_slowdown_percent": float(keeper.get("carrySlowdown")) * 100.0,
			"level": _bought_count(CARRY_UPGRADES),
		},
		"drill_strength": {
			"value": float(Data.of(keeper.playerId + ".keeper1.drillStrength")),
			"level": _bought_count(DRILL_UPGRADES),
		},
	}

func _status_laser_stats() -> Dictionary:
	var movement_speed := (
		float(Data.ofOr(keeper.teamId + ".laser.movespeed", 0.0))
		* float(Data.ofOr(keeper.teamId + ".laser.movespeedmod", 1.0))
	)
	return {
		"attack_strength": {
			"value": (
				float(Data.ofOr(keeper.teamId + ".laser.dps", 0.0))
				* float(Data.ofOr(keeper.teamId + ".laser.dpsmod", 1.0))
			),
			"level": _bought_count(ATTACK_UPGRADES),
		},
		"movement_speed": {
			"value": movement_speed,
			"while_firing": movement_speed * float(Data.ofOr(keeper.teamId + ".laser.movespeedwhilefiring", 1.0)),
			"level": _bought_count(LASER_MOVE_UPGRADES),
		},
		"aim": {
			"selected_monster": laser_selected_monster,
			"selected_monster_damageable": laser_selected_monster_damageable,
			"signed_angular_error_radians": laser_signed_angular_error,
			"first_collider": (
				null if laser_first_collider == null else {
					"ray_index": laser_first_collider_ray_index,
					"object": laser_first_collider,
				}
			),
		},
	}

func _status_active_monsters() -> Array[Dictionary]:
	var wave_manager = Level.monstersByTeamId.get(keeper.teamId)
	if not is_instance_valid(wave_manager):
		return []
	var grouped := {}
	for monster in wave_manager.monstersInWave:
		if not is_instance_valid(monster) or monster.dead:
			continue
		var kind := Utils.decode_monster_type(monster.type)
		if not grouped.has(kind):
			grouped[kind] = {"kind": kind, "count": 0, "health": 0.0, "max_health": 0.0}
		grouped[kind]["count"] += 1
		grouped[kind]["health"] += maxf(float(monster.currentHealth), 0.0)
		grouped[kind]["max_health"] += maxf(float(monster.maxHealth), 0.0)
	var kinds := grouped.keys()
	kinds.sort()
	var result: Array[Dictionary] = []
	for kind in kinds:
		var group: Dictionary = grouped[kind]
		result.append(group)
	return result

func _status_pending_intents() -> Array[String]:
	var intents: Array[String] = []
	for intent_class in INTENT_CLASSES:
		for intent in intent_class:
			if pending_intents.has(intent):
				intents.append(str(UpgradeIntent.keys()[intent]).to_lower())
	return intents

func _preflight() -> String:
	if checkpoint_save_enabled and checkpoint_session_id.is_empty():
		return "Checkpoint saving requires a recording session ID"
	if not StageManager.isInLevel() or not Level.initialized or Level.map == null:
		return "Start a run before starting teacher collection"
	if GameWorld.gameover:
		return "Teacher cannot start after the run has ended"
	if Level.isMultiplayer() or Keepers.local.getCount() != 1:
		return "Teacher requires one offline keeper"
	keeper = Keepers.local.first()
	if not is_instance_valid(keeper) or keeper.techId != "keeper1" or Options.useGamepad(keeper.deviceId):
		return "Teacher requires one local keyboard Engineer"
	if keeper.isInsideStation and _leaf() != "StationInputProcessor" and _leaf() != "BattleInputProcessor":
		return "Close station modals before starting teacher collection"
	dome = Level.getDome(keeper.teamId)
	if not is_instance_valid(dome) or dome.techId != "dome1" or _laser() == null:
		return "Teacher requires one normal Laser Dome weapon"
	if Level.loadout.modeId != CONST.MODE_RELICHUNT:
		return "Teacher requires Relic Hunt mode"
	var full_load := _full_load_count(_carry_loss())
	if full_load <= 0 or full_load >= 128:
		return "Engineer carry slowdown does not produce a bounded supported load"
	if not is_finite(_planning_base_speed()) or _planning_base_speed() <= 0.0:
		return "Engineer movement speed must be positive and finite"
	var reveal_distance := int(Data.ofOr("map.revealdistance", DEFAULT_REVEAL_DISTANCE))
	if reveal_distance != DEFAULT_REVEAL_DISTANCE and reveal_distance != SCANNER_REVEAL_DISTANCE:
		return "Teacher supports map reveal distance 1 or 2"
	return ""

func _branch_row_step() -> int:
	return 1 + int(Data.ofOr("map.revealdistance", DEFAULT_REVEAL_DISTANCE)) * 2

func _step_wide_shaft(task: Dictionary, cell: Vector2i) -> bool:
	var col := int(task.get("shaft_col", -1))
	if col < 0 or absi(cell.x - col) > 1:
		task.shaft_col = cell.x
		col = cell.x
	var phase := int(task.get("shaft_phase", 0))
	for _guard in range(4):
		var target := cell
		match phase:
			0: target = Vector2i(col + 1, cell.y)
			1: target = Vector2i(col - 1, cell.y)
			_:
				target = Vector2i(col, int(task.get("shaft_row", cell.y)) + 1)
		if phase < 2:
			var side = Level.map.getTile(target)
			if not (side is Tile and ARTIFACT_CLEARANCE_TILE_TYPES.has(side.type) and side.get_meta("destructable", false)):
				phase += 1
				if phase == 2:
					task.shaft_row = cell.y
				task.shaft_phase = phase
				continue
		if phase == 2 and cell.y > int(task.get("shaft_row", cell.y)):
			task.shaft_phase = 0
			continue
		if Level.map.getTileCoord(keeper.global_position) == target:
			phase = (phase + 1) % 3
			if phase == 2:
				task.shaft_row = cell.y
			task.shaft_phase = phase
			continue
		_hold(_axis(Level.map.getTilePos(target)))
		return true
	_hold([&"ui_down"])
	return true

func _widen_main_shaft(task: Dictionary) -> void:
	var col := int(task.get("main_col", -1))
	if col < 0:
		task.main_col = Level.map.getTileCoord(_home_position()).x
		col = int(task.main_col)
	var entry_coord := Vector2i(task.get("entry_coord", NO_COORD))
	if entry_coord == NO_COORD:
		task.entry_coord = Level.map.getTileCoord(_home_position())
		entry_coord = Vector2i(task.entry_coord)
	var cell: Vector2i = Level.map.getTileCoord(keeper.global_position)
	if not bool(task.get("descending", false)):
		if cell == entry_coord:
			task.descending = true
		else:
			if not _move_open(Level.map.getTilePos(entry_coord)):
				_fail("No open path reaches the main shaft entrance")
			return
	var phase := int(task.get("widen_phase", 0))
	for _guard in range(4):
		var target := cell
		match phase:
			0: target = Vector2i(col + 1, cell.y)
			1: target = Vector2i(col - 1, cell.y)
			_:
				target = Vector2i(col, int(task.get("widen_row", cell.y)) + 1)
		if phase < 2:
			var side = Level.map.getTile(target)
			if not (side is Tile and ARTIFACT_CLEARANCE_TILE_TYPES.has(side.type) and side.get_meta("destructable", false)):
				phase += 1
				if phase == 2:
					task.widen_row = cell.y
				task.widen_phase = phase
				continue
		if phase == 2 and cell.y > int(task.get("widen_row", cell.y)):
			task.widen_phase = 0
			continue
		if phase == 2 and Level.map.getTile(target) is Tile:
			shaft_widen_done = true
			var cleared := 0
			for row in range(entry_coord.y + 1, cell.y + 1):
				for side in [Vector2i(col - 1, row), Vector2i(col + 1, row)]:
					var tile = Level.map.getTile(side)
					if not (tile is Tile and ARTIFACT_CLEARANCE_TILE_TYPES.has(tile.type) and tile.get_meta("destructable", false)):
						cleared += 1
			_record("shaft_widened", "The main shaft was widened to three tiles", {
				"col": col, "depth": cell.y, "cleared": cleared,
			})
			_pop_task("The main shaft has been widened")
			return
		if Level.map.getTileCoord(keeper.global_position) == target:
			phase = (phase + 1) % 3
			if phase == 2:
				task.widen_row = cell.y
			task.widen_phase = phase
			continue
		_hold(_axis(Level.map.getTilePos(target)))
		return
	_hold([&"ui_down"])

func _load_bindings() -> String:
	bindings.clear(); var actions := ACTIONS.duplicate()
	actions.append(StringName(dome.techId + "_fire"))
	for action in actions:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				bindings[action] = event; break
		if not bindings.has(action):
			return "Missing keyboard binding for action: " + str(action)
	return ""

func _new_search_task(goal: String, minimum := 1) -> Dictionary:
	return {
		"type": TaskType.SEARCH,
		"goal": goal,
		"minimum": minimum,
		"mode": ExploreMode.DESCEND,
		"branch_row": -1000000,
		"branch_side": 1,
		"branch_entry_coord": NO_COORD,
		"bypass_side": 1,
		"bypass_reversed": false,
		"mining_outcome": MiningOutcome.ACTIVE,
		"mining_outcome_reason": "",
		"completed_corridors": [],
		"active_corridor_cells": {},
		"attempted_descent_origins": {},
		"resume_coord": NO_COORD,
		"relic_chamber": null,
		"shaft_phase": 0,
		"shaft_col": -1,
		"shaft_row": -1,
	}

func _task_type() -> int:
	return TaskType.SEARCH if tasks.is_empty() else int(tasks.back().type)

func _task_is(type: TaskType) -> bool:
	return not tasks.is_empty() and int(tasks.back().type) == type

func _find_task(type: TaskType) -> Dictionary:
	for index in range(tasks.size() - 1, -1, -1):
		if int(tasks[index].type) == type:
			return tasks[index]
	return {}

func _root_relic_search() -> Dictionary:
	if tasks.is_empty():
		return {}
	var root: Dictionary = tasks.front()
	if int(root.get("type", -1)) != TaskType.SEARCH or str(root.get("goal", "")) != "relic":
		return {}
	return root

func _push_task(task: Dictionary, reason: String) -> void:
	_release_all()
	if (
		int(task.type) == TaskType.DEFEND
		and _task_is(TaskType.MINE)
		and Vector2i(tasks.back().approach_coord) == NO_COORD
	):
		tasks.back().approach_coord = Level.map.getTileCoord(keeper.global_position)
	var search := _find_task(TaskType.SEARCH)
	if (
		int(task.type) != TaskType.RECOVER
		and not search.is_empty()
		and Vector2i(search.resume_coord) == NO_COORD
	):
		search.resume_coord = Level.map.getTileCoord(keeper.global_position)
	tasks.append(task)
	delay = 0.2
	pickup_failures = 0
	_reset_progress()
	_record("task_pushed", reason, _status_task(task))

func _pop_task(reason: String) -> Dictionary:
	if tasks.size() <= 1:
		_fail("The root search task cannot finish: " + reason)
		return {}
	_release_all()
	var finished: Dictionary = tasks.pop_back()
	delay = 0.2
	pickup_failures = 0
	_reset_progress()
	_record("task_popped", reason, _status_task(finished))
	return finished

func _status_tasks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(tasks.size() - 1, -1, -1):
		result.append(_status_task(tasks[index]))
	return result

func _status_task(task: Dictionary) -> Dictionary:
	var type := int(task.get("type", -1))
	var result := {
		"type": str(TaskType.keys()[type]).to_lower() if type >= 0 and type < TaskType.size() else "unknown",
	}
	match type:
		TaskType.SEARCH:
			result["detail"] = str(task.get("goal", "relic"))
		TaskType.MINE:
			result["detail"] = str(task.get("ore", NO_COORD))
		TaskType.INTERACT:
			result["detail"] = str(task.get("label", "interactable"))
		TaskType.ACQUIRE_RESOURCE:
			result["detail"] = "%d %s" % [int(task.get("amount", 1)), str(task.get("resource_type", "resource"))]
		TaskType.UPGRADE:
			result["detail"] = str(task.get("active_id", "select target"))
		TaskType.DEFEND:
			result["detail"] = "active wave" if bool(task.get("saw_wave", false)) else "pre-wave staging"
		TaskType.RECOVER:
			result["detail"] = "movement probe"
		TaskType.CHOOSE_REWARD:
			result["detail"] = "mandatory artifact choice"
		TaskType.WIDEN_SHAFT:
			result["detail"] = "main shaft"
	return result

func _tick_tasks(delta: float) -> void:
	if tasks.is_empty():
		_fail("Teacher has no active task")
		return
	var active_type := _task_type()
	if active_type == TaskType.CHOOSE_REWARD:
		_choose_reward(tasks.back(), delta)
		return
	if active_type == TaskType.UPGRADE and (
		_wave("wavepresent")
		or _wave("wavebattle")
		or (_defense_due() and not keeper.isInsideStation)
	):
		tasks.back().closing = true
	if active_type != TaskType.UPGRADE and active_type != TaskType.DEFEND and (_wave("wavepresent") or _wave("wavebattle") or _defense_due()):
		_push_task({"type": TaskType.DEFEND, "saw_wave": _wave("wavepresent") or _wave("wavebattle")}, "Defense requires the keeper at the dome")
		return
	if active_type != TaskType.UPGRADE and active_type != TaskType.DEFEND and not _wave("wavepresent") and _leaf() == "StationInputProcessor":
		var upgrade := _next_upgrade_target()
		var upgrade_id: String = upgrade.get("id", "")
		if not upgrade_id.is_empty() and _upgrade_ready(upgrade_id):
			_push_task({"type": TaskType.UPGRADE}, "An affordable upgrade is available at the base computer")
			return
	if (
		active_type != TaskType.UPGRADE
		and active_type != TaskType.DEFEND
		and active_type != TaskType.CHOOSE_REWARD
		and not shaft_widen_done
		and _shaft_should_widen()
		and _find_task(TaskType.WIDEN_SHAFT).is_empty()
	):
		_push_task({"type": TaskType.WIDEN_SHAFT, "main_col": -1, "entry_coord": NO_COORD, "widen_phase": 0, "widen_row": -1, "descending": false}, "The carry load reached the shaft-widening threshold")
		return
	if active_type != TaskType.UPGRADE and active_type != TaskType.DEFEND and keeper.isInsideStation:
		_release_all()
		if _leaf() == "StationInputProcessor":
			_tap(&"ui_cancel")
			delay = 0.5
		return
	var task: Dictionary = tasks.back()
	if _task_can_scan(task) and _scan_interaction(str(task.get("goal", ""))):
		return
	match int(task.type):
		TaskType.SEARCH: _search(task)
		TaskType.MINE: _mine(task)
		TaskType.INTERACT: _interact(task)
		TaskType.ACQUIRE_RESOURCE: _acquire_resource(task)
		TaskType.CLEANUP_RESOURCES: _cleanup_resources(task)
		TaskType.UPGRADE: _upgrade(task)
		TaskType.DEFEND: _defend(task)
		TaskType.RECOVER: _recover(task)
		TaskType.WIDEN_SHAFT: _widen_main_shaft(task)
		_: _fail("Unsupported task type: " + str(task.type))

func _task_can_scan(task: Dictionary) -> bool:
	return int(task.type) == TaskType.SEARCH or int(task.type) == TaskType.ACQUIRE_RESOURCE

func _search(task: Dictionary) -> void:
	var goal := str(task.goal)
	if goal != "relic" and _resource_site(goal, int(task.minimum)) is Vector2:
		_pop_task("A known cache now contains the requested " + goal)
		return
	var outcome := int(task.mining_outcome)
	if outcome == MiningOutcome.BACKTRACK_PENDING or outcome == MiningOutcome.WAITING_WAVE:
		var frontier := _find_backtrack_frontier(task)
		var frontier_status := int(frontier.get("status", FrontierSearch.BLOCKED))
		if frontier_status == FrontierSearch.READY:
			_adopt_descent_frontier(task, Vector2i(frontier.coord), int(frontier.row) + _branch_row_step(), "Selected a spread-out untried descent frontier")
			return
		if frontier_status == FrontierSearch.WAITING_WAVE:
			task.mining_outcome = MiningOutcome.WAITING_WAVE
			task.mining_outcome_reason = "No descent frontier has a safe round trip before the next wave"
			_release_all()
			return
		task.mining_outcome = MiningOutcome.BLOCKED
		task.mining_outcome_reason = str(frontier.get("reason", "No untried recorded descent frontier remains"))
		ModLoaderLog.info(task.mining_outcome_reason, LOG_NAME)
		_release_all()
		return
	if outcome == MiningOutcome.BLOCKED:
		if goal != "relic":
			_fail("No reachable physical %s remains for the active resource task" % goal)
		else:
			_release_all()
		return
	var cell: Vector2i = Level.map.getTileCoord(keeper.global_position)
	var resume_coord := Vector2i(task.resume_coord)
	if resume_coord != NO_COORD:
		var travel_position: Vector2 = Level.map.getTilePos(resume_coord)
		var reached := cell == resume_coord
		if int(task.mode) == ExploreMode.DESCEND:
			reached = reached and absf(keeper.global_position.x - travel_position.x) <= 6.0
		if reached:
			task.resume_coord = NO_COORD
			_release_all()
			_reset_progress()
			delay = 0.2
			return
		if _move_open(travel_position):
			return
		_fail("No open path remains to the search task's saved coordinate")
		return

	if int(task.mode) == ExploreMode.DESCEND:
		if int(task.branch_row) < -1000:
			task.branch_row = maxi(cell.y + _branch_row_step(), 1)
		if cell.y < int(task.branch_row):
			var below = Level.map.getTile(cell + Vector2i.DOWN)
			if below is Tile and below.type == CONST.BORDER:
				_release_all()
				task.mode = ExploreMode.BYPASS
				task.bypass_side = 1
				task.bypass_reversed = false
				_reset_progress()
				delay = 0.2
				return
			if _shaft_should_widen() and _step_wide_shaft(task, cell):
				return
			_hold([&"ui_down"])
			return
		task.branch_entry_coord = cell
		task.active_corridor_cells.clear()
		task.active_corridor_cells[cell] = true
		task.mode = ExploreMode.BRANCH
	if int(task.mode) == ExploreMode.BYPASS:
		var bypass_below = Level.map.getTile(cell + Vector2i.DOWN)
		if not (bypass_below is Tile and bypass_below.type == CONST.BORDER):
			_adopt_descent_frontier(task,
				cell,
				int(task.branch_row),
				"The first lateral column that can continue downward was adopted"
			)
			return
		var bypass_next = Level.map.getTile(cell + Vector2i(int(task.bypass_side), 0))
		if bypass_next is Tile and bypass_next.type == CONST.BORDER:
			_release_all()
			if bool(task.bypass_reversed):
				_finish_terminal_descent(task, "Both lateral bypass directions ended at revealed border")
				return
			task.bypass_reversed = true
			task.bypass_side = -1
			_reset_progress()
			delay = 0.2
			return
		_hold([&"ui_right" if int(task.bypass_side) > 0 else &"ui_left"])
		return
	task.active_corridor_cells[cell] = true
	var branch_next = Level.map.getTile(cell + Vector2i(int(task.branch_side), 0))
	if branch_next is Tile and branch_next.type == CONST.BORDER:
		_release_all()
		if Vector2i(task.branch_entry_coord) == NO_COORD:
			_fail("The fishbone branch has no saved open shaft intersection")
			return
		task.branch_side = int(task.branch_side) * -1
		task.resume_coord = task.branch_entry_coord
		if int(task.branch_side) > 0:
			_record_completed_corridor(task, int(task.branch_row))
			task.attempted_descent_origins[task.branch_entry_coord] = true
			task.branch_row = int(task.branch_row) + _branch_row_step()
			task.mode = ExploreMode.DESCEND
			_reset_progress()
		delay = 0.2
		return
	_hold([&"ui_right" if int(task.branch_side) > 0 else &"ui_left"])

func _interact(task: Dictionary) -> void:
	if bool(task.get("reward_complete", false)):
		_pop_task("The interrupted artifact delivery was installed")
		return
	var target = task.get("target")
	if not is_instance_valid(target):
		_fail("The active interactable disappeared")
		return
	if str(task.kind) == "cave":
		_run_cave_task(task)
		return
	if target is Chamber and target.getTileType() == Data.TILE_RELIC_SWITCH:
		_run_relic_switch_task(task)
		return
	if target is Chamber and target.drop_type == CONST.RELIC:
		_run_relic_chamber_task(task)
		return

	var carried_artifact := _carried_artifact(task)
	if is_instance_valid(carried_artifact):
		if carried_artifact.type == CONST.POWERCORE and not is_instance_valid(task.get("gadget_drop")):
			_record("power_core_acquired", "Exact Power Core attached", null)
		task.gadget_drop = carried_artifact
		task.recovery_coord = NO_COORD
		task.wait_steps = 0
		_travel_to_station()
		return
	var artifact = task.get("gadget_drop")
	if is_instance_valid(artifact):
		if not artifact.absorbed and not artifact.independent:
			_recover_detached_artifact(task)
		else:
			_wait_for_interaction(task, "Authoritative gadget handoff did not open its mandatory choice popup")
		return
	var chamber: Chamber = target
	if chamber.drop_type == CONST.POWERCORE:
		_run_power_core_task(task)
	else:
		_mine_gadget_chamber(task)

func _run_relic_switch_task(task: Dictionary) -> void:
	var relic_switch: Chamber = task.target
	match relic_switch.currentState:
		Chamber.State.REVEALED:
			_excavate_chamber(task, relic_switch, CONST.RELICSWITCH, "Relic switch")
		Chamber.State.OPENING:
			_wait_for_interaction(task, "Relic switch did not finish opening")
		Chamber.State.OPEN:
			_activate_chamber(task, "Relic switch", false)
		Chamber.State.EMPTY:
			if is_instance_valid(relic_switch.get_node_or_null("Usable")):
				_wait_for_interaction(task, "Relic switch activation animation did not finish")
				return
			var search := _root_relic_search()
			var relic_chamber = search.get("relic_chamber")
			var focus_coord: Vector2i = Level.map.getTileCoord(keeper.global_position)
			_pop_task("The revealed relic switch was activated")
			if is_instance_valid(relic_chamber):
				var revisit := _new_chamber_interaction_task(relic_chamber, "relic chamber")
				revisit.approach_coord = _relic_chamber_revisit_coord(search, relic_chamber)
				_push_task(revisit, "A relic switch was activated; revisit the excavated Relic Chamber")
			else:
				_adopt_descent_frontier(
					search,
					focus_coord,
					focus_coord.y + _branch_row_step(),
					"An activated relic switch focused the search on its surrounding mine"
				)
		_:
			_fail("Relic switch returned to an unsupported state")

func _run_relic_chamber_task(task: Dictionary) -> void:
	if int(Data.ofOr(keeper.teamId + ".inventory.relic", 0)) > 0:
		_record("relic_delivered", "The exact final relic reached the dome", null)
		_pop_task("The final relic was delivered to the dome")
		return

	var carried_relic := _carried_artifact(task)
	if is_instance_valid(carried_relic):
		if not is_instance_valid(task.get("gadget_drop")):
			_record("relic_acquired", "The exact final relic attached to the Engineer", null)
		task.gadget_drop = carried_relic
		task.recovery_coord = NO_COORD
		task.wait_steps = 0
		_travel_to_station()
		return

	var relic = task.get("gadget_drop")
	if is_instance_valid(relic):
		if not relic.absorbed and not relic.independent:
			_recover_detached_artifact(task)
		else:
			_wait_for_interaction(task, "The final relic did not finish entering the dome")
		return

	var chamber: Chamber = task.target
	match chamber.currentState:
		Chamber.State.REVEALED:
			if is_instance_valid(chamber.tileCover) and not chamber.tileCover.get_used_cells(MapData.DEFAULT_LAYER).is_empty():
				_excavate_chamber(task, chamber, CONST.RELIC, "Relic")
				return
			var search := _root_relic_search()
			var approach_cell := Vector2i(task.get("approach_coord", NO_COORD))
			if approach_cell == NO_COORD:
				approach_cell = _relic_chamber_revisit_coord(
					search,
					chamber,
					Level.map.getTileCoord(keeper.global_position)
				)
				task.approach_coord = approach_cell
			if approach_cell == NO_COORD:
				_fail("No recorded open approach reaches the excavated Relic Chamber")
				return
			if Level.map.getTileCoord(keeper.global_position) != approach_cell:
				if not _move_open(Level.map.getTilePos(approach_cell)):
					_fail("No open path reaches the excavated Relic Chamber")
				return
			if not bool(task.get("open_check_pending", false)):
				task.open_check_pending = true
				_release_all()
				delay = 0.2
				return
			search.relic_chamber_approach = _relic_chamber_revisit_coord(search, chamber, approach_cell)
			if Vector2i(search.relic_chamber_approach) == NO_COORD:
				_fail("No revealed corridor cell can revisit the excavated Relic Chamber")
				return
			var first_discovery: bool = search.get("relic_chamber") != chamber
			search.relic_chamber = chamber
			if first_discovery:
				_record("relic_chamber_excavated", "The Relic Chamber remains locked after excavation", null)
			_pop_task("The excavated Relic Chamber has not opened")
		Chamber.State.OPENING:
			_wait_for_interaction(task, "Relic Chamber did not finish opening")
		Chamber.State.OPEN:
			_activate_chamber(task, "Relic", true)
		Chamber.State.EMPTY:
			_wait_for_interaction(task, "Activated Relic Chamber did not attach its exact relic")
		_:
			_fail("Relic Chamber returned to an unsupported state")

func _relic_chamber_revisit_coord(search: Dictionary, chamber: Chamber, live_approach := NO_COORD) -> Vector2i:
	if live_approach != NO_COORD and Level.map.pathfinder.pointIdsByCoord.has(Vector2(live_approach) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET):
		return live_approach
	var preferred := Vector2i(search.get("relic_chamber_approach", NO_COORD))
	if preferred != NO_COORD and Level.map.pathfinder.pointIdsByCoord.has(Vector2(preferred) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET):
		return preferred
	var chamber_coord := Vector2i(chamber.coord)
	var best := NO_COORD
	var best_distance := INF
	var corridor_cells: Array = [search.get("active_corridor_cells", {})]
	for corridor in search.get("completed_corridors", []):
		if corridor is Dictionary:
			corridor_cells.append(corridor.get("cells", {}))
	for cells in corridor_cells:
		if not cells is Dictionary:
			continue
		for candidate in cells:
			if not candidate is Vector2i or not Level.map.pathfinder.pointIdsByCoord.has(Vector2(candidate) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET):
				continue
			var distance := Vector2i(candidate).distance_squared_to(chamber_coord)
			if distance < best_distance:
				best = candidate
				best_distance = distance
	return best

func _mine(task: Dictionary) -> void:
	var ore := Vector2i(task.get("ore", NO_COORD))
	if ore == NO_COORD or not Level.map.getTile(ore) is Tile or not Level.map.isRevealed(ore):
		task.approach_coord = NO_COORD
		ore = _adjacent_ore(task.get("vein", []))
		task.ore = ore
	if ore == NO_COORD:
		_record_cache(task.get("vein", []))
		_pop_task("The revealed ore vein has been cleared")
		return
	var vein: Array = task.get("vein", [])
	if not vein.has(ore):
		vein.append(ore)
		task.vein = vein
		var route := _tile_interaction_route(ore)
		task.approach_coord = NO_COORD if float(route.astar_seconds) > float(route.direct_seconds) else Vector2i(route.approach_coord)
	var approach_coord := Vector2i(task.get("approach_coord", NO_COORD))
	var current_coord: Vector2i = Level.map.getTileCoord(keeper.global_position)
	if approach_coord != NO_COORD and current_coord != approach_coord:
		if _move_open(Level.map.getTilePos(approach_coord)):
			return
		task.approach_coord = NO_COORD
	elif approach_coord != NO_COORD:
		task.approach_coord = NO_COORD
	_hold(_axis(Level.map.getTilePos(ore)))

func _new_acquire_resource_task(resource_type: String, amount: int, site_minimum := 1) -> Dictionary:
	return {
		"type": TaskType.ACQUIRE_RESOURCE,
		"goal": resource_type,
		"resource_type": resource_type,
		"amount": amount,
		"site_minimum": site_minimum,
		"site": null,
		"target": null,
	}

func _carried_resource(resource_type: String) -> Drop:
	for candidate in keeper.carriedCarryables:
		if candidate is Drop and candidate.type == resource_type and candidate.carryableType == "resource":
			return candidate
	return null

func _carried_resource_count(resource_type: String) -> int:
	return keeper.carriedCarryables.filter(func(candidate):
		return candidate is Drop and candidate.type == resource_type and candidate.carryableType == "resource"
	).size()

func _resource_site(resource_type: String, minimum: int) -> Variant:
	var resources := _cached_resources()
	var best = null
	var best_distance := INF
	for site in caches:
		var count := resources.filter(func(drop):
			return drop.type == resource_type and drop.global_position.distance_to(site) <= GameWorld.TILE_SIZE * 3.0
		).size()
		if count < minimum:
			continue
		var distance := _path_distance(keeper.global_position, site)
		if distance < best_distance:
			best = site
			best_distance = distance
	return best

func _acquire_resource(task: Dictionary) -> void:
	var resource_type := str(task.resource_type)
	if _carried_resource_count(resource_type) >= int(task.amount):
		_pop_task("The requested physical %s is attached" % resource_type)
		return
	var carried_resources := keeper.carriedCarryables.filter(func(candidate):
		return candidate is Drop and candidate.carryableType == "resource"
	)
	if not carried_resources.is_empty() and carried_resources.size() >= _full_load_count(_carry_loss()):
		_travel_to_station()
		return
	var site = task.get("site")
	if not site is Vector2:
		site = _resource_site(resource_type, int(task.site_minimum))
		if not site is Vector2:
			var search := _new_search_task(resource_type, int(task.site_minimum))
			var root_search := _root_relic_search()
			if not root_search.is_empty():
				var shaft_coord := Vector2i(root_search.get("resume_coord", NO_COORD))
				var branch_entry := Vector2i(root_search.get("branch_entry_coord", NO_COORD))
				if int(root_search.get("mode", ExploreMode.DESCEND)) == ExploreMode.BRANCH and branch_entry != NO_COORD:
					shaft_coord = branch_entry
				search.resume_coord = shaft_coord
			_push_task(search, "No known cache contains enough %s" % resource_type)
			return
		task.site = site
	var target = task.get("target")
	if not _available_resource(target, resource_type) or target.global_position.distance_to(site) > GameWorld.TILE_SIZE * 3.0:
		target = null
		var best_distance := INF
		for candidate in _cached_resources():
			if candidate.type != resource_type or candidate.global_position.distance_to(site) > GameWorld.TILE_SIZE * 3.0:
				continue
			var distance := _path_distance(keeper.global_position, candidate.global_position)
			if distance < best_distance:
				target = candidate
				best_distance = distance
		task.target = target
	var focused = keeper.focussedCarryable
	if _available_resource(focused):
		target = focused
		task.target = focused
	if not is_instance_valid(target):
		task.site = null
		return
	if keeper.focussedCarryable == target and _leaf() == "Keeper1InputProcessor":
		if pickup_failures >= 3:
			_fail("Repeated exact %s pickup attempts failed" % resource_type)
			return
		pickup_failures += 1
		_release_all()
		_tap(&"keeper1_pickup")
		delay = CARRY_PICKUP_SECONDS
		return
	if not _move_open(target.global_position):
		_fail("No open path reaches the reserved %s" % resource_type)

func _available_resource(candidate, resource_type := "") -> bool:
	return (
		is_instance_valid(candidate)
		and candidate is Drop
		and candidate.carryableType == "resource"
		and (resource_type.is_empty() or candidate.type == resource_type)
		and not candidate.absorbed
		and not candidate.independent
		and not candidate.isCarried()
		and not _drop_targeted_by_transport(candidate)
	)

func _track_cleanup_trip(task: Dictionary, full_load: int, carried: int, cached_empty: bool) -> void:
	if not task.has("planned"):
		task.planned = full_load
	task.peak = maxi(int(task.get("peak", 0)), carried)
	var prev := int(task.get("prev_carried", -1))
	if prev >= 0 and carried < prev:
		var lost := prev - carried
		var start_frame := int(task.get("return_frame", -1))
		if _at_dome():
			task.delivered = int(task.get("delivered", 0)) + lost
			_record("cleanup_delivery", "A cleanup load reached the dome", {
				"carried": lost,
				"actual_seconds": (Engine.get_process_frames() - start_frame) / float(recording_fps) if recording_fps > 0 and start_frame >= 0 else null,
			})
		else:
			task.detachments = int(task.get("detachments", 0)) + 1
			_record("cleanup_detachment", "A carried resource detached outside the dome", {
				"before": prev, "after": carried,
				"coord": Level.map.getTileCoord(keeper.global_position),
			})
	task.prev_carried = carried
	var inside := keeper.isInsideStation
	if bool(task.get("inside", false)) and not inside:
		task.returning = false
	task.inside = inside
	if not bool(task.get("returning", false)) and carried > 0 and not inside and (carried >= full_load or cached_empty):
		task.returning = true
		task.trips = int(task.get("trips", 0)) + 1
		task.return_carried = carried
		task.return_frame = Engine.get_process_frames()
		var distance := _path_distance(keeper.global_position, _home_position())
		var speed := _effective_speed(carried, _planning_base_speed(), _carry_loss())
		_record("cleanup_return_start", "A cleanup delivery leg started", {
			"carried": carried,
			"predicted_seconds": distance / speed if is_finite(distance) and speed > 0.0 else null,
		})

func _at_dome() -> bool:
	return keeper.isInsideStation or keeper.global_position.y <= _home_position().y + 12.0

func _cleanup_resources(task: Dictionary) -> void:
	var full_load := _full_load_count(_carry_loss())
	var cached_resources := _cached_resources()
	var carried_resources := keeper.carriedCarryables.filter(func(candidate):
		return candidate is Drop and candidate.carryableType == "resource"
	)
	_track_cleanup_trip(task, full_load, carried_resources.size(), cached_resources.is_empty())
	if not carried_resources.is_empty():
		var available := _stored_upgrade_resources()
		for resource in carried_resources:
			available[resource.type] = int(available.get(resource.type, 0)) + 1
		var upgrade := _select_upgrade_target(available, false)
		var upgrade_id: String = upgrade.get("id", "")
		var funds_upgrade := not upgrade_id.is_empty() and _resource_deficits(GameWorld.upgrades[upgrade_id].get("cost", {}), available).is_empty()
		if (
			carried_resources.size() >= full_load
			or cached_resources.is_empty()
			or bool(task.get("returning", false))
			or funds_upgrade
		):
			_travel_to_station()
			return
	var target = task.get("target")
	var ignored: Dictionary = task.ignored
	if not _available_resource(target) or not cached_resources.has(target) or ignored.has(target):
		target = null
		var best_distance := INF
		for candidate in cached_resources:
			if ignored.has(candidate):
				continue
			var distance := _path_distance(keeper.global_position, candidate.global_position)
			if distance < best_distance:
				target = candidate
				best_distance = distance
		task.target = target
	if not is_instance_valid(target):
		if carried_resources.is_empty():
			_record("cleanup_trip_summary", "Cleanup finished without a reachable cached resource", {
				"planned": int(task.get("planned", 0)),
				"peak": int(task.get("peak", 0)),
				"trips": int(task.get("trips", 0)),
				"detachments": int(task.get("detachments", 0)),
				"delivered": int(task.get("delivered", 0)),
			})
			_pop_task("No reachable cached resource remains")
		else:
			_travel_to_station()
		return
	var focused = keeper.focussedCarryable
	if _available_resource(focused) and cached_resources.has(focused) and not ignored.has(focused):
		target = focused
		task.target = focused
	if int(task.get("approach_uid", -1)) != target.UID:
		task.approach_uid = target.UID
		task.closest_path_distance = INF
		task.unfocusable_time = 0.0
	var path_distance := _path_distance(keeper.global_position, target.global_position)
	if not keeper.carryables.has(target):
		if path_distance + 2.0 < float(task.closest_path_distance):
			task.closest_path_distance = path_distance
			task.unfocusable_time = 0.0
		else:
			task.unfocusable_time = float(task.unfocusable_time) + TICK
		if float(task.unfocusable_time) >= STALL_SECONDS:
			ignored[target] = true
			task.target = null
			return
	else:
		task.closest_path_distance = path_distance
		task.unfocusable_time = 0.0
	if keeper.focussedCarryable == target and _leaf() == "Keeper1InputProcessor":
		if pickup_failures >= 3:
			ignored[target] = true
			task.target = null
			pickup_failures = 0
			return
		pickup_failures += 1
		_release_all()
		_tap(&"keeper1_pickup")
		delay = CARRY_PICKUP_SECONDS
		return
	if not _move_open(target.global_position):
		ignored[target] = true
		task.target = null

func _travel_to_station() -> void:
	var main_station: DomeStation = dome.stations.front()
	var main_usable := main_station.get_meta("usable") as Node2D
	if not is_instance_valid(main_usable):
		_fail("Main Laser station has no usable target")
		return
	if keeper.focussedUsable == main_usable and _leaf() == "Keeper1InputProcessor":
		_release_all(); _tap(&"ui_select"); delay = 0.7
		return
	var entry := Vector2(dome.global_position.x, -GameWorld.TILE_SIZE) + CONST.TILE_OFFSET
	if keeper.global_position.y > entry.y + 6.0:
		if not _move_open(entry):
			_fail("No open path back to the dome")
		return
	if keeper.global_position.y > main_usable.global_position.y + 6.0:
		_hold([&"ui_up"])
		return
	_hold(_axis(main_usable.global_position))

func _upgrade(task: Dictionary) -> void:
	var leaf := _leaf()
	if leaf == "StationInputProcessor":
		if bool(task.get("closing", false)):
			_pop_task("The upgrade menu closed")
			return
		if not _freeze_upgrade_target(task):
			task.closing = true
			return
		_tap(&"dome_upgrades")
		delay = 0.6
		return
	if leaf != "UpgradesInputProcessor":
		return
	if bool(task.get("closing", false)) or str(task.get("active_id", "")).is_empty():
		_tap(&"ui_cancel"); delay = 0.5
		return

	var processor = InputSystem.getLastChild(keeper.deviceId)
	if not is_instance_valid(processor) or not is_instance_valid(processor.popup):
		_consume_upgrade_step(task, "Upgrade popup did not become available")
		return
	var tree = processor.popup.find_child("TechTree")
	if not is_instance_valid(tree):
		_consume_upgrade_step(task, "Upgrade tree did not become available")
		return
	var current = tree.focussedTechPanel
	var target = null
	for panel in get_tree().get_nodes_in_group(keeper.playerId + "-techpanel"):
		if panel.techId == task.active_id:
			target = panel
			break
	if not is_instance_valid(current) or not is_instance_valid(target):
		_consume_upgrade_step(task, "Could not find intended upgrade panel")
		return
	if current == target:
		if not _active_upgrade_ready(task):
			task.closing = true
			return
		if int(target.state) != 1:
			_consume_upgrade_step(task, "Intended upgrade panel never became buyable")
			return
		if not _consume_upgrade_step(task, "Game did not confirm intended upgrade purchase"):
			return
		_tap(&"ui_select"); delay = 0.5
		return
	if not _consume_upgrade_step(task, "Could not focus intended upgrade through normal UI actions"):
		return
	var delta: Vector2 = target.global_position - current.global_position
	if absf(delta.x) >= absf(delta.y):
		_tap(&"ui_right" if delta.x > 0.0 else &"ui_left")
	else:
		_tap(&"ui_down" if delta.y > 0.0 else &"ui_up")
	delay = 0.15

func _choose_reward(task: Dictionary, delta: float) -> void:
	var processor = InputSystem.getLastChild(keeper.deviceId)
	var is_gadget_processor := is_instance_valid(processor) and str(processor.name) == "GadgetChoiceInputProcessor"
	if InputSystem.processors_changing:
		return
	if not is_gadget_processor:
		_finish_artifact_choice(task)
		return

	task.ui_delay = maxf(float(task.get("ui_delay", 0.0)) - delta, 0.0)
	if float(task.ui_delay) > 0.0:
		return
	if not is_instance_valid(processor.popup):
		_wait_for_artifact_choice(task, "Artifact choice popup did not become available")
		return
	var popup = processor.popup
	var popup_type := StringName(str(popup.droptype))
	if popup_type != StringName(CONST.GADGET) and popup_type != StringName(CONST.POWERCORE):
		_fail("Unsupported artifact choice type: " + str(popup.droptype))
		return
	var choice_type := StringName(str(task.get("choice_type", "")))
	if choice_type.is_empty():
		task.choice_type = popup_type
		choice_type = popup_type
	elif choice_type != popup_type:
		_fail("Artifact choice type changed while the modal was open")
		return
	if not bool(popup.animationDone) or popup.offersById.is_empty():
		_wait_for_artifact_choice(task, "Artifact offers did not become available")
		return
	var offer_id := StringName(str(task.get("offer_id", "")))
	if offer_id.is_empty():
		offer_id = _choose_artifact_offer(popup, choice_type)
		task.offer_id = offer_id
		task.ui_steps = 0
		if offer_id.is_empty():
			_fail("Artifact popup has neither a supported offer nor the shred fallback")
			return

	var reroll_button = popup.find_child("RerollButton")
	var target = popup.offersById.get(String(offer_id))
	var choosing_reroll: bool = (
		not _artifact_offer_matches_current_intent(offer_id, choice_type)
		and is_instance_valid(reroll_button)
		and reroll_button.visible
		and not reroll_button.disabled
		and int(Data.getInventory(CONST.WATER, keeper.teamId)) > 0
	)
	if choosing_reroll:
		target = reroll_button

	if not is_instance_valid(target) or bool(target.disabled):
		_fail("Chosen artifact action is no longer selectable: " + String(offer_id))
		return
	if bool(task.get("confirming", false)):
		_wait_for_artifact_choice(task, "Game did not confirm artifact selection")
		return

	var current = popup.get_viewport().gui_get_focus_owner()
	if not is_instance_valid(current) or not current is Control:
		_wait_for_artifact_choice(task, "Artifact popup did not expose a focused option")
		return
	if current == target:
		var selected: Variant = popup.selectedGadget
		if choosing_reroll:
			if not selected is Dictionary or int(selected.get("reroll", 0)) != 1:
				_wait_for_artifact_choice(task, "Focused artifact reroll action did not become selected")
				return
			_record("artifact_reroll", "Unsuitable artifact offers rerolled through the normal UI", null)
			_tap(&"ui_select")
			task.offer_id = StringName()
			task.ui_steps = 0
			task.ui_delay = 0.5
			return
		if not selected is Dictionary or StringName(str(selected.get("id", ""))) != offer_id:
			_wait_for_artifact_choice(task, "Focused artifact offer did not become selected")
			return
		_tap(&"ui_select")
		task.confirming = true
		task.ui_steps = 0
		task.ui_delay = TICK
		return

	if not _consume_artifact_ui_step(task, "Could not focus the chosen artifact action through normal UI actions"):
		return
	var options = popup.find_child("Gadgets")
	if not is_instance_valid(options):
		_fail("Artifact popup has no options container")
		return
	if choosing_reroll and current.get_parent() == options:
		_tap(&"ui_up")
		task.ui_delay = 0.15
		return
	if not choosing_reroll and current.get_parent() != options:
		_tap(&"ui_down")
		task.ui_delay = 0.15
		return
	var focus_delta: Vector2 = target.global_position - current.global_position
	if absf(focus_delta.x) >= absf(focus_delta.y):
		_tap(&"ui_right" if focus_delta.x > 0.0 else &"ui_left")
	else:
		_tap(&"ui_down" if focus_delta.y > 0.0 else &"ui_up")
	task.ui_delay = 0.15

func _choose_artifact_offer(popup, choice_type: StringName) -> StringName:
	var catalog = SUPPLEMENT_CATALOG if choice_type == StringName(CONST.POWERCORE) else GADGET_CATALOG
	var supported: Array[StringName] = []
	for offered_value in popup.offersById.keys():
		var offered_id := StringName(str(offered_value))
		var panel = popup.offersById[offered_value]
		if is_instance_valid(panel) and not bool(panel.disabled) and catalog.is_supported(offered_id):
			supported.append(offered_id)
	supported.sort_custom(func(left: StringName, right: StringName):
		var left_base := String(catalog.base_id(left))
		var right_base := String(catalog.base_id(right))
		return String(left) < String(right) if left_base == right_base else left_base < right_base
	)
	var target := _next_upgrade_target(false)
	if not target.is_empty():
		var benefit := _artifact_benefit_for_intent(int(target["intent"]))
		for offered_id in supported:
			if catalog.benefit_mask(offered_id) & benefit != 0:
				return offered_id
	if not supported.is_empty():
		return supported.front()
	if popup.offersById.has(String(catalog.SHRED_ID)):
		return catalog.SHRED_ID
	return StringName()

func _artifact_offer_matches_current_intent(offered_id: StringName, choice_type: StringName) -> bool:
	var catalog = SUPPLEMENT_CATALOG if choice_type == StringName(CONST.POWERCORE) else GADGET_CATALOG
	if catalog.is_shred(offered_id) or not catalog.is_supported(offered_id):
		return false
	var target := _next_upgrade_target(false)
	if target.is_empty():
		return true
	var benefit := _artifact_benefit_for_intent(int(target["intent"]))
	return catalog.benefit_mask(offered_id) & benefit != 0

func _artifact_benefit_for_intent(intent: int) -> int:
	match intent:
		UpgradeIntent.COMBAT:
			return GADGET_CATALOG.Benefit.COMBAT
		UpgradeIntent.REPAIR:
			return GADGET_CATALOG.Benefit.SURVIVAL_REPAIR
		UpgradeIntent.DRILL:
			return GADGET_CATALOG.Benefit.DRILLING
		UpgradeIntent.MOBILITY:
			if mobility_arm == MobilityArm.SPEED:
				return GADGET_CATALOG.Benefit.MOVEMENT
			return GADGET_CATALOG.Benefit.CARRYING_LOGISTICS
	return GADGET_CATALOG.Benefit.NONE

func _consume_artifact_ui_step(task: Dictionary, reason: String) -> bool:
	task.ui_steps = int(task.get("ui_steps", 0)) + 1
	if int(task.ui_steps) <= ARTIFACT_UI_STEP_LIMIT:
		return true
	_fail(reason)
	return false

func _wait_for_artifact_choice(task: Dictionary, reason: String) -> void:
	if _consume_artifact_ui_step(task, reason):
		task.ui_delay = TICK

func _finish_artifact_choice(task: Dictionary) -> void:
	var selected_id := StringName(str(task.get("offer_id", "")))
	var was_confirming := bool(task.get("confirming", false))
	var selected_type := StringName(str(task.get("choice_type", "")))
	if not was_confirming:
		_fail("Artifact choice closed before the teacher submitted a selection")
		return
	var catalog = SUPPLEMENT_CATALOG if selected_type == StringName(CONST.POWERCORE) else GADGET_CATALOG
	if not catalog.is_shred(selected_id) and not GameWorld.boughtUpgrades.has(String(selected_id)):
		_fail("Selected artifact upgrade was not installed: " + String(selected_id))
		return
	var base_id := String(catalog.base_id(selected_id))
	if selected_type == StringName(CONST.POWERCORE):
		var supplement_reason := "Supplement offer shredded" if catalog.is_shred(selected_id) else "Supplement selected: " + base_id
		_record("supplement_choice", supplement_reason, null)
	else:
		var gadget_reason := "Gadget offer shredded" if catalog.is_shred(selected_id) else "Gadget selected: " + base_id
		_record("gadget_choice", gadget_reason, null)
	_pop_task("The mandatory artifact choice was confirmed")
	var interaction := _find_task(TaskType.INTERACT)
	if (
		not interaction.is_empty()
		and str(interaction.get("kind", "")) == "chamber"
		and is_instance_valid(interaction.get("target"))
		and StringName(interaction.target.drop_type) == selected_type
	):
		interaction.reward_complete = true
	if _task_is(TaskType.INTERACT) and bool(tasks.back().get("reward_complete", false)):
		_pop_task("The artifact was delivered and installed")

func _scan_interaction(required_ore_type := "") -> bool:
	var claimed := (
		_claim_relic_switch_interaction()
		or _claim_chamber_interaction(CONST.RELIC)
		or _claim_chamber_interaction(CONST.POWERCORE)
		or _claim_chamber_interaction(CONST.GADGET)
		or _claim_cave_interaction()
	)
	if claimed:
		return true
	return _claim_ore_interaction("" if required_ore_type == "relic" else required_ore_type)

func _target_is_claimed(target: Variant) -> bool:
	for task in tasks:
		if target is Vector2i:
			var ore = task.get("ore")
			if ore is Vector2i and ore == target:
				return true
		else:
			var interaction_target = task.get("target")
			if is_instance_valid(interaction_target) and interaction_target == target:
				return true
	return false

func _claim_relic_switch_interaction() -> bool:
	var best: Chamber
	var best_distance := INF
	var best_plan := {}
	for candidate in Level.map.tiles_node.get_children():
		if (
			not candidate is Chamber
			or candidate.getTileType() != Data.TILE_RELIC_SWITCH
			or candidate.currentState != Chamber.State.REVEALED
			or _target_is_claimed(candidate)
		):
			continue
		var distance := keeper.global_position.distance_to(candidate.global_position) / GameWorld.TILE_SIZE
		if distance >= INTERACTION_RADIUS_TILES:
			continue
		var plan := _chamber_cover_plan(candidate, CONST.RELICSWITCH)
		if not plan.has("astar_seconds") or not Level.map.isRevealed(Vector2i(plan.target)):
			continue
		if distance < best_distance:
			best = candidate
			best_distance = distance
			best_plan = plan
	if not is_instance_valid(best):
		return false
	_record_interaction_decision("chamber", "relic switch", Vector2i(best.coord), best_distance, best_plan)
	_push_task(
		_new_chamber_interaction_task(best, "relic switch"),
		"A revealed Relic Switch Chamber is inside the interaction scan"
	)
	return true

func _new_chamber_interaction_task(target: Chamber, label: String) -> Dictionary:
	return {
		"type": TaskType.INTERACT,
		"kind": "chamber",
		"label": label,
		"target": target,
		"resource": null,
		"gadget_drop": null,
		"recovery_coord": NO_COORD,
		"recovery_attempts": 0,
		"wait_steps": 0,
		"prior_drop_uids": {},
	}

func _claim_chamber_interaction(tile_type: String) -> bool:
	var remembered_relic_chamber = _root_relic_search().get("relic_chamber")
	var best: Chamber
	var best_distance := INF
	var best_plan := {}
	for candidate in get_tree().get_nodes_in_group("chamber"):
		if not candidate is Chamber or candidate.drop_type != tile_type or _target_is_claimed(candidate):
			continue
		if tile_type == CONST.RELIC and candidate == remembered_relic_chamber:
			continue
		if tile_type == CONST.GADGET and candidate.type != CONST.GADGET:
			continue
		if candidate.currentState != Chamber.State.REVEALED:
			continue
		var distance := keeper.global_position.distance_to(candidate.global_position) / GameWorld.TILE_SIZE
		if distance >= INTERACTION_RADIUS_TILES:
			continue
		var plan := _chamber_cover_plan(candidate, tile_type)
		if not plan.has("astar_seconds") or not Level.map.isRevealed(Vector2i(plan.target)):
			continue
		if distance < best_distance:
			best = candidate
			best_distance = distance
			best_plan = plan
	if not is_instance_valid(best):
		return false
	var subtype := "supply" if tile_type == CONST.POWERCORE else "relic" if tile_type == CONST.RELIC else "gadget"
	_record_interaction_decision("chamber", subtype, Vector2i(best.coord), best_distance, best_plan)
	_push_task(
		_new_chamber_interaction_task(best, subtype + " chamber"),
		"A revealed %s Chamber is inside the interaction scan" % subtype.capitalize()
	)
	return true

func _run_power_core_task(task: Dictionary) -> void:
	var chamber: Chamber = task.target
	if not is_instance_valid(chamber):
		_fail("The active Power Core chamber disappeared")
		return
	if is_instance_valid(chamber.tileCover) and not chamber.tileCover.get_used_cells(MapData.DEFAULT_LAYER).is_empty():
		_excavate_chamber(task, chamber, CONST.POWERCORE, "Power Core")
		return
	var grabber = chamber.find_child("ResourceGrabber")
	if not is_instance_valid(grabber):
		_fail("Power Core chamber has no ResourceGrabber")
		return
	if bool(grabber.spent) and is_instance_valid(task.get("resource")):
		_record("power_core_water", "Power Core chamber accepted its physical water", null)
		task.resource = null
		task.wait_steps = 0
	if not bool(grabber.spent):
		if not _prepare_power_core_receiver(task, grabber):
			return
		var water := _carried_resource(CONST.WATER)
		if not is_instance_valid(water):
			_push_task(_new_acquire_resource_task(CONST.WATER, 1), "The Power Core chamber requires one water")
			return
		task.resource = water
		_deliver_power_core_water(task)
		return
	if chamber.currentState == Chamber.State.OPEN:
		_activate_chamber(task, "Power Core", true)
		return
	if chamber.currentState == Chamber.State.EMPTY:
		_wait_for_interaction(task, "Activated Power Core chamber did not attach its core")
		return
	_wait_for_interaction(task, "Power Core chamber did not finish opening")

func _prepare_power_core_receiver(task: Dictionary, grabber: ResourceGrabber) -> bool:
	var target: Vector2i = Level.map.getTileCoord(grabber.global_position) + Vector2i.UP
	var tile = Level.map.getTile(target)
	if not tile is Tile:
		if is_finite(_path_distance(keeper.global_position, Level.map.getTilePos(target))):
			return true
		_wait_for_interaction(task, "The Power Core water receiver cap is not confirmed open")
		return false
	if (
		not ARTIFACT_CLEARANCE_TILE_TYPES.has(tile.type)
		or not tile.get_meta("destructable", false)
	):
		_fail("The Power Core water receiver is blocked by an unsupported tile")
		return false
	var target_position: Vector2 = Level.map.getTilePos(target)
	if (
		ORE_TYPES.has(tile.type)
		and caches.all(func(existing): return existing.distance_to(target_position) > GameWorld.TILE_SIZE)
	):
		_record_cache_site(target_position)

	var route := _tile_interaction_route(target)
	task.wait_steps = 0
	var approach := (
		NO_COORD
		if float(route.astar_seconds) > float(route.direct_seconds)
		else Vector2i(route.approach_coord)
	)
	if approach != NO_COORD and Level.map.getTileCoord(keeper.global_position) != approach:
		if not _move_open(Level.map.getTilePos(approach)):
			_fail("The Power Core water receiver clearance approach became unreachable")
			return false
		return false
	_hold(_axis(Level.map.getTilePos(target)))
	return false

func _deliver_power_core_water(task: Dictionary) -> void:
	var grabber = task.target.find_child("ResourceGrabber")
	if not is_instance_valid(grabber):
		_fail("Power Core chamber has no ResourceGrabber")
		return
	var delivery_approach: Vector2i = Level.map.getTileCoord(grabber.global_position) + Vector2i.UP
	if Level.map.getTileCoord(keeper.global_position) != delivery_approach:
		if not _move_open(Level.map.getTilePos(delivery_approach)):
			_wait_for_interaction(task, "No open path reaches the Power Core water receiver")
		return
	var actions := _axis(grabber.global_position)
	if not actions.is_empty():
		_hold(actions)
		task.wait_steps = 0
		return
	_wait_for_interaction(task, "No open path reaches the Power Core water receiver")

func _claim_cave_interaction() -> bool:
	var best: Cave
	var best_kind := CaveTaskKind.NONE
	var best_distance := INTERACTION_RADIUS_TILES
	var best_astar_seconds := INF
	var best_direct_seconds := INF
	var best_approach_coord := NO_COORD
	var speed := _effective_speed(
		keeper.carriedCarryables.size(),
		_planning_base_speed(),
		_carry_loss()
	)
	for candidate in get_tree().get_nodes_in_group("cave"):
		if not candidate is Cave or candidate.currentState != Cave.State.REVEALED or _target_is_claimed(candidate):
			continue
		var candidate_kind := _supported_cave_kind(candidate)
		if candidate_kind == CaveTaskKind.NONE or not _cave_is_unfinished(candidate, candidate_kind):
			continue
		var distance := (
			keeper.global_position.distance_to(candidate.global_position)
			/ GameWorld.TILE_SIZE
		)
		if distance >= best_distance:
			continue
		var route := _cave_route(candidate, speed)
		var astar_seconds: float = route.astar_seconds
		var direct_seconds: float = route.direct_seconds
		if not is_finite(astar_seconds) and not is_finite(direct_seconds):
			continue
		best = candidate
		best_kind = candidate_kind
		best_distance = distance
		best_astar_seconds = astar_seconds
		best_direct_seconds = direct_seconds
		best_approach_coord = route.approach_coord

	if not is_instance_valid(best):
		return false
	var label := str(CaveTaskKind.keys()[best_kind]).to_lower().replace("_", " ")
	var route := {
		"approach_coord": best_approach_coord,
		"astar_seconds": best_astar_seconds,
		"direct_seconds": best_direct_seconds,
	}
	var task := {
		"type": TaskType.INTERACT,
		"kind": "cave",
		"label": label + " cave",
		"target": best,
		"cave_kind": best_kind,
		"resource": null,
		"scanner_receiver": null,
		"activation_pending": false,
		"wait_steps": 0,
		"approach_coord": NO_COORD if best_astar_seconds > best_direct_seconds else best_approach_coord,
		"harvest_targets": [],
		"prior_drop_uids": {},
		"resource_type": "",
		"observed_value": 0.0,
	}
	if _is_resource_cave_kind(best_kind):
		task.resource_type = RESOURCE_CAVE_DROP_TYPES[best_kind]
		for path in RESOURCE_CAVE_REWARD_PATHS[best_kind]:
			var reward := best.get_node_or_null(path) as Node2D
			if not is_instance_valid(reward) or reward.get("taken") == null:
				_fail("The claimed resource cave does not expose its exact reward nodes")
				return false
			if not bool(reward.get("taken")):
				task.harvest_targets.append(path)
		if task.harvest_targets.is_empty():
			_fail("The claimed resource cave has no available rewards to snapshot")
			return false
	_record_interaction_decision("cave", label, Vector2i(best.coord), best_distance, route)
	_push_task(task, "A revealed %s Cave is inside the interaction scan" % label)
	return true

func _cave_route(candidate: Cave, speed: float) -> Dictionary:
	var astar_seconds := INF
	var approach_coord := NO_COORD
	var footprint := {}
	for offset in candidate.tileCoords:
		footprint[Vector2i(candidate.coord + offset)] = true
	for cell in footprint:
		for offset in CARDINAL_OFFSETS:
			var boundary: Vector2i = cell + offset
			if footprint.has(boundary) or not Level.map.visibleTileCoords.has(boundary):
				continue
			var pathfinder_coord := Vector2(boundary) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
			if not Level.map.pathfinder.pointIdsByCoord.has(pathfinder_coord):
				continue
			var seconds := _path_distance(
				keeper.global_position,
				Level.map.getTilePos(boundary)
			) / speed
			if seconds < astar_seconds:
				astar_seconds = seconds
				approach_coord = boundary
	var direct_seconds := INF
	for cell in footprint:
		direct_seconds = minf(
			direct_seconds,
			_direct_approach_seconds(cell, speed, 1)
		)
	return {
		"approach_coord": approach_coord,
		"astar_seconds": astar_seconds,
		"direct_seconds": direct_seconds,
	}

func _supported_cave_kind(candidate: Cave) -> CaveTaskKind:
	var script = candidate.get_script()
	if not script is Script:
		return CaveTaskKind.NONE
	return CAVE_KINDS_BY_SCRIPT.get(script.resource_path, CaveTaskKind.NONE)

func _cave_is_unfinished(candidate: Cave, kind: CaveTaskKind) -> bool:
	match kind:
		CaveTaskKind.SCANNER:
			return bool(candidate.get("hasScanner"))
		CaveTaskKind.DRONE:
			return bool(candidate.get("hasDrone"))
		CaveTaskKind.MUSHROOM, CaveTaskKind.HELMET:
			return candidate.canFocusUse(keeper)
		CaveTaskKind.PORTAL:
			return (
				keeper.carriedCarryables.any(func(item): return item is Drop and item.type in ORE_TYPES and item.carryableType == "resource")
				or not _cached_resources().is_empty()
			)
		CaveTaskKind.IRON_TREE, CaveTaskKind.COBALT, CaveTaskKind.WATER:
			for path in RESOURCE_CAVE_REWARD_PATHS[kind]:
				var reward := candidate.get_node_or_null(path) as Node2D
				if is_instance_valid(reward) and reward.get("taken") != null and not bool(reward.get("taken")):
					return true
	return false

func _is_resource_cave_kind(kind: CaveTaskKind) -> bool:
	return RESOURCE_CAVE_DROP_TYPES.has(kind)

func _run_cave_task(task: Dictionary) -> void:
	if not is_instance_valid(task.get("target")):
		_fail("The active natural cave disappeared")
		return
	match int(task.cave_kind):
		CaveTaskKind.SCANNER:
			_run_scanner_cave_task(task)
		CaveTaskKind.DRONE:
			_run_drone_cave_task(task)
		CaveTaskKind.MUSHROOM:
			_run_mushroom_cave_task(task)
		CaveTaskKind.PORTAL:
			_run_portal_cave_task(task)
		CaveTaskKind.HELMET:
			_run_helmet_cave_task(task)
		CaveTaskKind.IRON_TREE, CaveTaskKind.COBALT, CaveTaskKind.WATER:
			_run_resource_cave_task(task)
		_:
			_fail("The active natural cave kind is unsupported")

func _run_scanner_cave_task(task: Dictionary) -> void:
	var cave: Cave = task.target
	var reveal_distance := float(Data.of("map.revealdistance"))
	if bool(task.activation_pending) or cave.canFocusUse(keeper):
		_run_observed_cave_task(
			task,
			reveal_distance,
			reveal_distance > float(task.observed_value),
			"Scanner",
			"increase reveal distance"
		)
		return
	var carried_iron := keeper.carriedCarryables.filter(
		func(item): return item is Drop and item.type == CONST.IRON
	)
	var receiver = task.get("scanner_receiver")
	if is_instance_valid(receiver):
		if carried_iron.is_empty():
			_wait_for_interaction(task, "Scanner cave did not become usable after accepting two iron")
			return
		if _move_to_cave(receiver.global_position):
			task.wait_steps = 0
			return
		task.scanner_receiver = _scanner_receiver(task, receiver)
		if is_instance_valid(task.scanner_receiver) and _move_to_cave(task.scanner_receiver.global_position):
			task.wait_steps = 0
			return
		_wait_for_interaction(task, "No route crosses both Scanner cave receivers")
		return
	if carried_iron.size() >= 2:
		task.scanner_receiver = _scanner_receiver(task)
		if not is_instance_valid(task.scanner_receiver):
			_fail("Scanner cave does not expose two resource receiver positions")
			return
		if _move_to_cave(task.scanner_receiver.global_position):
			task.wait_steps = 0
		else:
			_wait_for_interaction(task, "No route reaches a Scanner cave receiver")
		return
	_push_task(_new_acquire_resource_task(CONST.IRON, 2, 3), "The Scanner cave requires two iron from a cache containing more than two")

func _scanner_receiver(task: Dictionary, excluded = null) -> ResourceGrabber:
	var selected: ResourceGrabber
	var best_distance := -1.0
	for candidate in [task.target.get("leftRes"), task.target.get("rightRes")]:
		if not candidate is ResourceGrabber or candidate == excluded:
			continue
		var distance := keeper.global_position.distance_squared_to(candidate.global_position)
		if distance > best_distance:
			selected = candidate
			best_distance = distance
	return selected

func _run_drone_cave_task(task: Dictionary) -> void:
	var cave: Cave = task.target
	if not bool(cave.get("hasDrone")):
		if bool(cave.get("opening")) or not _drone_cave_has_owned_squidley(cave):
			_wait_for_interaction(task, "Drone cave finished opening without an owned Squidley")
			return
		_finish_cave_task(task, "Drone cave spawned its owned Squidley")
		return
	var receiver := cave.get_node_or_null("ResourceGrabber") as ResourceGrabber
	if not is_instance_valid(receiver):
		_fail("Drone cave does not expose its exact water receiver")
		return
	if bool(receiver.spent):
		task.resource = null
		_wait_for_interaction(task, "Drone cave did not finish spawning its Squidley")
		return
	_run_cave_resource_delivery(task, CONST.WATER, "Drone cave", receiver)

func _run_mushroom_cave_task(task: Dictionary) -> void:
	var speed := _planning_base_speed()
	_run_observed_cave_task(
		task,
		speed,
		speed > float(task.observed_value),
		"Mushroom",
		"increase keeper movement speed"
	)

func _run_helmet_cave_task(task: Dictionary) -> void:
	var zoom := float(Data.of(keeper.playerId + ".keeper.zoominmine"))
	_run_observed_cave_task(
		task,
		zoom,
		not is_equal_approx(zoom, float(task.observed_value)),
		"Helmet",
		"change the mine camera zoom"
	)

func _run_observed_cave_task(
	task: Dictionary,
	observed_value: float,
	success: bool,
	label: String,
	change: String,
) -> void:
	if bool(task.activation_pending):
		if success:
			_finish_cave_task(task,
				"%s interaction did %s" % [label, change],
				{"after": observed_value, "before": task.observed_value}
			)
		else:
			_fail_cave_interaction(task,
				"%s interaction did not %s" % [label, change],
				observed_value
			)
		return
	_activate_observed_cave(task, observed_value)

func _activate_observed_cave(task: Dictionary, observed_value: float) -> void:
	var cave: Cave = task.target
	var usable := cave.get_node_or_null("Usable") as Node2D
	if not is_instance_valid(usable) or not cave.canFocusUse(keeper):
		_fail_cave_interaction(task, "The cave is no longer ready for interaction", observed_value)
		return
	if keeper.focussedUsable == usable and _leaf() == "Keeper1InputProcessor":
		_release_all()
		task.observed_value = observed_value
		task.activation_pending = true
		_tap(&"ui_select")
		delay = 0.2
		return
	if not _move_to_cave(usable.global_position):
		_fail_cave_interaction(task, "Neither approach can reach the cave", observed_value)

func _run_portal_cave_task(task: Dictionary) -> void:
	var target := task.target.get_node_or_null("TeleportArea") as Node2D
	if not is_instance_valid(target):
		_fail_cave_interaction(task, "The Portal no longer exposes its passive entrance")
		return
	if bool(task.activation_pending):
		var inventory := float(Data.getInventory(task.resource_type, keeper.teamId))
		var still_carried := (
			is_instance_valid(task.get("resource"))
			and keeper.carriedCarryables.has(task.resource)
		)
		if not still_carried and inventory > float(task.observed_value):
			_finish_cave_task(task,
				"Portal interaction increased stored %s" % task.resource_type,
				{
					"after": inventory,
					"before": task.observed_value,
					"detached": true,
					"resource_type": task.resource_type,
				}
			)
			return
		if still_carried and _move_to_cave(target.global_position):
			task.wait_steps = 0
			return
		_release_all()
		task.wait_steps = int(task.wait_steps) + 1
		if int(task.wait_steps) > INTERACTION_WAIT_LIMIT:
			_fail_cave_interaction(task,
				"Portal interaction did not increase stored %s" % task.resource_type,
				inventory
			)
		return
	if not _select_portal_resource(task):
		_fail_cave_interaction(task, "No reachable ordinary resource is available in a known cache")
		return
	if keeper.carriedCarryables.has(task.resource):
		task.resource_type = task.resource.type
		task.observed_value = float(Data.getInventory(task.resource_type, keeper.teamId))
		task.activation_pending = true
		task.wait_steps = 0
		return
	_push_task(_new_acquire_resource_task(task.resource.type, 1), "The Portal cave requires one cached resource")

func _select_portal_resource(task: Dictionary) -> bool:
	if (
		is_instance_valid(task.get("resource"))
		and task.resource.type in ORE_TYPES
		and not task.resource.absorbed
		and not task.resource.independent
	):
		return true
	task.resource = null
	for candidate in keeper.carriedCarryables:
		if (
			candidate is Drop
			and candidate.type in ORE_TYPES
			and not candidate.absorbed
			and not candidate.independent
		):
			task.resource = candidate
			return true
	var best_distance := INF
	for candidate in _cached_resources():
		if candidate.type not in ORE_TYPES:
			continue
		var distance := _path_distance(keeper.global_position, candidate.global_position)
		if distance >= best_distance:
			continue
		task.resource = candidate
		best_distance = distance
	return is_instance_valid(task.get("resource"))

func _fail_cave_interaction(task: Dictionary, reason: String, observed_value = null) -> void:
	var evidence = null
	if observed_value != null:
		evidence = {"after": observed_value, "before": task.observed_value}
	_record("cave_interaction_failed", reason, evidence)
	_pop_task(reason)

func _run_resource_cave_task(task: Dictionary) -> void:
	var label := str(CaveTaskKind.keys()[int(task.cave_kind)]).to_lower().replace("_", " ")
	if str(task.resource_type).is_empty():
		_fail("The active resource cave has no exact physical reward type")
		return

	if is_instance_valid(task.get("resource")):
		if keeper.carriedCarryables.has(task.resource):
			if keeper.carriedCarryables.size() != 1:
				_fail("The %s cave reward attached to a non-exclusive load" % label)
				return
			if int(task.wait_steps) >= INTERACTION_WAIT_LIMIT:
				_fail("The %s cave reward did not detach through configured input" % label)
				return
			_release_all()
			_tap(&"keeper1_drop")
			task.wait_steps = int(task.wait_steps) + 1
			delay = 0.2
			return
		if task.resource.isCarried():
			_fail("The %s cave reward attached to an unexpected carrier" % label)
			return
		if task.resource.absorbed or task.resource.independent:
			_queue_record("The released resource cave reward entered ordinary resource routing")
		else:
			_record_cache_site(task.resource.global_position)
		task.resource = null
		task.wait_steps = 0

	if task.harvest_targets.is_empty():
		_finish_cave_task(task, "%s cave released every reward in its initial snapshot" % label.capitalize())
		return

	if bool(task.activation_pending):
		var spawned := _new_resource_cave_drop(task, task.resource_type)
		if is_instance_valid(spawned) and _accept_pending_resource_cave_drop(task, spawned):
			return
		if not running:
			return
		_wait_for_interaction(task, "The %s cave did not attach its exact physical reward" % label)
		return

	if not keeper.carriedCarryables.is_empty():
		_drop_interaction_cargo()
		return

	var reward := task.target.get_node_or_null(task.harvest_targets.front()) as Node2D
	if not is_instance_valid(reward) or reward.get("taken") == null:
		_fail("The %s cave lost a snapshotted reward node" % label)
		return
	if bool(reward.get("taken")):
		_fail("A snapshotted %s cave reward was consumed outside its exact interaction" % label)
		return
	var usable := reward.get_node_or_null("Usable") as Node2D
	if not is_instance_valid(usable) or not reward.has_method(&"canFocusUse"):
		_fail("The %s cave reward does not expose its exact usable" % label)
		return
	if is_instance_valid(keeper.focussedUsable):
		for index in range(1, task.harvest_targets.size()):
			var focused_reward := task.target.get_node_or_null(task.harvest_targets[index]) as Node2D
			if (
				is_instance_valid(focused_reward)
				and focused_reward.get_node_or_null("Usable") == keeper.focussedUsable
			):
				var focused_path: NodePath = task.harvest_targets[index]
				task.harvest_targets.remove_at(index)
				task.harvest_targets.push_front(focused_path)
				reward = focused_reward
				usable = keeper.focussedUsable
				break
	if not bool(reward.call(&"canFocusUse", keeper)):
		_wait_for_interaction(task, "The snapshotted %s cave reward is not usable" % label)
		return
	if keeper.focussedUsable == usable and _leaf() == "Keeper1InputProcessor":
		_release_all()
		task.prior_drop_uids.clear()
		for candidate in Level.drops.get_all_drops().values():
			if candidate is Drop and candidate.type == task.resource_type:
				task.prior_drop_uids[candidate.UID] = true
		task.activation_pending = true
		task.wait_steps = 0
		_tap(&"ui_select")
		delay = 0.2
		return
	if Level.map.getTileCoord(keeper.global_position) == Level.map.getTileCoord(usable.global_position):
		var actions := _axis(usable.global_position)
		if not actions.is_empty():
			_hold(actions)
			task.wait_steps = 0
			return
		_wait_for_interaction(task, "The %s cave reward did not receive exact usable focus" % label)
		return
	if _move_to_cave(usable.global_position):
		task.wait_steps = 0
		return
	if Vector2i(task.approach_coord) == NO_COORD:
		_fail("The %s cave does not have a saved open interaction approach" % label)
		return
	if _move_open(Level.map.getTilePos(task.approach_coord)):
		task.wait_steps = 0
		return
	_fail("No open path reaches the %s cave interaction approach" % label)

func _new_resource_cave_drop(task: Dictionary, drop_type: String) -> Drop:
	var spawned: Drop
	for candidate in Level.drops.get_all_drops().values():
		if (
			candidate is Drop
			and candidate.type == drop_type
			and not task.prior_drop_uids.has(candidate.UID)
			and not candidate.absorbed
			and not candidate.independent
		):
			if is_instance_valid(spawned):
				_fail("The resource cave activation produced multiple exact reward candidates")
				return null
			spawned = candidate
	return spawned

func _accept_pending_resource_cave_drop(task: Dictionary, drop: Drop) -> bool:
	if not _is_resource_cave_kind(int(task.cave_kind)) or not bool(task.activation_pending):
		return false
	if (
		task.harvest_targets.is_empty()
		or drop.type != task.resource_type
		or task.prior_drop_uids.has(drop.UID)
	):
		return false
	var reward := task.target.get_node_or_null(task.harvest_targets.front()) as Node2D
	if not is_instance_valid(reward) or not bool(reward.get("taken")):
		_fail("The resource cave attached a reward without consuming the exact snapshotted node")
		return true
	task.resource = drop
	task.harvest_targets.pop_front()
	task.prior_drop_uids.clear()
	task.activation_pending = false
	task.wait_steps = 0
	_queue_record("The resource cave attached its exact physical reward")
	return true

func _run_cave_resource_delivery(task: Dictionary, required_type: String, owner_label: String, receiver: ResourceGrabber) -> void:
	if not is_instance_valid(receiver) or bool(receiver.spent):
		_wait_for_interaction(task, "%s lost its unspent physical-resource receiver" % owner_label)
		return
	var resource := _carried_resource(required_type)
	if not is_instance_valid(resource):
		_push_task(_new_acquire_resource_task(required_type, 1), "%s requires one %s" % [owner_label, required_type])
		return
	if task.resource != resource:
		task.resource = resource
		task.receiver_passes = 0
	_deliver_cave_resource(task, owner_label, receiver)

func _deliver_cave_resource(task: Dictionary, owner_label: String, receiver: ResourceGrabber) -> void:
	if not keeper.carriedCarryables.has(task.resource):
		task.resource = null
		_wait_for_interaction(task, "The reserved %s resource attached to an unexpected carrier" % owner_label)
		return
	var receiver_coord: Vector2i = Level.map.getTileCoord(receiver.global_position)
	if Level.map.getTileCoord(keeper.global_position) != receiver_coord:
		if _move_to_cave(receiver.global_position):
			task.wait_steps = 0
			return
		_wait_for_interaction(task, "No open path reaches the %s resource receiver" % owner_label)
		return
	var actions := _axis(receiver.global_position)
	if not actions.is_empty():
		_hold(actions)
		task.wait_steps = 0
		return
	# The keeper reached the exact receiver position while the carried line
	# still trails behind; back off to an adjacent open tile so the trailing
	# drops drag across the receiver instead of failing at the first stop.
	task.receiver_passes = int(task.get("receiver_passes", 0)) + 1
	if int(task.receiver_passes) > 30:
		_wait_for_interaction(task, "The %s receiver did not accept its exact physical resource" % owner_label)
		return
	for offset in CARDINAL_OFFSETS:
		var side_pos := Vector2(receiver_coord + offset) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
		if not Level.map.pathfinder.pointIdsByCoord.has(side_pos):
			continue
		if _move_open(side_pos):
			return
	_wait_for_interaction(task, "The %s receiver did not accept its exact physical resource" % owner_label)

func _drone_cave_has_owned_squidley(cave: Cave) -> bool:
	var dispatcher = cave.get_node_or_null("DroneDispatcher")
	if not is_instance_valid(dispatcher):
		return false
	var drones = dispatcher.get("drones")
	if not drones is Dictionary:
		return false
	for drone in drones.values():
		if not is_instance_valid(drone) or drone.get("teamId") != keeper.teamId:
			continue
		if drone.get("dispatcherId") != "dronecave":
			continue
		var script = drone.get_script()
		if script is Script and script.resource_path == SQUIDLEY_SCRIPT:
			return true
	return false

func _finish_cave_task(task: Dictionary, reason: String, evidence = null) -> void:
	var label := str(CaveTaskKind.keys()[int(task.cave_kind)]).to_lower()
	_record("cave_completed", reason, evidence)
	ModLoaderLog.info("Completed %s cave side task: %s" % [label, reason], LOG_NAME)
	_pop_task(reason)

func _wait_for_interaction(task: Dictionary, reason: String) -> void:
	_release_all()
	task.wait_steps = int(task.get("wait_steps", 0)) + 1
	if int(task.wait_steps) <= INTERACTION_WAIT_LIMIT:
		return
	_fail(reason)

func _mine_gadget_chamber(task: Dictionary) -> void:
	var chamber: Chamber = task.target
	if not is_instance_valid(chamber):
		_fail("The active gadget chamber disappeared")
		return

	match chamber.currentState:
		Chamber.State.REVEALED:
			_excavate_chamber(task, chamber, CONST.GADGET, "Gadget")
		Chamber.State.OPENING:
			_wait_for_interaction(task, "Gadget chamber did not finish opening")
		Chamber.State.OPEN:
			_activate_chamber(task, "Gadget", true)
		Chamber.State.EMPTY:
			_wait_for_interaction(task, "Activated gadget chamber did not attach its artifact")
		_:
			_fail("Gadget chamber returned to an unsupported state")

func _excavate_chamber(task: Dictionary, chamber: Chamber, tile_type: String, label: String) -> void:
	var plan := _chamber_cover_plan(chamber, tile_type)
	if plan.is_empty():
		_wait_for_interaction(task, "No revealed %s cover has a reachable open approach" % label)
		return
	task.wait_steps = 0
	var approach: Vector2i = plan["approach_coord"]
	var target: Vector2i = plan["target"]
	if approach != NO_COORD and Level.map.getTileCoord(keeper.global_position) != approach:
		if not _move_open(Level.map.getTilePos(approach)):
			_fail("The revealed %s cover approach became unreachable" % label)
		return
	var actions := _axis(Level.map.getTilePos(target))
	if actions.is_empty():
		_wait_for_interaction(task, "%s chamber did not reveal another cover tile" % label)
		return
	_hold(actions)

func _chamber_cover_plan(chamber: Chamber, tile_type: String) -> Dictionary:
	if not is_instance_valid(chamber) or not is_instance_valid(chamber.tileCover):
		return {}
	var best := {}
	var best_seconds := INF
	var fallback := NO_COORD
	var fallback_distance := INF
	for local_cell in chamber.tileCover.get_used_cells(MapData.DEFAULT_LAYER):
		var target := Vector2i(chamber.coord + Vector2(local_cell))
		var tile = Level.map.getTile(target)
		if not tile is Tile or tile.type != tile_type:
			continue
		var distance := keeper.global_position.distance_squared_to(Level.map.getTilePos(target))
		if distance < fallback_distance:
			fallback = target
			fallback_distance = distance
		if not Level.map.isRevealed(target):
			continue
		var route := _tile_interaction_route(target)
		var selected_seconds := minf(route.astar_seconds, route.direct_seconds)
		if not is_finite(selected_seconds) or selected_seconds >= best_seconds:
			continue
		if float(route.astar_seconds) > float(route.direct_seconds):
			route["approach_coord"] = NO_COORD
		best = route
		best["target"] = target
		best_seconds = selected_seconds
	if best.is_empty() and fallback != NO_COORD:
		return {"approach_coord": NO_COORD, "target": fallback}
	return best

func _begin_detached_artifact_recovery(task: Dictionary, artifact: Drop) -> void:
	if Vector2i(task.recovery_coord) != NO_COORD:
		return
	if int(task.recovery_attempts) >= ARTIFACT_RECOVERY_LIMIT:
		_fail("The chamber artifact detached more than three times before delivery")
		return
	task.recovery_attempts = int(task.recovery_attempts) + 1
	task.recovery_coord = Level.map.getTileCoord(artifact.global_position)
	task.wait_steps = 0
	_record("artifact_recovery_started", "The chamber artifact detached; clear its fixed neighboring tiles", {"attempt": task.recovery_attempts})

func _recover_detached_artifact(task: Dictionary) -> void:
	var artifact = task.get("gadget_drop")
	if not is_instance_valid(artifact) or artifact.absorbed or artifact.independent:
		task.recovery_coord = NO_COORD
		return
	if artifact.isCarried():
		_fail("The tracked chamber artifact attached to an unexpected carrier during clearance")
		return
	if Vector2i(task.recovery_coord) == NO_COORD:
		_begin_detached_artifact_recovery(task, artifact)
	var plan := _artifact_recovery_clearance_plan(task.recovery_coord)
	if int(plan["remaining"]) == 0:
		task.wait_steps = 0
		_reattach_detached_artifact(task)
		return
	if not plan.has("target"):
		_wait_for_interaction(task, "No open approach reaches the detached artifact clearance tiles")
		return
	task.wait_steps = 0
	var target: Vector2i = plan["target"]
	var target_tile = Level.map.getTile(target)
	if target_tile is Tile and ORE_TYPES.has(target_tile.type):
		_record_cache_site(Level.map.getTilePos(task.recovery_coord))
	var approach: Vector2i = plan["approach"]
	if Level.map.getTileCoord(keeper.global_position) != approach:
		if not _move_open(Level.map.getTilePos(approach)):
			_fail("The detached artifact clearance approach became unreachable")
		return
	_hold(_axis(Level.map.getTilePos(target)))

func _artifact_recovery_clearance_plan(recovery_coord: Vector2i) -> Dictionary:
	var result := {"remaining": 0}
	var best_distance := INF
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			var target := recovery_coord + Vector2i(x_offset, y_offset)
			if not Level.map.isRevealed(target):
				continue
			var tile = Level.map.getTile(target)
			if (
				not tile is Tile
				or not ARTIFACT_CLEARANCE_TILE_TYPES.has(tile.type)
				or not tile.get_meta("destructable", false)
			):
				continue
			result["remaining"] = int(result["remaining"]) + 1
			for direction in CARDINAL_OFFSETS:
				var approach: Vector2i = target + direction
				var distance := _path_distance(keeper.global_position, Level.map.getTilePos(approach))
				if not is_finite(distance) or distance >= best_distance:
					continue
				result["target"] = target
				result["approach"] = approach
				best_distance = distance
	return result

func _reattach_detached_artifact(task: Dictionary) -> void:
	var artifact = task.get("gadget_drop")
	if not is_instance_valid(artifact) or artifact.absorbed or artifact.independent:
		task.recovery_coord = NO_COORD
		return
	if artifact.isCarried():
		_fail("The tracked chamber artifact attached to an unexpected carrier before reattachment")
		return
	if not keeper.carriedCarryables.is_empty():
		_fail("Cannot reacquire the chamber artifact with a non-exclusive load")
		return
	if keeper.focussedCarryable == artifact and _leaf() == "Keeper1InputProcessor":
		if pickup_failures >= 3:
			_fail("Repeated exact chamber artifact pickup attempts failed")
			return
		pickup_failures += 1
		_release_all()
		_tap(&"keeper1_pickup")
		delay = CARRY_PICKUP_SECONDS
		return
	if _move_open(artifact.global_position):
		task.wait_steps = 0
		return
	_wait_for_interaction(task, "No open path reaches the detached chamber artifact")

func _activate_chamber(task: Dictionary, label: String, transport_artifact: bool) -> void:
	var chamber: Chamber = task.target
	if not is_instance_valid(chamber) or chamber.currentState != Chamber.State.OPEN:
		_wait_for_interaction(task, "%s chamber is not ready for activation" % label)
		return
	if transport_artifact and not keeper.carriedCarryables.is_empty():
		_drop_interaction_cargo()
		return
	var usable := chamber.get_node_or_null("Usable") as Node2D
	if not is_instance_valid(usable) or not chamber.canFocusUse(keeper):
		_wait_for_interaction(task, "Open %s chamber did not expose its usable target" % label)
		return
	if keeper.focussedUsable == usable and _leaf() == "Keeper1InputProcessor":
		_release_all()
		if transport_artifact:
			_prepare_artifact_transport(task)
		_tap(&"ui_select")
		task.wait_steps = 0
		delay = 0.2
		return
	if Level.map.getTileCoord(keeper.global_position) == Level.map.getTileCoord(usable.global_position):
		var actions := _axis(usable.global_position)
		if not actions.is_empty():
			task.wait_steps = 0
			_hold(actions)
			return
		_wait_for_interaction(task, "The open %s chamber did not receive exact usable focus" % label)
		return
	if _move_open(usable.global_position):
		task.wait_steps = 0
	else:
		_fail("No open path reaches the %s chamber usable" % label)

func _prepare_artifact_transport(task: Dictionary) -> void:
	task.gadget_drop = null
	task.prior_drop_uids.clear()
	task.wait_steps = 0
	task.recovery_coord = NO_COORD
	task.recovery_attempts = 0
	for candidate in Level.drops.get_all_drops().values():
		if candidate is Drop and candidate.type == task.target.drop_type:
			task.prior_drop_uids[candidate.UID] = true

func _drop_interaction_cargo() -> void:
	if _leaf() != "Keeper1InputProcessor":
		_fail("Cannot unload cargo without keeper input control")
		return
	if keeper.carriedCarryables.any(func(item): return item is Drop and item.type in [CONST.POWERCORE, CONST.GADGET, CONST.RELIC]):
		_fail("Cannot unload mixed cargo without dropping the chamber artifact")
		return
	if keeper.carriedCarryables.any(func(item): return item is Drop and item.carryableType == "resource"):
		_record_cache_site(keeper.global_position)
	_release_all()
	_tap(&"keeper1_drop")
	delay = 0.2

func _carried_artifact(task: Dictionary) -> Drop:
	if not is_instance_valid(task.get("target")):
		return null
	for carried in keeper.carriedCarryables:
		if not carried is Drop or carried.type != task.target.drop_type or carried.carryableType != "gadget":
			continue
		if is_instance_valid(task.get("gadget_drop")) and carried != task.gadget_drop:
			continue
		if task.prior_drop_uids.has(carried.UID):
			continue
		return carried
	return null

func _consume_upgrade_step(task: Dictionary, reason: String) -> bool:
	task.ui_steps = int(task.get("ui_steps", 0)) + 1
	if int(task.ui_steps) <= 30:
		return true
	_release_all()
	if _leaf() == "UpgradesInputProcessor":
		_tap(&"ui_cancel")
	_fail(reason)
	return false

func _defend(task: Dictionary) -> void:
	var leaf := _leaf()
	if not keeper.isInsideStation:
		_travel_to_station()
		return
	if not _wave("wavepresent") and not _wave("wavebattle") and leaf == "StationInputProcessor":
		var upgrade := _next_upgrade_target()
		var upgrade_id: String = upgrade.get("id", "")
		if not upgrade_id.is_empty() and _upgrade_ready(upgrade_id):
			_push_task({"type": TaskType.UPGRADE}, "An affordable upgrade is available before battle")
			return
	if _wave("wavepresent") or _wave("wavebattle"):
		task.saw_wave = true
	if bool(task.get("saw_wave", false)) and not _wave("wavepresent") and not _wave("wavebattle"):
		_release_all()
		if leaf == "BattleInputProcessor":
			_tap(&"ui_cancel"); delay = 0.5
		else:
			_finish_defense()
		return
	if leaf != "BattleInputProcessor":
		_release_all()
		if leaf == "StationInputProcessor":
			_tap(&"dome_battle"); delay = 0.5
		return
	if _wave("wavepresent") and leaf == "BattleInputProcessor":
		return
	_release_all()

func _finish_defense() -> void:
	_pop_task("The monster wave has settled")
	var full_load := _full_load_count(_carry_loss())
	if (
		_find_task(TaskType.CLEANUP_RESOURCES).is_empty()
		and _reachable_cached_resource_count() >= full_load
	):
		pending_intents[UpgradeIntent.MOBILITY] = true
		mobility_arm = MobilityArm.SPEED if _bought_count(SPEED_UPGRADES) <= _bought_count(CARRY_UPGRADES) else MobilityArm.STRENGTH
		_push_task({"type": TaskType.CLEANUP_RESOURCES, "target": null, "ignored": {}}, "Post-wave cache quantity reached the cleanup threshold")

func _recover(task: Dictionary) -> void:
	var action := DIRECTIONS[int(task.probe_index)]
	if _directed_distance(action, task.probe_origin) >= GameWorld.TILE_SIZE:
		_pop_task("A recovery probe moved the keeper one tile")
		return
	task.probe_time = float(task.probe_time) + TICK
	if float(task.probe_time) >= STALL_SECONDS:
		task.probe_count = int(task.probe_count) + 1
		if int(task.probe_count) >= DIRECTIONS.size():
			_fail("All four recovery probes failed")
			return
		task.probe_index = (int(task.probe_index) + 1) % DIRECTIONS.size()
		task.probe_time = 0.0
		task.probe_origin = keeper.global_position
		action = DIRECTIONS[int(task.probe_index)]
	_hold([action])

func _claim_ore_interaction(required_type := "") -> bool:
	var best := NO_COORD
	var best_distance := INF
	var best_route := {}
	for type in ORE_TYPES:
		if not required_type.is_empty() and type != required_type:
			continue
		for tile in Level.map.tilesByType.get(type, []):
			if not is_instance_valid(tile) or not tile.is_visible_in_tree():
				continue
			var coord := Vector2i(tile.coord)
			if not Level.map.isRevealed(coord) or _target_is_claimed(coord):
				continue
			var distance := keeper.global_position.distance_to(tile.global_position) / GameWorld.TILE_SIZE
			if distance >= INTERACTION_RADIUS_TILES:
				continue
			var route := _tile_interaction_route(coord)
			if not is_finite(route.astar_seconds) and not is_finite(route.direct_seconds):
				continue
			if distance < best_distance:
				best = coord
				best_distance = distance
				best_route = route
	if best == NO_COORD:
		return false
	var subtype := required_type if not required_type.is_empty() else "ore"
	var reason := "A revealed ore deposit is inside the interaction scan"
	if not required_type.is_empty():
		reason = "A revealed %s deposit can supply the active side task" % required_type
	_record_interaction_decision("mine", subtype, best, best_distance, best_route)
	_push_task({
		"type": TaskType.MINE,
		"ore": best,
		"approach_coord": NO_COORD if float(best_route.astar_seconds) > float(best_route.direct_seconds) else Vector2i(best_route.approach_coord),
		"vein": [best],
	}, reason)
	return true

func _tile_interaction_route(target: Vector2i) -> Dictionary:
	var speed := _effective_speed(
		keeper.carriedCarryables.size(),
		_planning_base_speed(),
		_carry_loss()
	)
	var astar_seconds := INF
	var approach_coord := NO_COORD
	for offset in CARDINAL_OFFSETS:
		var candidate: Vector2i = target + offset
		var seconds := _path_distance(
			keeper.global_position,
			Level.map.getTilePos(candidate)
		) / speed
		if seconds < astar_seconds:
			astar_seconds = seconds
			approach_coord = candidate
	return {
		"approach_coord": approach_coord,
		"astar_seconds": astar_seconds,
		"direct_seconds": _direct_approach_seconds(target, speed, 1),
	}

func _record_interaction_decision(kind: String, subtype: String, coord: Vector2i, distance: float, route: Dictionary) -> void:
	var astar_seconds := float(route.astar_seconds)
	var direct_seconds := float(route.direct_seconds)
	var approach := "direct_dig" if astar_seconds > direct_seconds else "astar"
	_record(
		"interaction_decided",
		"A revealed %s %s is inside the local scan; use %s because its estimate is no slower"
		% [subtype, kind, approach],
		{
			"approach": approach,
			"approach_coord": null if Vector2i(route.approach_coord) == NO_COORD else Vector2i(route.approach_coord),
			"astar_seconds": astar_seconds if is_finite(astar_seconds) else null,
			"coord": coord,
			"direct_dig_seconds": direct_seconds if is_finite(direct_seconds) else null,
			"interaction_kind": kind,
			"straight_distance": distance,
		}
	)

func _direct_approach_seconds(target: Vector2i, speed: float, stop_tiles: int) -> float:
	var cursor: Vector2i = Level.map.getTileCoord(keeper.global_position)
	var seconds := 0.0
	while absi(cursor.x - target.x) + absi(cursor.y - target.y) > stop_tiles:
		var delta: Vector2i = target - cursor
		if absi(delta.x) > absi(delta.y):
			cursor.x += signi(delta.x)
		else:
			cursor.y += signi(delta.y)
		if not Level.map.visibleTileCoords.has(cursor):
			return INF
		var tile = Level.map.getTile(cursor)
		if tile is Tile:
			var drill_seconds := _tile_drill_seconds(tile)
			if not is_finite(drill_seconds):
				return INF
			seconds += drill_seconds
		seconds += GameWorld.TILE_SIZE / speed
	return seconds

func _tile_drill_seconds(tile: Tile) -> float:
	if not tile.get_meta("destructable", false):
		return INF
	var strength := float(Data.of(keeper.playerId + ".keeper1.drillStrength"))
	if tile.hardness >= 3:
		strength *= float(Data.ofOr(keeper.playerId + ".keeper1.hardtilesmodifier", 1.0))
	if tile.maxDamagePerHit >= 0.0:
		strength = minf(strength, tile.maxDamagePerHit)
	if strength <= 0.0:
		return INF
	var cooldown := float(Data.of(keeper.playerId + ".keeper1.tileHitCooldown"))
	var drill_buff := 1.0 - float(Data.ofOr(keeper.playerId + ".keeper.drillBuff", 0.0))
	if drill_buff < 1.0:
		cooldown = maxf(cooldown * drill_buff, 0.017)
	return ceilf(tile.health / strength) * cooldown

func _adjacent_ore(vein: Array) -> Vector2i:
	for type in ORE_TYPES:
		for tile in Level.map.tilesByType.get(type, []):
			if not is_instance_valid(tile) or not tile.is_visible_in_tree():
				continue
			var cell := Vector2i(tile.coord)
			if not Level.map.isRevealed(cell):
				continue
			for previous in vein:
				if absi(cell.x - previous.x) + absi(cell.y - previous.y) == 1:
					return cell
	return NO_COORD

func _record_cache(vein: Array) -> void:
	if vein.is_empty():
		return
	var site: Vector2 = Level.map.getTilePos(vein.front())
	_record_cache_site(site)

func _record_cache_site(site: Vector2) -> void:
	if caches.all(func(existing): return existing.distance_to(site) > GameWorld.TILE_SIZE):
		caches.append(site)

func _cached_resources() -> Array[Drop]:
	var result: Array[Drop] = []
	for candidate in Level.drops.get_all_drops().values():
		if not candidate is Drop:
			continue
		if candidate.carryableType != "resource" or candidate.absorbed or candidate.independent or candidate.isCarried():
			continue
		if _drop_targeted_by_transport(candidate):
			continue
		var near_cache := caches.any(func(site): return site.distance_to(candidate.global_position) <= GameWorld.TILE_SIZE * 3.0)
		if near_cache:
			result.append(candidate)
	return result

func _drop_targeted_by_transport(drop: Drop) -> bool:
	if not is_instance_valid(drop) or not is_instance_valid(keeper):
		return false
	for drone in get_tree().get_nodes_in_group(keeper.teamId + "-transport_drones"):
		if not _is_cave_squidley(drone):
			continue
		if drone.get("targettedDrop") == drop:
			return true
	return false

func _is_cave_squidley(drone) -> bool:
	if not is_instance_valid(drone):
		return false
	if drone.get("teamId") != keeper.teamId or drone.get("dispatcherId") != "dronecave":
		return false
	var script = drone.get_script()
	return script is Script and script.resource_path == SQUIDLEY_SCRIPT

func _reachable_cached_resource_count() -> int:
	var reachable := 0
	for drop in _cached_resources():
		if not is_finite(_path_distance(keeper.global_position, drop.global_position)):
			continue
		if not is_finite(_path_distance(drop.global_position, _home_position())):
			continue
		reachable += 1
	return reachable
func _defense_due() -> bool:
	var wave_time := _wave_time()
	if not is_finite(wave_time):
		return false
	var distance := _path_distance(keeper.global_position, _home_position())
	if not is_finite(distance):
		return true
	var speed := _effective_speed(keeper.carriedCarryables.size(), _planning_base_speed(), _carry_loss())
	return speed <= 0.0 or wave_time <= distance / speed + STATION_ENTRY_SECONDS

func _stored_upgrade_resources() -> Dictionary:
	var available := {}
	for resource in ORE_TYPES:
		available[resource] = int(Data.getInventory(resource, keeper.teamId))
	return available

func _resource_deficits(cost: Dictionary, available: Dictionary) -> Dictionary:
	var deficits := {}
	for resource in cost:
		var missing := int(cost[resource]) - int(available.get(resource, 0))
		if missing > 0:
			deficits[resource] = missing
	return deficits

func _resource_total(resources: Dictionary) -> int:
	var total := 0
	for resource in resources:
		total += int(resources[resource])
	return total

func _home_position() -> Vector2:
	return Vector2(dome.global_position.x, -GameWorld.TILE_SIZE) + CONST.TILE_OFFSET

func _planning_base_speed() -> float:
	var speed := float(Data.of(keeper.playerId + ".keeper1.maxSpeed"))
	return speed + float(Data.ofOr(keeper.playerId + ".keeper.speedBuff", 0.0))

func _carry_loss() -> float:
	return float(Data.of(keeper.playerId + ".keeper1.speedLossPerCarry"))

func _speed_ratio_for_count(count: int, loss: float) -> float:
	var ratio := 1.0 - 0.005 * loss * count * (count + 1)
	return maxf(ratio, 0.0)

func _effective_speed(count: int, base_speed: float, loss: float) -> float:
	return base_speed * _speed_ratio_for_count(count, loss)

func _full_load_count(loss: float) -> int:
	var count := 0
	while count < 128 and _speed_ratio_for_count(count + 1, loss) >= MIN_SPEED_RATIO:
		count += 1
	return count

func _shaft_should_widen() -> bool:
	return _full_load_count(_carry_loss()) >= WIDE_SHAFT_MIN_LOAD

func _aim() -> void:
	var weapon = _laser()
	if weapon == null or not weapon.inputReady:
		_clear_laser_aim("The normal Laser is not ready for aiming input")
		_release_all()
		return
	var target = _select_laser_target(weapon)
	laser_target = target
	if target == null:
		_update_laser_aim(null, null, null, null, null)
		_release_all()
		return
	var damageable: bool = target.canBeHit() and not target.invulnerable
	var error := _laser_aim_error(weapon, target)
	var collider = null
	var collider_ray_index: Variant = null
	for ray_index in weapon.raycasts.size():
		var raycast = weapon.raycasts[ray_index]
		if not raycast.enabled:
			continue
		collider = raycast.get_collider()
		if collider != null:
			collider_ray_index = ray_index
			break
	var switch_reason := ""
	var wave = Level.monstersByTeamId.get(keeper.teamId)
	if (
		collider != target
		and collider is Monster
		and _laser_target_is_eligible(collider, wave)
		and _laser_target_is_damageable(collider)
	):
		target = collider
		laser_target = target
		damageable = true
		error = _laser_aim_error(weapon, target)
		switch_reason = "an eligible first collider took over"
	var fire_action := StringName(dome.techId + "_fire")
	var actions: Array[StringName] = []
	var started_firing := false
	if collider == target and damageable:
		started_firing = not held.has(fire_action)
		actions.append(fire_action)
	elif collider != target:
		if error > 0.0:
			actions.append(&"ui_right")
		elif error < 0.0:
			actions.append(&"ui_left")
	_hold(actions)
	_update_laser_aim(target, damageable, error, collider, collider_ray_index, switch_reason)
	if started_firing:
		_queue_record("Laser began firing at an acquired monster")

func _reset_laser_aim() -> void:
	laser_target = null
	laser_selected_monster = null
	laser_selected_monster_damageable = null
	laser_signed_angular_error = null
	laser_first_collider = null
	laser_first_collider_ray_index = null
	laser_selected_monster_ref = null

func _clear_laser_aim(reason: String) -> void:
	laser_target = null
	if (
		laser_selected_monster == null
		and laser_selected_monster_damageable == null
		and laser_signed_angular_error == null
		and laser_first_collider == null
	):
		return
	_update_laser_aim(null, null, null, null, null, reason)

func _update_laser_aim(target, damageable, error, collider, collider_ray_index, reason := "") -> void:
	var selected_monster: Variant = _laser_aim_object(target)
	var first_collider: Variant = _laser_aim_object(collider)
	var target_changed: bool = selected_monster != laser_selected_monster
	var damageability_changed: bool = damageable != laser_selected_monster_damageable
	var collider_changed: bool = (
		first_collider != laser_first_collider
		or collider_ray_index != laser_first_collider_ray_index
	)
	var previous_target = laser_selected_monster_ref.get_ref() if laser_selected_monster_ref != null else null
	var previous_selected_monster = laser_selected_monster
	var previous_first_collider = laser_first_collider
	var previous_collider_ray_index = laser_first_collider_ray_index

	laser_selected_monster = selected_monster
	laser_selected_monster_damageable = damageable
	laser_signed_angular_error = error
	laser_first_collider = first_collider
	laser_first_collider_ray_index = collider_ray_index
	if target_changed:
		laser_selected_monster_ref = weakref(target) if is_instance_valid(target) else null

	if target_changed:
		var switch_reason := reason
		if switch_reason.is_empty():
			switch_reason = _laser_target_switch_reason(
				previous_target,
				target,
				previous_selected_monster != null,
			)
		_record(
			"laser_target_changed",
			"Laser target changed from %s to %s: %s" % [
				_describe_laser_aim_object(previous_selected_monster),
				_describe_laser_aim_object(selected_monster),
				switch_reason,
			],
			null,
		)
		return
	if damageability_changed:
		_record(
			"laser_target_damageability_changed",
			"Selected Laser target became %s" % ("damageable" if damageable else "not damageable"),
			null,
		)
		return
	if collider_changed:
		var previous_ray := "none" if previous_collider_ray_index == null else str(previous_collider_ray_index)
		var current_ray := "none" if collider_ray_index == null else str(collider_ray_index)
		_record(
			"laser_first_collider_changed",
			"Laser first collider changed from %s on ray %s to %s on ray %s" % [
				_describe_laser_aim_object(previous_first_collider),
				previous_ray,
				_describe_laser_aim_object(first_collider),
				current_ray,
			],
			null,
		)

func _laser_aim_object(value) -> Variant:
	if not is_instance_valid(value):
		return null
	if value is Monster:
		return {
			"category": "monster",
			"kind": Utils.decode_monster_type(value.type),
			"uid": int(value.UID),
			"counter": int(value.counter),
			"instance_id": null,
		}
	return {
		"category": "projectile" if value.is_in_group("projectile") else "other",
		"kind": value.get_class(),
		"uid": null,
		"counter": null,
		"instance_id": str(value.get_instance_id()),
	}

func _describe_laser_aim_object(value) -> String:
	if value == null:
		return "none"
	if value["category"] != "monster":
		return "%s %s (instance %s)" % [value["category"], value["kind"], value["instance_id"]]
	return "%s #%d (UID %d)" % [value["kind"], value["counter"], value["uid"]]

func _laser_target_switch_reason(previous, target, had_previous: bool) -> String:
	if not is_instance_valid(target):
		if not is_instance_valid(previous):
			return "no selectable target remains"
		if previous.dead:
			return "the previous target died and no replacement is selectable"
		if previous.leaving:
			return "the previous target departed and no replacement is selectable"
		if not previous.alive():
			return "the previous target was no longer alive and no replacement is selectable"
		var previous_wave = Level.monstersByTeamId.get(keeper.teamId)
		if not is_instance_valid(previous_wave) or not previous_wave.monstersInWave.has(previous):
			return "the previous target left the active wave and no replacement is selectable"
		return "the previous target left the visible selectable set"
	if not is_instance_valid(previous):
		if had_previous:
			return "the previous target became unavailable"
		return (
			"an initial damageable target became available"
			if _laser_target_is_damageable(target)
			else "only a non-damageable pre-aim target was available"
		)
	if previous.dead:
		return "the previous target died"
	if previous.leaving:
		return "the previous target departed"
	if not previous.alive():
		return "the previous target was no longer alive"
	var wave = Level.monstersByTeamId.get(keeper.teamId)
	if not is_instance_valid(wave) or not wave.monstersInWave.has(previous):
		return "the previous target left the active wave"
	var local_center: Vector2 = previous.to_local(previous.getCenter())
	var screen_position: Vector2 = previous.get_global_transform_with_canvas() * local_center
	if not previous.is_visible_in_tree() or not get_viewport().get_visible_rect().has_point(screen_position):
		return "the previous target left the visible viewport"
	var previous_damageable: bool = previous.canBeHit() and not previous.invulnerable
	var target_damageable: bool = target.canBeHit() and not target.invulnerable
	if target_damageable and not previous_damageable:
		return "a damageable target became available while pre-aiming"
	return "the minimum-turn selector acquired a replacement"

func _select_laser_target(weapon):
	var wave = Level.monstersByTeamId.get(keeper.teamId)
	if not is_instance_valid(wave):
		return null
	var retained = laser_target if _laser_target_is_eligible(laser_target, wave) else null
	if retained != null and _laser_target_is_damageable(retained):
		return retained
	var best_damageable = null
	var best_pre_aim = null
	for monster in wave.monstersInWave:
		if not _laser_target_is_eligible(monster, wave):
			continue
		if _laser_target_is_damageable(monster):
			if _laser_target_is_better(monster, best_damageable, weapon):
				best_damageable = monster
			continue
		if retained == null and _laser_target_is_better(monster, best_pre_aim, weapon):
			best_pre_aim = monster
	if best_damageable != null:
		return best_damageable
	if retained != null:
		return retained
	return best_pre_aim

func _laser_target_is_eligible(monster, wave) -> bool:
	if not is_instance_valid(monster) or not monster is Monster or not is_instance_valid(wave):
		return false
	if not wave.monstersInWave.has(monster) or not monster.alive() or monster.dead or monster.leaving:
		return false
	if monster.type == Monster.Type.WORM_ROCK or monster.is_in_group("projectile") or not monster.is_visible_in_tree():
		return false
	var local_center: Vector2 = monster.to_local(monster.getCenter())
	var screen_position: Vector2 = monster.get_global_transform_with_canvas() * local_center
	return get_viewport().get_visible_rect().has_point(screen_position)

func _laser_target_is_damageable(monster: Monster) -> bool:
	return monster.canBeHit() and not monster.invulnerable

func _laser_target_is_better(candidate: Monster, current, weapon) -> bool:
	if not is_instance_valid(current):
		return true
	var candidate_error := absf(_laser_aim_error(weapon, candidate))
	var current_error := absf(_laser_aim_error(weapon, current))
	if not is_equal_approx(candidate_error, current_error):
		return candidate_error < current_error
	if candidate.UID != current.UID:
		return candidate.UID < current.UID
	return candidate.get_instance_id() < current.get_instance_id()

func _laser_aim_error(weapon, target: Monster) -> float:
	var aim: Vector2 = target.getCenter() - weapon.global_position
	var error := wrapf(aim.angle() - (weapon.rotation - CONST.PI_HALF), -PI, PI)
	if aim.x < 0.0 and error > CONST.PI_HALF:
		error -= TAU
	elif aim.x > 0.0 and error < -CONST.PI_HALF:
		error += TAU
	return error

func _laser():
	var found = null
	for station in dome.stations:
		for weapon in station.controlledWeapons:
			if weapon is LaserWeapon and not weapon.inverse:
				if found != null:
					return null
				found = weapon
	return found

func _upgrade_id(raw_id: StringName) -> String:
	var base_id := str(raw_id).to_lower()
	for candidate in [keeper.teamId + "." + base_id, keeper.playerId + "." + base_id, base_id]:
		if GameWorld.upgrades.has(candidate):
			return candidate
	return ""

func _bought_count(chain: Array[StringName]) -> int:
	var count := 0
	for raw_id in chain:
		count += int(GameWorld.boughtUpgrades.has(_upgrade_id(raw_id)))
	return count

func _resolve_chain(chain: Array[StringName], repeat_last := false) -> Dictionary:
	for index in chain.size():
		var raw_id := chain[index]
		var id := _upgrade_id(raw_id)
		if id.is_empty():
			return {"exhausted": false}
		var upgrade: Dictionary = GameWorld.upgrades[id]
		var repeat_target := repeat_last and index == chain.size() - 1 and upgrade.has("repeatable")
		if GameWorld.boughtUpgrades.has(id) and not repeat_target:
			continue
		if raw_id == &"domesandrepair" and _dome_health() >= _dome_max_health():
			return {"exhausted": false}
		if GameWorld.isUpgradeAddable(id):
			return {"id": id, "raw_id": raw_id, "exhausted": false}
		return {"exhausted": false}
	return {"exhausted": true}

func _resolve_alternating(primary: Array[StringName], secondary: Array[StringName], primary_next: bool) -> Dictionary:
	var first_arm := 0 if primary_next else 1
	var first := _resolve_chain(primary if first_arm == 0 else secondary)
	if not str(first.get("id", "")).is_empty():
		first["arm"] = first_arm
		return first
	var second := _resolve_chain(secondary if first_arm == 0 else primary)
	if not str(second.get("id", "")).is_empty():
		second["arm"] = 1 - first_arm
		return second
	return {"exhausted": bool(first.get("exhausted", false)) and bool(second.get("exhausted", false))}

func _resolve_intent(intent: int) -> Dictionary:
	var target := {}
	match intent:
		UpgradeIntent.COMBAT:
			target = _resolve_alternating(ATTACK_UPGRADES, HEALTH_PATH, combat_attack_next)
			var raw_id: StringName = target.get("raw_id", &"")
			target["fulfills"] = target.get("arm", -1) == 0 or raw_id == &"dome1health1" or raw_id == &"dome1health2"
		UpgradeIntent.REPAIR:
			target = _resolve_chain(REPAIR_UPGRADES, true)
			target["fulfills"] = target.get("raw_id", &"") == &"domesandrepair"
		UpgradeIntent.LASER_MOVE:
			target = _resolve_chain(LASER_MOVE_UPGRADES)
			target["fulfills"] = true
		UpgradeIntent.DRILL:
			target = _resolve_chain(DRILL_UPGRADES, true)
			target["fulfills"] = true
		UpgradeIntent.MOBILITY:
			target = _resolve_alternating(SPEED_UPGRADES, CARRY_UPGRADES, mobility_arm == MobilityArm.SPEED)
			target["fulfills"] = true
	target["intent"] = intent
	return target

func _select_upgrade_target(
	available: Dictionary,
	prune_exhausted := true,
	excluded_intents := {},
	excluded_ids := {},
) -> Dictionary:
	var reserved_resource_types := {}
	var fallback := {}
	var intent_classes := INTENT_CLASSES
	if pending_intents.has(UpgradeIntent.DRILL) and _bought_count(DRILL_UPGRADES) == 0 and _bought_count(ATTACK_UPGRADES) > 0:
		intent_classes = [
			[UpgradeIntent.REPAIR, UpgradeIntent.DRILL],
			[UpgradeIntent.COMBAT, UpgradeIntent.LASER_MOVE],
			[UpgradeIntent.MOBILITY],
		]
	for intent_class in intent_classes:
		var class_resource_types := {}
		var best := {}
		for intent in intent_class:
			if not pending_intents.has(intent) or excluded_intents.has(intent):
				continue
			var target := _resolve_intent(intent)
			if bool(target.get("exhausted", false)):
				if prune_exhausted:
					pending_intents.erase(intent)
					_queue_record("Upgrade plan changed")
				continue
			var id: String = target.get("id", "")
			if id.is_empty() or excluded_ids.has(id):
				continue
			var cost: Dictionary = GameWorld.upgrades[id].get("cost", {})
			var uses_reserved_resource := false
			for resource in cost:
				if int(cost[resource]) <= 0:
					continue
				class_resource_types[resource] = true
				if not reserved_resource_types.has(resource):
					continue
				uses_reserved_resource = true
			if uses_reserved_resource:
				continue
			if best.is_empty() or _upgrade_target_is_better(target, best, available):
				best = target
		if not best.is_empty() and _resource_deficits(
			GameWorld.upgrades[best["id"]].get("cost", {}),
			available,
		).is_empty():
			return best
		if not best.is_empty() and fallback.is_empty():
			fallback = best
		for resource in class_resource_types:
			reserved_resource_types[resource] = true
	return fallback

func _upgrade_target_is_better(candidate: Dictionary, current: Dictionary, available: Dictionary) -> bool:
	var candidate_cost: Dictionary = GameWorld.upgrades[candidate["id"]].get("cost", {})
	var current_cost: Dictionary = GameWorld.upgrades[current["id"]].get("cost", {})
	var candidate_deficits := _resource_deficits(candidate_cost, available)
	var current_deficits := _resource_deficits(current_cost, available)
	var candidate_affordable := candidate_deficits.is_empty()
	var current_affordable := current_deficits.is_empty()
	if candidate_affordable != current_affordable:
		return candidate_affordable
	if candidate_affordable:
		return _resource_total(candidate_cost) < _resource_total(current_cost)
	return _resource_total(candidate_deficits) < _resource_total(current_deficits)

func _next_upgrade_target(prune_exhausted := true) -> Dictionary:
	return _select_upgrade_target(_stored_upgrade_resources(), prune_exhausted)

func _freeze_upgrade_target(task: Dictionary) -> bool:
	if not str(task.get("active_id", "")).is_empty():
		return true
	var target := _next_upgrade_target()
	task.active_id = target.get("id", "")
	if str(task.active_id).is_empty():
		return false
	task.active_intent = int(target["intent"])
	task.active_arm = int(target.get("arm", -1))
	task.active_fulfills = bool(target.get("fulfills", true))
	if int(task.active_intent) == UpgradeIntent.REPAIR and float(task.get("repair_target", 0.0)) <= 0.0:
		task.repair_target = minf(
			_dome_max_health(),
			maxf(
				_dome_max_health() * REPAIR_HEALTH_RESERVE_RATIO,
				last_wave_health_loss
			)
		)
		ModLoaderLog.info(
			"UPGRADE repair target %.1f after %.1f net wave loss" % [task.repair_target, last_wave_health_loss],
			LOG_NAME
		)
	return true

func _upgrade_ready(id: String) -> bool:
	if not GameWorld.upgrades.has(id) or not GameWorld.isUpgradeAddable(id):
		return false
	if id.ends_with(".domesandrepair") or id == "domesandrepair":
		if _dome_health() >= _dome_max_health():
			return false
	return GameWorld.canAfford(GameWorld.upgrades[id].get("cost", {}), keeper.teamId)

func _active_upgrade_ready(task: Dictionary) -> bool:
	if int(task.get("active_intent", -1)) == UpgradeIntent.REPAIR and _dome_health() >= float(task.get("repair_target", 0.0)):
		return false
	return not str(task.get("active_id", "")).is_empty() and _upgrade_ready(task.active_id)

func _clear_active_upgrade(task: Dictionary) -> void:
	task.active_intent = -1
	task.active_id = ""
	task.active_arm = -1
	task.active_fulfills = false

func _on_upgrade_bought(id: String, team_id: String, player_id: String) -> void:
	if not running or team_id != keeper.teamId or player_id != keeper.playerId:
		return
	var task := _find_task(TaskType.UPGRADE)
	if task.is_empty() or id != str(task.get("active_id", "")):
		return
	if bool(task.get("active_fulfills", false)):
		if int(task.active_intent) == UpgradeIntent.COMBAT:
			combat_attack_next = int(task.active_arm) != 0
			if not combat_attack_next:
				pending_intents.erase(UpgradeIntent.COMBAT)
		elif int(task.active_intent) == UpgradeIntent.DRILL:
			drill_hits_by_coord.clear()
			pending_intents.erase(UpgradeIntent.DRILL)
		else:
			pending_intents.erase(int(task.active_intent))
	_clear_active_upgrade(task)
	_sync_repair_intent()
	task.ui_steps = 0
	task.closing = not _freeze_upgrade_target(task) or not _active_upgrade_ready(task)
	_queue_record("Upgrade purchased: " + id)

func _on_upgrade_error(id: String, team_id: String, player_id: String) -> void:
	var task := _find_task(TaskType.UPGRADE)
	if not running or task.is_empty() or id != str(task.get("active_id", "")) or team_id != keeper.teamId or player_id != keeper.playerId:
		return
	_release_all()
	if _leaf() == "UpgradesInputProcessor":
		_tap(&"ui_cancel")
	_fail("Game rejected intended upgrade: " + id)

func _path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if (
		keeper.getIsInsideDome()
		and from.distance_squared_to(keeper.global_position) <= 1.0
	):
		var departure_path := _dome_departure_path(from, to)
		if not departure_path.is_empty():
			return departure_path
	return _map_path(from, to)

func _map_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	for offset in CONST.PATHFINDING_OFFSETS:
		var result = Level.map.findPath(from + Vector2(offset), to, keeper.teamId)
		if result is PackedVector2Array and not result.is_empty():
			return result
	return PackedVector2Array()

func _dome_departure_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var map_path := _map_path(_home_position(), to)
	if map_path.is_empty():
		return PackedVector2Array()
	var points := PackedVector2Array([from])
	var shaft_at_current_height := Vector2(dome.global_position.x, from.y)
	if from.distance_squared_to(shaft_at_current_height) > 16.0:
		points.append(shaft_at_current_height)
	for point in map_path:
		if not points[points.size() - 1].is_equal_approx(point):
			points.append(point)
	return points

func _path_distance(from: Vector2, to: Vector2) -> float:
	var points := _path(from, to)
	if points.is_empty():
		return INF
	var distance := from.distance_to(points[0])
	for index in range(1, points.size()):
		distance += points[index - 1].distance_to(points[index])
	distance += points[points.size() - 1].distance_to(to)
	return distance

func _move_open(target: Vector2) -> bool:
	var points := _path(keeper.global_position, target)
	if points.is_empty():
		return false
	_hold(_axis(points[mini(1, points.size() - 1)]))
	return true

func _move_to_cave(target: Vector2) -> bool:
	var task := _find_task(TaskType.INTERACT)
	var approach_coord := Vector2i(task.get("approach_coord", NO_COORD))
	if approach_coord != NO_COORD:
		if Level.map.getTileCoord(keeper.global_position) != approach_coord:
			return _move_open(Level.map.getTilePos(approach_coord))
		task.approach_coord = NO_COORD
	var actions := _axis(target)
	if actions.is_empty():
		return false
	_hold(actions)
	return true
func _track_progress(delta: float) -> void:
	var action := StringName(held.keys().front()) if not held.is_empty() else StringName()
	if action.is_empty():
		_reset_progress()
		return
	if action != progress_action:
		progress_action = action; progress_origin = keeper.global_position; stalled = 0.0
	if _directed_distance(action, progress_origin) >= GameWorld.TILE_SIZE:
		_reset_progress()
		return
	stalled += delta
	if stalled < STALL_SECONDS:
		return
	_push_task({
		"type": TaskType.RECOVER,
		"probe_index": (DIRECTIONS.find(action) + 1) % DIRECTIONS.size(),
		"probe_count": 0,
		"probe_time": 0.0,
		"probe_origin": keeper.global_position,
	}, "No directed movement or drill progress for four seconds")

func _on_mined(_amount = 0.0) -> void:
	var tile := keeper.drill_hit_test_ray.get_collider() as Tile
	if is_instance_valid(tile):
		var tile_coord := Vector2i(tile.coord)
		var hits := int(drill_hits_by_coord.get(tile_coord, 0)) + 1
		if hits >= DRILL_HIT_INTENT_THRESHOLD:
			var was_pending := pending_intents.has(UpgradeIntent.DRILL)
			pending_intents[UpgradeIntent.DRILL] = true
			if not was_pending:
				_queue_record("Drill upgrade requested after repeated hits")
		if tile.health <= 0.0:
			drill_hits_by_coord.erase(tile_coord)
		else:
			drill_hits_by_coord[tile_coord] = hits
	if _task_is(TaskType.RECOVER):
		tasks.back().probe_time = 0.0
	else:
		_reset_progress()

func _reset_progress() -> void:
	progress_action = StringName()
	stalled = 0.0
	progress_origin = keeper.global_position

func _directed_distance(action: StringName, origin: Vector2) -> float:
	var vectors := {&"ui_right": Vector2.RIGHT, &"ui_down": Vector2.DOWN, &"ui_left": Vector2.LEFT, &"ui_up": Vector2.UP}
	return (keeper.global_position - origin).dot(vectors.get(action, Vector2.ZERO))

func _axis(target: Vector2) -> Array[StringName]:
	var delta := target - keeper.global_position; if delta.length_squared() <= 16.0: return []
	if absf(delta.x) > absf(delta.y):
		return [&"ui_right" if delta.x > 0.0 else &"ui_left"]
	return [&"ui_down" if delta.y > 0.0 else &"ui_up"]

func _wave(property: String) -> bool:
	return bool(Data.ofOr(keeper.teamId + ".monsters." + property, false))

func _wave_time() -> float:
	if _wave("wavepresent"):
		return 0.0
	var key := keeper.teamId + ".monsters.waveCooldown"
	return float(Data.of(key)) if GameWorld.runStarted and Data.has(key) else INF

func _on_drop_picked_up(drop, carrier) -> void:
	if carrier == keeper:
		pickup_failures = 0
		var interaction := _find_task(TaskType.INTERACT)
		if (
			drop is Drop
			and not interaction.is_empty()
			and str(interaction.get("kind", "")) == "chamber"
			and is_instance_valid(interaction.get("target"))
			and drop.type == interaction.target.drop_type
			and drop.carryableType == "gadget"
		):
			if not interaction.prior_drop_uids.has(drop.UID):
				interaction.gadget_drop = drop
				_queue_record("Keeper picked up the exact activated artifact")
			return
		if drop is Drop and not interaction.is_empty() and str(interaction.get("kind", "")) == "cave" and _accept_pending_resource_cave_drop(interaction, drop):
			return
		_queue_record("Keeper picked up a resource")

func _on_monster_spawned(monster: Monster) -> void:
	monster.died.connect(_queue_record.bind("Monster died"), CONNECT_ONE_SHOT)
	_queue_record("Monster spawned")

func propertyChanged(property: String, old_value, new_value) -> void:
	if not running:
		return
	if property == "game.over":
		if new_value == "":
			return
		if new_value != "won" and new_value != "lost":
			_fail("Unsupported game.over value: " + str(new_value))
			return
		if recording_file != null:
			var outcome := String(new_value)
			_record("run_" + outcome, "Run " + outcome, null)
			recording_terminal = true
			recording_finished.emit()
		return
	if property.ends_with(".monsters.wavepresent") and bool(new_value) and not bool(old_value):
		wave_start_max_health = _dome_max_health()
		wave_start_missing_health = maxf(wave_start_max_health - _dome_health(), 0.0)
		wave_health_tracking = true
	elif property.ends_with(".monsters.wavebattle") and bool(old_value) and not bool(new_value):
		if wave_health_tracking and wave_start_max_health > 0.0:
			var missing_health := maxf(_dome_max_health() - _dome_health(), 0.0)
			last_wave_health_loss = maxf(missing_health - wave_start_missing_health, 0.0)
			var loss_ratio := last_wave_health_loss / wave_start_max_health
			if loss_ratio > WAVE_NET_HEALTH_LOSS_RATIO_THRESHOLD:
				pending_intents[UpgradeIntent.COMBAT] = true
		wave_health_tracking = false
		if checkpoint_save_enabled:
			call_deferred(&"_commit_checkpoint")
	if property.ends_with(".dome.health") or property.ends_with(".dome.maxhealth"):
		_sync_repair_intent()
	_queue_record("Game data changed: " + property.get_slice(".", property.get_slice_count(".") - 1))

func _commit_checkpoint() -> void:
	if not running or _wave("wavepresent") or _wave("wavebattle"):
		return
	_save_checkpoint(int(Data.of(keeper.teamId + ".monsters.cycle")))

func _sync_repair_intent() -> void:
	var upgrade_task := _find_task(TaskType.UPGRADE)
	var target_health := float(upgrade_task.get("repair_target", 0.0))
	if target_health <= 0.0:
		target_health = _dome_max_health() * REPAIR_HEALTH_RESERVE_RATIO
	if _dome_max_health() > 0.0 and _dome_health() < target_health:
		pending_intents[UpgradeIntent.REPAIR] = true
	else:
		pending_intents.erase(UpgradeIntent.REPAIR)

func _dome_health() -> float:
	return float(Data.of(keeper.teamId + ".dome.health"))

func _dome_max_health() -> float:
	return float(Data.of(keeper.teamId + ".dome.maxhealth"))

func _blocked() -> bool:
	if InputSystem.game_not_in_focus or InputSystem.processors_changing:
		return true
	var leaf := _leaf()
	if not keeper.isInsideStation and not _task_is(TaskType.UPGRADE) and not _task_is(TaskType.DEFEND) and not _task_is(TaskType.CHOOSE_REWARD) and leaf != "Keeper1InputProcessor":
		return true
	if GameWorld.paused and leaf != "StationInputProcessor" and leaf != "UpgradesInputProcessor" and leaf != "GadgetChoiceInputProcessor":
		return true
	for overlay in get_tree().get_nodes_in_group("yolo_pause_menu"):
		if overlay is CanvasItem and overlay.is_visible_in_tree() and leaf != "UpgradesInputProcessor":
			return true
	return false

func _leaf() -> String:
	var leaf = InputSystem.getLastChild(keeper.deviceId)
	return str(leaf.name) if is_instance_valid(leaf) else ""

func _hold(actions: Array[StringName]) -> void:
	for action in held.keys():
		if not actions.has(action):
			_emit(action, false)
			held.erase(action)
	for action in actions:
		if not held.has(action):
			_emit(action, true)
			held[action] = true

func _tap(action: StringName) -> void:
	_emit(action, true)
	_emit(action, false)

func _emit(action: StringName, pressed: bool) -> void:
	var event := bindings[action].duplicate() as InputEventKey
	event.device = 0; event.pressed = pressed; event.echo = false
	InputSystem.game_not_in_focus = false
	Input.parse_input_event(event)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _release_all() -> void:
	for action in held.keys():
		_emit(action, false)
	held.clear()

func _adopt_descent_frontier(task: Dictionary, coord: Vector2i, target_row: int, reason: String) -> void:
	task.attempted_descent_origins[coord] = true
	task.mining_outcome = MiningOutcome.ACTIVE
	task.mining_outcome_reason = ""
	task.branch_row = target_row
	task.branch_side = 1
	task.branch_entry_coord = NO_COORD
	task.active_corridor_cells.clear()
	task.bypass_side = 1
	task.bypass_reversed = false
	task.resume_coord = coord
	task.mode = ExploreMode.DESCEND
	task.shaft_phase = 0
	task.shaft_col = -1
	task.shaft_row = -1
	_release_all()
	_record("search_route_changed", reason, {"mode": "descend", "coord": coord})
	_reset_progress()
	delay = 0.2

func _record_completed_corridor(task: Dictionary, row: int) -> void:
	var cells: Dictionary = task.active_corridor_cells.duplicate()
	task.active_corridor_cells.clear()
	for index in range(task.completed_corridors.size()):
		var corridor: Dictionary = task.completed_corridors[index]
		if int(corridor.get("row", -1)) != row:
			continue
		var known_cells: Dictionary = corridor.get("cells", {})
		var overlaps := false
		for coord in cells:
			if known_cells.has(coord):
				overlaps = true
				break
		if not overlaps:
			continue
		for coord in cells:
			known_cells[coord] = true
		task.completed_corridors.remove_at(index)
		task.completed_corridors.append({"row": row, "cells": known_cells})
		return
	task.completed_corridors.append({"row": row, "cells": cells})

func _find_backtrack_frontier(task: Dictionary) -> Dictionary:
	var saw_unreachable := false
	var saw_unsupported := false
	var saw_wave_unsafe := false
	var candidates: Array[Dictionary] = []
	var deepest_row := -1
	var keeper_coord: Vector2i = Level.map.getTileCoord(keeper.global_position)
	for corridor_index in range(task.completed_corridors.size() - 1, -1, -1):
		var corridor: Dictionary = task.completed_corridors[corridor_index]
		var cells: Dictionary = corridor.get("cells", {})
		var row := int(corridor.get("row", -1))
		for raw_coord in cells:
			var coord := Vector2i(raw_coord)
			if task.attempted_descent_origins.has(coord):
				continue
			var frontier := _descent_frontier(coord)
			if frontier == DescentFrontier.CLOSED:
				continue
			if frontier == DescentFrontier.UNSUPPORTED:
				saw_unsupported = true
				continue
			var position: Vector2 = Level.map.getTilePos(coord)
			var outward_distance := _path_distance(keeper.global_position, position)
			var return_distance := _path_distance(position, _home_position())
			if not is_finite(outward_distance) or not is_finite(return_distance):
				saw_unreachable = true
				continue
			if not _descent_frontier_trip_is_safe(outward_distance, return_distance):
				saw_wave_unsafe = true
				continue
			candidates.append({
				"coord": coord,
				"distance": outward_distance,
				"row": row,
			})
			deepest_row = maxi(deepest_row, row)
	var best_coord := NO_COORD
	var best_distance := INF
	var best_row := -1
	var best_spread := -1
	for candidate in candidates:
		var row := int(candidate.row)
		if row < deepest_row - _branch_row_step():
			continue
		var coord := Vector2i(candidate.coord)
		var outward_distance := float(candidate.distance)
		var spread := absi(coord.x - keeper_coord.x)
		if spread < best_spread:
			continue
		if spread == best_spread and row < best_row:
			continue
		if spread == best_spread and row == best_row and outward_distance > best_distance:
			continue
		if spread == best_spread and row == best_row and is_equal_approx(outward_distance, best_distance) and best_coord != NO_COORD and coord.x < best_coord.x:
			continue
		best_coord = coord
		best_distance = outward_distance
		best_row = row
		best_spread = spread
	if best_coord != NO_COORD:
		return {
			"status": FrontierSearch.READY,
			"coord": best_coord,
			"row": best_row,
		}
	if saw_wave_unsafe:
		return {"status": FrontierSearch.WAITING_WAVE}
	if saw_unreachable:
		return {
			"status": FrontierSearch.BLOCKED,
			"reason": "Recorded descent frontiers are not reachable through the open A* graph; map completion is not claimed",
		}
	if saw_unsupported:
		return {
			"status": FrontierSearch.BLOCKED,
			"reason": "Only unsupported revealed descent frontiers remain; map completion is not claimed",
		}
	return {
		"status": FrontierSearch.BLOCKED,
		"reason": "No untried recorded descent frontier remains; map completion is not claimed",
	}

func _descent_frontier(coord: Vector2i) -> DescentFrontier:
	var below := coord + Vector2i.DOWN
	if not Level.map.visibleTileCoords.has(below):
		return DescentFrontier.OPEN
	if int(Level.map.visibleTileCoords[below]) == Data.TILE_EMPTY:
		return DescentFrontier.CLOSED
	var tile = Level.map.getTile(below)
	if not tile is Tile:
		return DescentFrontier.UNSUPPORTED
	if tile.type == CONST.BORDER:
		return DescentFrontier.CLOSED
	return DescentFrontier.OPEN if tile.get_meta("destructable", false) else DescentFrontier.UNSUPPORTED

func _descent_frontier_trip_is_safe(outward_distance: float, return_distance: float) -> bool:
	var wave_time := _wave_time()
	if not is_finite(wave_time):
		return true
	var speed := _effective_speed(keeper.carriedCarryables.size(), _planning_base_speed(), _carry_loss())
	if not is_finite(speed) or speed <= 0.0:
		return false
	var seconds := (outward_distance + return_distance) / speed
	return seconds + STATION_ENTRY_SECONDS + TICK < wave_time

func _finish_terminal_descent(task: Dictionary, reason: String) -> void:
	task.mining_outcome = MiningOutcome.BACKTRACK_PENDING
	task.mining_outcome_reason = reason
	task.resume_coord = NO_COORD
	task.branch_entry_coord = NO_COORD
	task.active_corridor_cells.clear()
	_release_all()

func _fail(reason: String) -> void:
	ModLoaderLog.error(reason + " tasks=" + str(_status_tasks()), LOG_NAME)
	_record("teacher_failed", reason, null)
	failed.emit(reason)
