extends Node

signal failed(reason: String)
signal recording_finished

const GADGET_CATALOG = preload("res://mods-unpacked/LemonNekoGH-YoloDataCollector/gadget_catalog.gd")
const SUPPLEMENT_CATALOG = preload("res://mods-unpacked/LemonNekoGH-YoloDataCollector/supplement_catalog.gd")

enum State { EXPLORE, INTERACTION, CARRY, RETURN, UPGRADE, DEFEND, RECOVER }
enum ExploreMode { DESCEND, BRANCH, BYPASS }
enum MiningOutcome { ACTIVE, BACKTRACK_PENDING, WAITING_WAVE, BLOCKED }
enum DescentFrontier { CLOSED, OPEN, UNSUPPORTED }
enum FrontierSearch { READY, WAITING_WAVE, BLOCKED }
enum CacheCleanupMode { NONE, PENDING_DEFENSE, ACTIVE }
enum UpgradeIntent { COMBAT, REPAIR, DRILL, MOBILITY }
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
	"state", "explore_mode", "pending_intents", "active_upgrade_intent", "active_upgrade_id",
	"active_upgrade_fulfills", "active_upgrade_arm", "combat_attack_next", "mobility_arm",
	"drill_hits_by_coord", "wave_start_missing_health", "wave_start_max_health",
	"last_wave_health_loss", "wave_health_tracking", "repair_target_health", "caches", "vein",
	"ore", "ore_approach_coord", "nav_travel_coord", "explore_resume_mode", "cache_cleanup_mode",
	"interaction_wait_steps", "gadget_recovery_coord",
	"gadget_recovery_attempts",
	"cave_activation_pending", "cave_approach_coord",
	"cave_harvest_targets", "interaction_prior_drop_uids",
	"completed_resource_caves", "branch_row", "branch_side",
	"branch_entry_coord", "bypass_side", "bypass_reversed", "mining_outcome",
	"mining_outcome_reason", "completed_corridors", "active_corridor_cells",
	"attempted_descent_origins",
]
const CHECKPOINT_REFS := [
	"carry", "artifact_chamber", "gadget_drop", "cave_task", "interaction_resource",
]
const CHECKPOINT_REF_SETS := ["ignored_cache_drops"]
const TICK := 0.1
const MOBILITY_RETURN_TARGET_SECONDS := 15.0
const STATION_ENTRY_SECONDS := 2.0
const CARRY_PICKUP_SECONDS := 0.35
const CARRY_PREVIEW_INTERVAL := 1.0
const ARTIFACT_UI_STEP_LIMIT := 40
const GADGET_RECOVERY_LIMIT := 3
const INTERACTION_WAIT_LIMIT := 150
const MOBILITY_CAPACITY_RATIO_THRESHOLD := 0.75
const CACHE_CLEANUP_LOAD_MULTIPLIER := 2
const MIN_SPEED_RATIO := 0.55
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
	[UpgradeIntent.COMBAT, UpgradeIntent.REPAIR],
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
var state := State.EXPLORE
var explore_mode := ExploreMode.DESCEND
var keeper: Keeper
var dome: Dome
var bindings := {}
var held := {}
var pending_intents := {}
var active_upgrade_intent := -1
var active_upgrade_id := ""
var active_upgrade_fulfills := false
var active_upgrade_arm := -1
var combat_attack_next := true
var mobility_arm := MobilityArm.SPEED
var drill_hits_by_coord := {}
var wave_start_missing_health := 0.0
var wave_start_max_health := 0.0
var last_wave_health_loss := 0.0
var wave_health_tracking := false
var repair_target_health := 0.0
var observed_properties: Array[String] = []
var caches: Array[Vector2] = []
var vein: Array[Vector2i] = []
var ore := NO_COORD
var ore_approach_coord := NO_COORD
var nav_travel_coord := NO_COORD
var explore_resume_mode := -1
var cache_cleanup_mode := CacheCleanupMode.NONE
var ignored_cache_drops := {}
var carry: Drop
var carry_plan := {}
var carry_preview_cache := {}
var carry_preview_refresh_at := 0.0
var artifact_chamber: Chamber
var gadget_drop: Drop
var interaction_wait_steps := 0
var gadget_recovery_coord := NO_COORD
var gadget_recovery_attempts := 0
var cave_task: Cave
var interaction_resource: Drop
var scanner_receiver: ResourceGrabber
var cave_activation_pending := false
var cave_approach_coord := NO_COORD
var cave_harvest_targets: Array[NodePath] = []
var interaction_prior_drop_uids := {}
var cave_resource_type := ""
var cave_observed_value := 0.0
var deferred_cave: Cave
var completed_resource_caves := {}
var branch_row := -1000000
var branch_side := 1
var branch_entry_coord := NO_COORD
var bypass_side := 1
var bypass_reversed := false
var mining_outcome := MiningOutcome.ACTIVE
var mining_outcome_reason := ""
var completed_corridors: Array[Dictionary] = []
var active_corridor_cells := {}
var attempted_descent_origins := {}
var tick_time := 0.0
var delay := 0.0
var pickup_failures := 0
var ui_steps := 0
var closing_upgrade := false
var artifact_offer_id := StringName()
var artifact_ui_steps := 0
var artifact_ui_delay := 0.0
var artifact_confirming := false
var choice_type := StringName()
var progress_action := StringName()
var progress_origin := Vector2.ZERO
var stalled := 0.0
var interrupted := State.EXPLORE
var probe_index := 0
var probe_count := 0
var probe_time := 0.0
var probe_origin := Vector2.ZERO
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
	pending_intents[UpgradeIntent.DRILL] = true
	active_upgrade_intent = -1; active_upgrade_id = ""
	combat_attack_next = _bought_count(ATTACK_UPGRADES) <= _bought_count(HEALTH_UPGRADES)
	mobility_arm = MobilityArm.SPEED
	drill_hits_by_coord.clear(); carry_plan.clear(); carry_preview_cache.clear()
	ore_approach_coord = NO_COORD; nav_travel_coord = NO_COORD; explore_resume_mode = -1
	cache_cleanup_mode = CacheCleanupMode.NONE; ignored_cache_drops.clear()
	_reset_artifact_choice()
	_reset_artifact_retrieval()
	_reset_cave_task()
	deferred_cave = null
	completed_resource_caves.clear()
	carry_preview_refresh_at = 0.0
	wave_health_tracking = _wave("wavepresent") or _wave("wavebattle")
	wave_start_max_health = _dome_max_health()
	wave_start_missing_health = maxf(wave_start_max_health - _dome_health(), 0.0)
	last_wave_health_loss = 0.0; repair_target_health = 0.0
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
	if keeper.isInsideStation:
		state = State.DEFEND if _leaf() == "BattleInputProcessor" else State.RETURN
	else:
		state = State.EXPLORE
	explore_mode = ExploreMode.DESCEND
	branch_row = -1000000; branch_side = 1
	branch_entry_coord = NO_COORD
	nav_travel_coord = Level.map.getTileCoord(_home_position())
	explore_resume_mode = ExploreMode.DESCEND
	mining_outcome = MiningOutcome.ACTIVE
	mining_outcome_reason = ""
	completed_corridors.clear()
	active_corridor_cells.clear()
	attempted_descent_origins.clear()
	attempted_descent_origins[nav_travel_coord] = true
	caches.clear()
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
	running = false; keeper = null; carry = null; carry_plan.clear(); carry_preview_cache.clear()
	_reset_laser_aim()
	cache_cleanup_mode = CacheCleanupMode.NONE; ignored_cache_drops.clear()
	_reset_artifact_choice()
	_reset_artifact_retrieval()
	_reset_cave_task()
	deferred_cave = null
	completed_resource_caves.clear()
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
	if _handle_artifact_choice(delta):
		_release_all(); _reset_progress()
		return
	if not running:
		return
	if _blocked():
		_release_all(); _reset_progress()
		return

	delay = maxf(delay - delta, 0.0)
	if state != State.RECOVER and state != State.UPGRADE and state != State.DEFEND:
		_track_progress(delta)
	if not running or delay > 0.0:
		return
	tick_time += delta
	if tick_time < TICK:
		return
	tick_time = 0.0
	match state:
		State.EXPLORE: _explore()
		State.INTERACTION: _interaction()
		State.CARRY: _carry()
		State.RETURN: _return()
		State.UPGRADE: _upgrade()
		State.DEFEND: _defend()
		State.RECOVER: _recover()

func _physics_process(_delta: float) -> void:
	if not running or state != State.DEFEND:
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
	elif not OS.has_feature("movie") or movie != directory.path_join(RECORDING_MOVIE):
		push_error("Movie Maker output does not match the recording session")
		get_tree().quit(1)
	elif window_size != RECORDING_RESOLUTION:
		push_error(
			"Recording window is %s instead of %s"
			% [str(window_size), str(RECORDING_RESOLUTION)]
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
			if not parsed is Dictionary or int(parsed.get("version", 0)) != 4:
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
	var refs := {}
	for field in CHECKPOINT_REFS:
		refs[field] = _checkpoint_ref(get(field))
	for field in CHECKPOINT_REF_SETS:
		refs[field] = []
		for value in get(field):
			var ref = _checkpoint_ref(value)
			if ref != null:
				refs[field].append(ref)
	return {"version": 4, "values": values, "refs": refs}

func _restore_checkpoint(data: Dictionary) -> String:
	var values: Dictionary = data.get("values", {})
	for field in CHECKPOINT_FIELDS:
		if not values.has(field):
			return "Teacher checkpoint is missing state field: " + field
		set(field, str_to_var(values[field]))
	if not data.get("refs") is Dictionary:
		return "Teacher checkpoint references are missing"
	var refs: Dictionary = data["refs"]
	for field in CHECKPOINT_REFS:
		if not refs.has(field):
			return "Teacher checkpoint is missing reference field: " + field
		var encoded = refs.get(field)
		var restored = _restore_checkpoint_ref(encoded)
		if encoded != null and not is_instance_valid(restored):
			return "Official save did not restore teacher reference: " + field
		set(field, restored)
	for field in CHECKPOINT_REF_SETS:
		if not refs.has(field):
			return "Teacher checkpoint is missing reference field: " + field
		if not refs[field] is Array:
			return "Teacher checkpoint reference set is malformed: " + field
		var restored := {}
		for encoded in refs[field]:
			var object = _restore_checkpoint_ref(encoded)
			if not is_instance_valid(object):
				return "Official save did not restore teacher reference set: " + field
			restored[object] = true
		set(field, restored)
	cave_resource_type = str(RESOURCE_CAVE_DROP_TYPES.get(_active_cave_kind(), ""))
	carry_preview_cache.clear()
	carry_preview_refresh_at = 0.0
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
	for candidate in get_tree().get_nodes_in_group(group):
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

func _record(type: String, reason: String, transition) -> void:
	if recording_file == null or recording_terminal:
		return
	pending_recording_events.append({
		"movie_frame": Engine.get_process_frames(), "type": type, "reason": reason,
		"transition": transition, "state": get_status_snapshot(),
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
		"teacher": {
			"state": State.keys()[state],
			"explore_mode": ExploreMode.keys()[explore_mode] if state == State.EXPLORE else null,
			"mining_outcome": MiningOutcome.keys()[mining_outcome],
			"mining_outcome_reason": mining_outcome_reason,
			"power_core_phase": _power_core_status(),
			"artifact_choice_type": String(choice_type) if not choice_type.is_empty() else null,
		},
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
		if drop is Drop and (drop.type == CONST.GADGET or drop.type == CONST.POWERCORE):
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

func _explore() -> void:
	var resource_search_type := _exclusive_resource_search_type()
	var exclusive_resource_search := not resource_search_type.is_empty()
	if _wave("wavepresent"):
		_change(State.RETURN, "The monster wave has started")
		return
	if not exclusive_resource_search and _scan_interaction():
		return
	if not exclusive_resource_search and cache_cleanup_mode == CacheCleanupMode.ACTIVE:
		if keeper.isInsideStation or _leaf() != "Keeper1InputProcessor":
			_change(State.RETURN, "The active cache cleanup must finish leaving the station")
			return
		if _reachable_cached_resource_count() <= 0:
			_change_cache_cleanup(CacheCleanupMode.NONE, "No known reachable cached resource remains")
		elif _begin_carry("The active cache cleanup starts another trip"):
			return
		elif not running:
			return
		elif not keeper.isInsideDome or _wave_needed():
			_change(State.RETURN, "No cache cleanup trip remains safe before defense")
			return
		else:
			var cleanup_target := _next_upgrade_target()
			var cleanup_upgrade_id: String = cleanup_target.get("id", "")
			if not cleanup_upgrade_id.is_empty() and _upgrade_ready(cleanup_upgrade_id):
				_change(State.RETURN, "Cache cleanup requested an affordable mobility or resource upgrade")
				return
			_release_all()
			delay = minf(CARRY_PREVIEW_INTERVAL, maxf(_wave_time() - STATION_ENTRY_SECONDS, TICK))
			return
	if mining_outcome == MiningOutcome.BACKTRACK_PENDING or mining_outcome == MiningOutcome.WAITING_WAVE:
		var target := _next_upgrade_target()
		var id: String = target.get("id", "")
		if _wave_needed() or (not exclusive_resource_search and not id.is_empty() and _upgrade_ready(id)):
			_change(State.RETURN, "A station task takes priority over descent backtracking")
			return
		var search := _find_backtrack_frontier()
		var search_status := int(search.get("status", FrontierSearch.BLOCKED))
		if search_status == FrontierSearch.READY:
			_adopt_descent_frontier(
				Vector2i(search["coord"]),
				int(search["row"]) + _branch_row_step(),
				"The nearest untried descent frontier on a completed branch corridor was selected"
			)
			return
		if search_status == FrontierSearch.WAITING_WAVE:
			mining_outcome = MiningOutcome.WAITING_WAVE
			mining_outcome_reason = "No descent frontier has a safe round trip before the next wave"
			_release_all()
			delay = minf(CARRY_PREVIEW_INTERVAL, maxf(_wave_time() - STATION_ENTRY_SECONDS, TICK))
			return
		mining_outcome = MiningOutcome.BLOCKED
		mining_outcome_reason = str(search.get(
			"reason",
			"No untried recorded descent frontier remains; map completion is not claimed"
		))
		ModLoaderLog.info(mining_outcome_reason, LOG_NAME)
		_release_all()
		return
	if mining_outcome == MiningOutcome.BLOCKED:
		if exclusive_resource_search:
			_fail("No reachable physical %s remains for the active side task" % resource_search_type)
			return
		var blocked_target := _next_upgrade_target()
		var blocked_id: String = blocked_target.get("id", "")
		if _wave_needed() or (not blocked_id.is_empty() and _upgrade_ready(blocked_id)):
			_change(State.RETURN, "Mining is blocked and a station task is ready")
			return
		_release_all()
		return
	if not exclusive_resource_search and keeper.isInsideDome and _must_return_now():
		var waiting_target := _next_upgrade_target()
		var waiting_id: String = waiting_target.get("id", "")
		if not waiting_id.is_empty() and _upgrade_ready(waiting_id):
			_change(State.RETURN, "A pending upgrade became affordable while waiting in the dome")
			return
		if _wave_needed():
			_change(State.RETURN, "The wave became imminent while waiting in the dome")
			return
		_release_all()
		return
	if not exclusive_resource_search:
		var carry_preview := _carry_window_plan()
		if not carry_preview.is_empty():
			if _begin_carry("The planned carry window has opened", carry_preview):
				return
			if not running:
				return
		if _must_return_now():
			_change(State.RETURN, "No cache trip remains safe; return to the dome")
			return
	var cell: Vector2i = Level.map.getTileCoord(keeper.global_position)
	if nav_travel_coord != NO_COORD:
		if explore_resume_mode != ExploreMode.DESCEND and explore_resume_mode != ExploreMode.BRANCH:
			_fail("The open navigation target has no supported continuation")
			return
		var travel_position: Vector2 = Level.map.getTilePos(nav_travel_coord)
		var reached := cell == nav_travel_coord
		if explore_resume_mode == ExploreMode.DESCEND:
			reached = reached and absf(keeper.global_position.x - travel_position.x) <= 6.0
		if reached:
			var continuation := explore_resume_mode
			nav_travel_coord = NO_COORD
			explore_resume_mode = -1
			_release_all()
			_change_exploration(continuation, "The keeper reached the saved open navigation target")
			_reset_progress()
			delay = 0.2
			return
		if _move_open(travel_position):
			return
		_fail("No open path remains to the saved navigation target")
		return

	if exclusive_resource_search and _scan_interaction(resource_search_type):
		return

	if explore_mode == ExploreMode.DESCEND:
		if branch_row < -1000:
			branch_row = maxi(cell.y + _branch_row_step(), 1)
		if cell.y < branch_row:
			var below = Level.map.getTile(cell + Vector2i.DOWN)
			if below is Tile and below.type == CONST.BORDER:
				_release_all()
				_change_exploration(ExploreMode.BYPASS, "Revealed border blocks the shaft below")
				bypass_side = 1
				bypass_reversed = false
				_reset_progress()
				delay = 0.2
				return
			_hold([&"ui_down"])
			return
		branch_entry_coord = cell
		active_corridor_cells.clear()
		active_corridor_cells[cell] = true
		_change_exploration(ExploreMode.BRANCH, "The target fishbone branch row was reached")
	if explore_mode == ExploreMode.BYPASS:
		var bypass_below = Level.map.getTile(cell + Vector2i.DOWN)
		if not (bypass_below is Tile and bypass_below.type == CONST.BORDER):
			_adopt_descent_frontier(
				cell,
				branch_row,
				"The first lateral column that can continue downward was adopted"
			)
			return
		var bypass_next = Level.map.getTile(cell + Vector2i(bypass_side, 0))
		if bypass_next is Tile and bypass_next.type == CONST.BORDER:
			_release_all()
			if bypass_reversed:
				_finish_terminal_descent("Both lateral bypass directions ended at revealed border")
				return
			bypass_reversed = true
			bypass_side = -1
			_reset_progress()
			delay = 0.2
			return
		_hold([&"ui_right" if bypass_side > 0 else &"ui_left"])
		return
	active_corridor_cells[cell] = true
	var branch_next = Level.map.getTile(cell + Vector2i(branch_side, 0))
	if branch_next is Tile and branch_next.type == CONST.BORDER:
		_release_all()
		if branch_entry_coord == NO_COORD:
			_fail("The fishbone branch has no saved open shaft intersection")
			return
		branch_side *= -1
		nav_travel_coord = branch_entry_coord
		explore_resume_mode = ExploreMode.BRANCH
		if branch_side > 0:
			_record_completed_corridor(branch_row)
			attempted_descent_origins[branch_entry_coord] = true
			branch_row += _branch_row_step()
			explore_resume_mode = ExploreMode.DESCEND
		_reset_progress()
		delay = 0.2
		return
	_hold([&"ui_right" if branch_side > 0 else &"ui_left"])

func _interaction() -> void:
	var carried_artifact := _carried_artifact()
	if is_instance_valid(carried_artifact):
		var label := "Power Core" if carried_artifact.type == CONST.POWERCORE else "chamber gadget"
		var reattached := gadget_recovery_coord != NO_COORD
		gadget_drop = carried_artifact
		gadget_recovery_coord = NO_COORD
		interaction_wait_steps = 0
		if carried_artifact.type == CONST.POWERCORE:
			_record("power_core_acquired", "Exact Power Core attached", null)
		var reason := "The %s requires an exclusive direct return" % label
		if reattached:
			reason = "The detached %s was reattached; resume its direct return" % label
		_change(State.RETURN, reason)
		return
	if _wave_needed() or _wave("wavepresent") or _must_return_now():
		if not is_instance_valid(gadget_drop):
			_abandon_interaction("The local interaction scan expired when defense took priority")
		_change(State.RETURN, "The active interaction must yield to the next wave")
		return
	if is_instance_valid(cave_task):
		_run_cave_task()
	elif gadget_recovery_coord != NO_COORD:
		_mine_gadget_recovery()
	elif is_instance_valid(artifact_chamber) and artifact_chamber.drop_type == CONST.POWERCORE:
		_run_power_core_task()
	elif is_instance_valid(artifact_chamber):
		_mine_gadget_chamber()
	else:
		_mine()

func _mine() -> void:
	if ore == NO_COORD or not Level.map.getTile(ore) is Tile or not Level.map.isRevealed(ore):
		ore_approach_coord = NO_COORD
		ore = _adjacent_ore()
	if ore == NO_COORD:
		_record_cache(); _change(State.EXPLORE, "The revealed ore vein has been cleared")
		return
	if not vein.has(ore):
		vein.append(ore)
		var route := _tile_interaction_route(ore)
		ore_approach_coord = NO_COORD if float(route.astar_seconds) > float(route.direct_seconds) else Vector2i(route.approach_coord)
	var current_coord: Vector2i = Level.map.getTileCoord(keeper.global_position)
	if (
		ore_approach_coord != NO_COORD
		and absi(current_coord.x - ore.x) + absi(current_coord.y - ore.y) > 1
	):
		if _move_open(Level.map.getTilePos(ore_approach_coord)):
			return
		ore_approach_coord = NO_COORD
	_hold(_axis(Level.map.getTilePos(ore)))

func _carry() -> void:
	if _wave("wavepresent"):
		_change(State.RETURN, "The monster wave has started")
		return
	if not is_instance_valid(carry) or carry.isCarried():
		carry = null
		if not _choose_planned_carry():
			_change(State.RETURN, "The carry plan is complete or no planned resource remains")
			return
	if not _planned_pickup_is_safe(carry):
		_change(State.RETURN, "The next planned pickup is no longer safe")
		return
	var focused = keeper.focussedCarryable
	if (
		is_instance_valid(focused)
		and focused is Drop
		and focused.carryableType == "resource"
		and not focused.absorbed
		and not focused.independent
		and not focused.isCarried()
		and focused.type == carry.type
	):
		carry = focused
		if pickup_failures >= 3:
			_ignore_failed_cleanup_drop()
			_change(State.RETURN, "Repeated resource pickup attempts failed")
			return
		pickup_failures += 1
		_release_all(); _tap(&"keeper1_pickup"); delay = 0.35
		return
	if _move_open(carry.global_position) and not held.is_empty():
		return
	_release_all()
	pickup_failures += 1
	if pickup_failures >= 3:
		_ignore_failed_cleanup_drop()
		_change(State.RETURN, "Repeated resource pickup or path attempts failed")
		return
	carry = null

func _return() -> void:
	if is_instance_valid(gadget_drop) and not is_instance_valid(_carried_artifact()):
		var tracked_gadget := gadget_drop
		if (
			is_instance_valid(tracked_gadget)
			and not tracked_gadget.absorbed
			and not tracked_gadget.independent
			):
			if tracked_gadget.isCarried():
				_fail("The tracked chamber gadget attached to an unexpected carrier")
				return
			if not _wave("wavepresent") and not _wave("wavebattle"):
				if keeper.isInsideStation and _leaf() != "Keeper1InputProcessor":
					_release_all()
					if _leaf() == "StationInputProcessor" or _leaf() == "BattleInputProcessor":
						_tap(&"ui_cancel")
						delay = 0.5
					return
				_begin_detached_gadget_recovery(tracked_gadget)
				return
		else:
			_wait_for_interaction("Authoritative gadget handoff did not open its mandatory choice popup")
			return
	if keeper.isInsideStation:
		_release_all(); var leaf := _leaf()
		if leaf == "StationInputProcessor":
			if is_instance_valid(artifact_chamber) and (_wave("wavepresent") or _wave("wavebattle")):
				_change(State.DEFEND, "Finish the active wave before resuming gadget retrieval")
				return
			var target := _next_upgrade_target()
			var id: String = target.get("id", "")
			if not id.is_empty() and _upgrade_ready(id):
				_change(State.UPGRADE, "A pending upgrade is affordable")
				return
		if _wave_needed():
			_change(State.DEFEND, "A monster wave is active or imminent")
			return
		if leaf == "StationInputProcessor":
			_tap(&"ui_cancel")
			_change(State.EXPLORE, "No upgrade or defense task requires the station")
			delay = 0.5
		elif leaf == "Keeper1InputProcessor":
			_change(State.EXPLORE, "No upgrade or defense task requires the station")
		return

	_travel_to_station()

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

func _upgrade() -> void:
	var leaf := _leaf()
	if leaf == "StationInputProcessor":
		if closing_upgrade:
			_clear_active_upgrade()
			if _wave_needed():
				_change(State.DEFEND, "The upgrade menu closed and the wave requires defense")
			else:
				_change(State.RETURN, "The upgrade menu closed; resume station task selection")
			return
		if not _freeze_upgrade_target():
			closing_upgrade = true
			return
		_tap(&"dome_upgrades")
		delay = 0.6
		return
	if leaf != "UpgradesInputProcessor":
		return
	if closing_upgrade or active_upgrade_id.is_empty():
		_tap(&"ui_cancel"); delay = 0.5
		return

	var processor = InputSystem.getLastChild(keeper.deviceId)
	if not is_instance_valid(processor) or not is_instance_valid(processor.popup):
		_consume_upgrade_step("Upgrade popup did not become available")
		return
	var tree = processor.popup.find_child("TechTree")
	if not is_instance_valid(tree):
		_consume_upgrade_step("Upgrade tree did not become available")
		return
	var current = tree.focussedTechPanel
	var target = null
	for panel in get_tree().get_nodes_in_group(keeper.playerId + "-techpanel"):
		if panel.techId == active_upgrade_id:
			target = panel
			break
	if not is_instance_valid(current) or not is_instance_valid(target):
		_consume_upgrade_step("Could not find intended upgrade panel")
		return
	if current == target:
		if not _active_upgrade_ready():
			closing_upgrade = true
			return
		if int(target.state) != 1:
			_consume_upgrade_step("Intended upgrade panel never became buyable")
			return
		if not _consume_upgrade_step("Game did not confirm intended upgrade purchase"):
			return
		_tap(&"ui_select"); delay = 0.5
		return
	if not _consume_upgrade_step("Could not focus intended upgrade through normal UI actions"):
		return
	var delta: Vector2 = target.global_position - current.global_position
	if absf(delta.x) >= absf(delta.y):
		_tap(&"ui_right" if delta.x > 0.0 else &"ui_left")
	else:
		_tap(&"ui_down" if delta.y > 0.0 else &"ui_up")
	delay = 0.15

func _handle_artifact_choice(delta: float) -> bool:
	var processor = InputSystem.getLastChild(keeper.deviceId)
	var is_gadget_processor := is_instance_valid(processor) and str(processor.name) == "GadgetChoiceInputProcessor"
	if InputSystem.processors_changing:
		return is_gadget_processor or not artifact_offer_id.is_empty() or artifact_confirming
	if not is_gadget_processor:
		if not choice_type.is_empty() or not artifact_offer_id.is_empty() or artifact_confirming:
			_finish_artifact_choice()
		return false

	artifact_ui_delay = maxf(artifact_ui_delay - delta, 0.0)
	if artifact_ui_delay > 0.0:
		return true
	if not is_instance_valid(processor.popup):
		_wait_for_artifact_choice("Artifact choice popup did not become available")
		return true
	var popup = processor.popup
	var popup_type := StringName(str(popup.droptype))
	if popup_type != StringName(CONST.GADGET) and popup_type != StringName(CONST.POWERCORE):
		_fail("Unsupported artifact choice type: " + str(popup.droptype))
		return true
	if choice_type.is_empty():
		choice_type = popup_type
	elif choice_type != popup_type:
		_fail("Artifact choice type changed while the modal was open")
		return true
	if not bool(popup.animationDone) or popup.offersById.is_empty():
		_wait_for_artifact_choice("Artifact offers did not become available")
		return true
	if artifact_offer_id.is_empty():
		artifact_offer_id = _choose_artifact_offer(popup)
		artifact_ui_steps = 0
		if artifact_offer_id.is_empty():
			_fail("Artifact popup has neither a supported offer nor the shred fallback")
			return true

	var reroll_button = popup.find_child("RerollButton")
	var target = popup.offersById.get(String(artifact_offer_id))
	var choosing_reroll: bool = (
		not _artifact_offer_matches_current_intent(artifact_offer_id)
		and is_instance_valid(reroll_button)
		and reroll_button.visible
		and not reroll_button.disabled
		and int(Data.getInventory(CONST.WATER, keeper.teamId)) > 0
	)
	if choosing_reroll:
		target = reroll_button

	if not is_instance_valid(target) or bool(target.disabled):
		_fail("Chosen artifact action is no longer selectable: " + String(artifact_offer_id))
		return true
	if artifact_confirming:
		_wait_for_artifact_choice("Game did not confirm artifact selection")
		return true

	var current = popup.get_viewport().gui_get_focus_owner()
	if not is_instance_valid(current) or not current is Control:
		_wait_for_artifact_choice("Artifact popup did not expose a focused option")
		return true
	if current == target:
		var selected: Variant = popup.selectedGadget
		if choosing_reroll:
			if not selected is Dictionary or int(selected.get("reroll", 0)) != 1:
				_wait_for_artifact_choice("Focused artifact reroll action did not become selected")
				return true
			_record("artifact_reroll", "Unsuitable artifact offers rerolled through the normal UI", null)
			_tap(&"ui_select")
			artifact_offer_id = StringName()
			artifact_ui_steps = 0
			artifact_ui_delay = 0.5
			return true
		if not selected is Dictionary or StringName(str(selected.get("id", ""))) != artifact_offer_id:
			_wait_for_artifact_choice("Focused artifact offer did not become selected")
			return true
		_tap(&"ui_select")
		artifact_confirming = true
		artifact_ui_steps = 0
		artifact_ui_delay = TICK
		return true

	if not _consume_artifact_ui_step("Could not focus the chosen artifact action through normal UI actions"):
		return true
	var options = popup.find_child("Gadgets")
	if not is_instance_valid(options):
		_fail("Artifact popup has no options container")
		return true
	if choosing_reroll and current.get_parent() == options:
		_tap(&"ui_up")
		artifact_ui_delay = 0.15
		return true
	if not choosing_reroll and current.get_parent() != options:
		_tap(&"ui_down")
		artifact_ui_delay = 0.15
		return true
	var focus_delta: Vector2 = target.global_position - current.global_position
	if absf(focus_delta.x) >= absf(focus_delta.y):
		_tap(&"ui_right" if focus_delta.x > 0.0 else &"ui_left")
	else:
		_tap(&"ui_down" if focus_delta.y > 0.0 else &"ui_up")
	artifact_ui_delay = 0.15
	return true

func _choose_artifact_offer(popup) -> StringName:
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

func _artifact_offer_matches_current_intent(offered_id: StringName) -> bool:
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

func _consume_artifact_ui_step(reason: String) -> bool:
	artifact_ui_steps += 1
	if artifact_ui_steps <= ARTIFACT_UI_STEP_LIMIT:
		return true
	_fail(reason)
	return false

func _wait_for_artifact_choice(reason: String) -> void:
	if _consume_artifact_ui_step(reason):
		artifact_ui_delay = TICK

func _finish_artifact_choice() -> void:
	var selected_id := artifact_offer_id
	var was_confirming := artifact_confirming
	var selected_type := choice_type
	_reset_artifact_choice()
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
	_reset_artifact_retrieval()

func _reset_artifact_choice() -> void:
	artifact_offer_id = StringName()
	artifact_ui_steps = 0
	artifact_ui_delay = 0.0
	artifact_confirming = false
	choice_type = StringName()

func _scan_interaction(required_ore_type := "") -> bool:
	if not required_ore_type.is_empty():
		return _claim_ore_interaction(required_ore_type)
	return (
		_claim_chamber_interaction(CONST.POWERCORE)
		or _claim_chamber_interaction(CONST.GADGET)
		or _claim_cave_interaction()
		or _claim_ore_interaction()
	)

func _claim_chamber_interaction(tile_type: String) -> bool:
	var best: Chamber
	var best_distance := INF
	var best_plan := {}
	for candidate in get_tree().get_nodes_in_group("chamber"):
		if not candidate is Chamber or candidate.drop_type != tile_type:
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
	var subtype := "supply" if tile_type == CONST.POWERCORE else "gadget"
	artifact_chamber = best
	_record_interaction_decision("chamber", subtype, Vector2i(best.coord), best_distance, best_plan)
	_change(State.INTERACTION, "A revealed %s Chamber is inside the interaction scan" % subtype.capitalize())
	return true

func _power_core_status():
	if is_instance_valid(artifact_chamber) and artifact_chamber.drop_type == CONST.POWERCORE and is_instance_valid(gadget_drop):
		return "DELIVER_CORE"
	if not is_instance_valid(artifact_chamber) or artifact_chamber.drop_type != CONST.POWERCORE:
		return null
	if is_instance_valid(artifact_chamber.tileCover) and not artifact_chamber.tileCover.get_used_cells(MapData.DEFAULT_LAYER).is_empty():
		return "EXCAVATE"
	var grabber = artifact_chamber.find_child("ResourceGrabber")
	if is_instance_valid(grabber) and not bool(grabber.spent):
		if not is_instance_valid(interaction_resource):
			return "SEARCH_WATER"
		return "DELIVER_WATER" if interaction_resource.isCarried() else "FETCH_WATER"
	if artifact_chamber.currentState == Chamber.State.OPEN:
		return "ACQUIRE"
	return "OPENING"

func _run_power_core_task() -> void:
	if not is_instance_valid(artifact_chamber):
		_fail("The active Power Core chamber disappeared")
		return
	if is_instance_valid(artifact_chamber.tileCover) and not artifact_chamber.tileCover.get_used_cells(MapData.DEFAULT_LAYER).is_empty():
		_excavate_chamber(artifact_chamber, CONST.POWERCORE, "Power Core")
		return
	var grabber = artifact_chamber.find_child("ResourceGrabber")
	if not is_instance_valid(grabber):
		_fail("Power Core chamber has no ResourceGrabber")
		return
	if bool(grabber.spent) and is_instance_valid(interaction_resource):
		_record("power_core_water", "Power Core chamber accepted its physical water", null)
		interaction_resource = null
		interaction_wait_steps = 0
	if not bool(grabber.spent):
		if not _prepare_power_core_receiver(grabber):
			return
		if ore != NO_COORD:
			_mine_exclusive_resource(CONST.WATER, "the Power Core chamber")
			return
		if _select_interaction_resource(CONST.WATER):
			if interaction_resource.isCarried():
				_deliver_power_core_water()
			else:
				_fetch_interaction_resource("Power Core chamber")
		else:
			_explore()
		return
	if artifact_chamber.currentState == Chamber.State.OPEN:
		_activate_artifact_chamber()
		return
	if artifact_chamber.currentState == Chamber.State.EMPTY:
		_wait_for_interaction("Activated Power Core chamber did not attach its core")
		return
	_wait_for_interaction("Power Core chamber did not finish opening")

func _prepare_power_core_receiver(grabber: ResourceGrabber) -> bool:
	var target: Vector2i = Level.map.getTileCoord(grabber.global_position) + Vector2i.UP
	var tile = Level.map.getTile(target)
	if not tile is Tile:
		if is_finite(_path_distance(keeper.global_position, Level.map.getTilePos(target))):
			return true
		_wait_for_interaction("The Power Core water receiver cap is not confirmed open")
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
	if not is_finite(route.astar_seconds) and not is_finite(route.direct_seconds):
		_wait_for_interaction("No revealed route reaches the Power Core water receiver cap")
		return false
	interaction_wait_steps = 0
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

func _deliver_power_core_water() -> void:
	var grabber = artifact_chamber.find_child("ResourceGrabber")
	if not is_instance_valid(grabber):
		_fail("Power Core chamber has no ResourceGrabber")
		return
	var delivery_approach: Vector2i = Level.map.getTileCoord(grabber.global_position) + Vector2i.UP
	if Level.map.getTileCoord(keeper.global_position) != delivery_approach:
		if not _move_open(Level.map.getTilePos(delivery_approach)):
			_wait_for_interaction("No open path reaches the Power Core water receiver")
		return
	var actions := _axis(grabber.global_position)
	if not actions.is_empty():
		_hold(actions)
		interaction_wait_steps = 0
		return
	_wait_for_interaction("No open path reaches the Power Core water receiver")

func _claim_cave_interaction() -> bool:
	if is_instance_valid(deferred_cave):
		var deferred_distance := (
			keeper.global_position.distance_to(deferred_cave.global_position)
			/ GameWorld.TILE_SIZE
		)
		if deferred_distance >= INTERACTION_RADIUS_TILES:
			deferred_cave = null

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
		if not candidate is Cave or candidate.currentState != Cave.State.REVEALED:
			continue
		if candidate == deferred_cave:
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
	cave_task = best
	interaction_wait_steps = 0
	cave_approach_coord = NO_COORD if best_astar_seconds > best_direct_seconds else best_approach_coord
	if _is_resource_cave_kind(best_kind):
		cave_resource_type = RESOURCE_CAVE_DROP_TYPES[best_kind]
		cave_harvest_targets.clear()
		for path in RESOURCE_CAVE_REWARD_PATHS[best_kind]:
			var reward := cave_task.get_node_or_null(path) as Node2D
			if not is_instance_valid(reward) or reward.get("taken") == null:
				_fail("The claimed resource cave does not expose its exact reward nodes")
				return false
			if not bool(reward.get("taken")):
				cave_harvest_targets.append(path)
		if cave_harvest_targets.is_empty():
			_fail("The claimed resource cave has no available rewards to snapshot")
			return false
	_record_interaction_decision("cave", label, Vector2i(best.coord), best_distance, route)
	_change(State.INTERACTION, "A revealed %s Cave is inside the interaction scan" % label)
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

func _active_cave_kind() -> CaveTaskKind:
	return _supported_cave_kind(cave_task) if is_instance_valid(cave_task) else CaveTaskKind.NONE

func _cave_is_unfinished(candidate: Cave, kind: CaveTaskKind) -> bool:
	match kind:
		CaveTaskKind.SCANNER:
			return bool(candidate.get("hasScanner"))
		CaveTaskKind.DRONE:
			return bool(candidate.get("hasDrone"))
		CaveTaskKind.MUSHROOM, CaveTaskKind.HELMET:
			return candidate.canFocusUse(keeper)
		CaveTaskKind.PORTAL:
			return not completed_resource_caves.has(candidate.coord)
		CaveTaskKind.IRON_TREE, CaveTaskKind.COBALT, CaveTaskKind.WATER:
			if completed_resource_caves.has(candidate.coord):
				return false
			for path in RESOURCE_CAVE_REWARD_PATHS[kind]:
				var reward := candidate.get_node_or_null(path) as Node2D
				if is_instance_valid(reward) and reward.get("taken") != null and not bool(reward.get("taken")):
					return true
	return false

func _is_resource_cave_kind(kind: CaveTaskKind) -> bool:
	return RESOURCE_CAVE_DROP_TYPES.has(kind)

func _run_cave_task() -> void:
	if not is_instance_valid(cave_task):
		_fail("The active natural cave disappeared")
		return
	match _active_cave_kind():
		CaveTaskKind.SCANNER:
			_run_scanner_cave_task()
		CaveTaskKind.DRONE:
			_run_drone_cave_task()
		CaveTaskKind.MUSHROOM:
			_run_mushroom_cave_task()
		CaveTaskKind.PORTAL:
			_run_portal_cave_task()
		CaveTaskKind.HELMET:
			_run_helmet_cave_task()
		CaveTaskKind.IRON_TREE, CaveTaskKind.COBALT, CaveTaskKind.WATER:
			_run_resource_cave_task()
		_:
			_fail("The active natural cave kind is unsupported")

func _run_scanner_cave_task() -> void:
	var reveal_distance := float(Data.of("map.revealdistance"))
	if cave_activation_pending or cave_task.canFocusUse(keeper):
		_run_observed_cave_task(
			reveal_distance,
			reveal_distance > cave_observed_value,
			"Scanner",
			"increase reveal distance"
		)
		return
	var carried_iron := keeper.carriedCarryables.filter(
		func(item): return item is Drop and item.type == CONST.IRON
	)
	if is_instance_valid(scanner_receiver):
		if carried_iron.is_empty():
			_wait_for_interaction("Scanner cave did not become usable after accepting two iron")
			return
		if _move_to_cave(scanner_receiver.global_position):
			interaction_wait_steps = 0
			return
		scanner_receiver = _scanner_receiver(scanner_receiver)
		if is_instance_valid(scanner_receiver) and _move_to_cave(scanner_receiver.global_position):
			interaction_wait_steps = 0
			return
		_wait_for_interaction("No route crosses both Scanner cave receivers")
		return
	if carried_iron.size() >= 2:
		interaction_resource = null
		scanner_receiver = _scanner_receiver()
		if not is_instance_valid(scanner_receiver):
			_fail("Scanner cave does not expose two resource receiver positions")
			return
		if _move_to_cave(scanner_receiver.global_position):
			interaction_wait_steps = 0
		else:
			_wait_for_interaction("No route reaches a Scanner cave receiver")
		return
	if _select_scanner_iron(carried_iron.size()):
		_fetch_interaction_resource("Scanner cave", true)
	else:
		_explore()

func _scanner_receiver(excluded = null) -> ResourceGrabber:
	var selected: ResourceGrabber
	var best_distance := -1.0
	for candidate in [cave_task.get("leftRes"), cave_task.get("rightRes")]:
		if not candidate is ResourceGrabber or candidate == excluded:
			continue
		var distance := keeper.global_position.distance_squared_to(candidate.global_position)
		if distance > best_distance:
			selected = candidate
			best_distance = distance
	return selected

func _select_scanner_iron(carried: int) -> bool:
	if is_instance_valid(interaction_resource) and not interaction_resource.isCarried():
		return true
	var resources := _cached_resources()
	var site = null
	var site_distance := INF
	for candidate_site in caches:
		var available := resources.filter(func(drop):
			return drop.type == CONST.IRON and drop.global_position.distance_to(candidate_site) <= GameWorld.TILE_SIZE * 3.0
		)
		if available.size() + carried <= 2:
			continue
		var distance := _path_distance(keeper.global_position, candidate_site)
		if distance < site_distance:
			site = candidate_site
			site_distance = distance
	interaction_resource = null
	if not site is Vector2:
		return false
	var best_distance := INF
	for drop in resources:
		if drop.type != CONST.IRON or drop.global_position.distance_to(site) > GameWorld.TILE_SIZE * 3.0:
			continue
		var distance := _path_distance(keeper.global_position, drop.global_position)
		if distance < best_distance:
			interaction_resource = drop
			best_distance = distance
	return is_instance_valid(interaction_resource)

func _run_drone_cave_task() -> void:
	if not bool(cave_task.get("hasDrone")):
		if bool(cave_task.get("opening")) or not _drone_cave_has_owned_squidley():
			_wait_for_interaction("Drone cave finished opening without an owned Squidley")
			return
		_finish_cave_task("Drone cave spawned its owned Squidley")
		return
	var receiver := cave_task.get_node_or_null("ResourceGrabber") as ResourceGrabber
	if not is_instance_valid(receiver):
		_fail("Drone cave does not expose its exact water receiver")
		return
	if bool(receiver.spent):
		interaction_resource = null
		_wait_for_interaction("Drone cave did not finish spawning its Squidley")
		return
	_run_cave_resource_delivery(CONST.WATER, "Drone cave", receiver)

func _run_mushroom_cave_task() -> void:
	var speed := _planning_base_speed()
	_run_observed_cave_task(
		speed,
		speed > cave_observed_value,
		"Mushroom",
		"increase keeper movement speed"
	)

func _run_helmet_cave_task() -> void:
	var zoom := float(Data.of(keeper.playerId + ".keeper.zoominmine"))
	_run_observed_cave_task(
		zoom,
		not is_equal_approx(zoom, cave_observed_value),
		"Helmet",
		"change the mine camera zoom"
	)

func _run_observed_cave_task(
	observed_value: float,
	success: bool,
	label: String,
	change: String,
) -> void:
	if cave_activation_pending:
		if success:
			_finish_cave_task(
				"%s interaction did %s" % [label, change],
				{"after": observed_value, "before": cave_observed_value}
			)
		else:
			_fail_cave_interaction(
				"%s interaction did not %s" % [label, change],
				observed_value
			)
		return
	_activate_observed_cave(observed_value)

func _activate_observed_cave(observed_value: float) -> void:
	var usable := cave_task.get_node_or_null("Usable") as Node2D
	if not is_instance_valid(usable) or not cave_task.canFocusUse(keeper):
		_fail_cave_interaction("The cave is no longer ready for interaction", observed_value)
		return
	if keeper.focussedUsable == usable and _leaf() == "Keeper1InputProcessor":
		_release_all()
		cave_observed_value = observed_value
		cave_activation_pending = true
		_tap(&"ui_select")
		delay = 0.2
		return
	if not _move_to_cave(usable.global_position):
		_fail_cave_interaction("Neither approach can reach the cave", observed_value)

func _run_portal_cave_task() -> void:
	var target := cave_task.get_node_or_null("TeleportArea") as Node2D
	if not is_instance_valid(target):
		_fail_cave_interaction("The Portal no longer exposes its passive entrance")
		return
	if cave_activation_pending:
		var inventory := float(Data.getInventory(cave_resource_type, keeper.teamId))
		var still_carried := (
			is_instance_valid(interaction_resource)
			and keeper.carriedCarryables.has(interaction_resource)
		)
		if not still_carried and inventory > cave_observed_value:
			completed_resource_caves[cave_task.coord] = true
			if carry == interaction_resource:
				carry = null
			_finish_cave_task(
				"Portal interaction increased stored %s" % cave_resource_type,
				{
					"after": inventory,
					"before": cave_observed_value,
					"detached": true,
					"resource_type": cave_resource_type,
				}
			)
			return
		if still_carried and _move_to_cave(target.global_position):
			interaction_wait_steps = 0
			return
		_release_all()
		interaction_wait_steps += 1
		if interaction_wait_steps > INTERACTION_WAIT_LIMIT:
			_fail_cave_interaction(
				"Portal interaction did not increase stored %s" % cave_resource_type,
				inventory
			)
		return
	if not _select_portal_resource():
		_fail_cave_interaction("No reachable ordinary resource is available in a known cache")
		return
	if keeper.carriedCarryables.has(interaction_resource):
		cave_resource_type = interaction_resource.type
		cave_observed_value = float(Data.getInventory(cave_resource_type, keeper.teamId))
		cave_activation_pending = true
		interaction_wait_steps = 0
		return
	_fetch_interaction_resource("Portal cave")

func _select_portal_resource() -> bool:
	if (
		is_instance_valid(interaction_resource)
		and interaction_resource.type in ORE_TYPES
		and not interaction_resource.absorbed
		and not interaction_resource.independent
	):
		return true
	interaction_resource = null
	for candidate in keeper.carriedCarryables:
		if (
			candidate is Drop
			and candidate.type in ORE_TYPES
			and not candidate.absorbed
			and not candidate.independent
		):
			interaction_resource = candidate
			return true
	var best_distance := INF
	for candidate in _cached_resources():
		if candidate.type not in ORE_TYPES:
			continue
		var distance := _path_distance(keeper.global_position, candidate.global_position)
		if distance >= best_distance:
			continue
		interaction_resource = candidate
		best_distance = distance
	return is_instance_valid(interaction_resource)

func _fail_cave_interaction(reason: String, observed_value = null) -> void:
	var evidence = null
	if observed_value != null:
		evidence = {"after": observed_value, "before": cave_observed_value}
	_record("cave_interaction_failed", reason, evidence)
	deferred_cave = cave_task
	_reset_cave_task()
	_change(State.EXPLORE, reason + "; resume the saved ordinary path")

func _run_resource_cave_task() -> void:
	var label := str(CaveTaskKind.keys()[_active_cave_kind()]).to_lower().replace("_", " ")
	if cave_resource_type.is_empty():
		_fail("The active resource cave has no exact physical reward type")
		return

	if is_instance_valid(interaction_resource):
		if keeper.carriedCarryables.has(interaction_resource):
			if keeper.carriedCarryables.size() != 1:
				_fail("The %s cave reward attached to a non-exclusive load" % label)
				return
			if interaction_wait_steps >= INTERACTION_WAIT_LIMIT:
				_fail("The %s cave reward did not detach through configured input" % label)
				return
			_release_all()
			_tap(&"keeper1_drop")
			interaction_wait_steps += 1
			delay = 0.2
			return
		if interaction_resource.isCarried():
			_fail("The %s cave reward attached to an unexpected carrier" % label)
			return
		if interaction_resource.absorbed or interaction_resource.independent:
			_queue_record("The released resource cave reward entered ordinary resource routing")
		else:
			_record_cache_site(interaction_resource.global_position)
		interaction_resource = null
		interaction_wait_steps = 0

	if cave_harvest_targets.is_empty():
		completed_resource_caves[cave_task.coord] = true
		_finish_cave_task("%s cave released every reward in its initial snapshot" % label.capitalize())
		return

	if cave_activation_pending:
		var spawned := _new_resource_cave_drop(cave_resource_type)
		if is_instance_valid(spawned) and _accept_pending_resource_cave_drop(spawned):
			return
		if not running:
			return
		_wait_for_interaction("The %s cave did not attach its exact physical reward" % label)
		return

	if not keeper.carriedCarryables.is_empty():
		_drop_interaction_cargo()
		return

	var reward := cave_task.get_node_or_null(cave_harvest_targets.front()) as Node2D
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
		for index in range(1, cave_harvest_targets.size()):
			var focused_reward := cave_task.get_node_or_null(cave_harvest_targets[index]) as Node2D
			if (
				is_instance_valid(focused_reward)
				and focused_reward.get_node_or_null("Usable") == keeper.focussedUsable
			):
				var focused_path: NodePath = cave_harvest_targets[index]
				cave_harvest_targets.remove_at(index)
				cave_harvest_targets.push_front(focused_path)
				reward = focused_reward
				usable = keeper.focussedUsable
				break
	if not bool(reward.call(&"canFocusUse", keeper)):
		_wait_for_interaction("The snapshotted %s cave reward is not usable" % label)
		return
	if keeper.focussedUsable == usable and _leaf() == "Keeper1InputProcessor":
		_release_all()
		interaction_prior_drop_uids.clear()
		for candidate in Level.drops.get_all_drops().values():
			if candidate is Drop and candidate.type == cave_resource_type:
				interaction_prior_drop_uids[candidate.UID] = true
		cave_activation_pending = true
		interaction_wait_steps = 0
		_tap(&"ui_select")
		delay = 0.2
		return
	if Level.map.getTileCoord(keeper.global_position) == Level.map.getTileCoord(usable.global_position):
		var actions := _axis(usable.global_position)
		if not actions.is_empty():
			_hold(actions)
			interaction_wait_steps = 0
			return
		_wait_for_interaction("The %s cave reward did not receive exact usable focus" % label)
		return
	if _move_to_cave(usable.global_position):
		interaction_wait_steps = 0
		return
	if cave_approach_coord == NO_COORD:
		_fail("The %s cave does not have a saved open interaction approach" % label)
		return
	if _move_open(Level.map.getTilePos(cave_approach_coord)):
		interaction_wait_steps = 0
		return
	_fail("No open path reaches the %s cave interaction approach" % label)

func _new_resource_cave_drop(drop_type: String) -> Drop:
	var spawned: Drop
	for candidate in Level.drops.get_all_drops().values():
		if (
			candidate is Drop
			and candidate.type == drop_type
			and not interaction_prior_drop_uids.has(candidate.UID)
			and not candidate.absorbed
			and not candidate.independent
		):
			if is_instance_valid(spawned):
				_fail("The resource cave activation produced multiple exact reward candidates")
				return null
			spawned = candidate
	return spawned

func _accept_pending_resource_cave_drop(drop: Drop) -> bool:
	if not _is_resource_cave_kind(_active_cave_kind()) or not cave_activation_pending:
		return false
	if (
		cave_harvest_targets.is_empty()
		or drop.type != cave_resource_type
		or interaction_prior_drop_uids.has(drop.UID)
	):
		return false
	var reward := cave_task.get_node_or_null(cave_harvest_targets.front()) as Node2D
	if not is_instance_valid(reward) or not bool(reward.get("taken")):
		_fail("The resource cave attached a reward without consuming the exact snapshotted node")
		return true
	interaction_resource = drop
	cave_harvest_targets.pop_front()
	interaction_prior_drop_uids.clear()
	cave_activation_pending = false
	interaction_wait_steps = 0
	_queue_record("The resource cave attached its exact physical reward")
	return true

func _run_cave_resource_delivery(required_type: String, owner_label: String, receiver: ResourceGrabber) -> void:
	if not is_instance_valid(receiver) or bool(receiver.spent):
		_wait_for_interaction("%s lost its unspent physical-resource receiver" % owner_label)
		return
	if ore != NO_COORD:
		_mine_exclusive_resource(required_type, owner_label)
		return
	if _select_interaction_resource(required_type):
		if keeper.carriedCarryables.has(interaction_resource):
			_deliver_cave_resource(owner_label, receiver)
		else:
			_fetch_interaction_resource(owner_label)
		return
	_explore()

func _select_interaction_resource(required_type: String) -> bool:
	if (
		is_instance_valid(interaction_resource)
		and interaction_resource.type == required_type
		and not interaction_resource.absorbed
		and not interaction_resource.independent
		and not _drop_targeted_by_transport(interaction_resource)
	):
		return true
	interaction_resource = null
	var best: Drop
	for candidate in _cached_resources():
		if candidate.type != required_type:
			continue
		if not is_finite(_path_distance(keeper.global_position, candidate.global_position)):
			continue
		if not is_instance_valid(best) or candidate.get_instance_id() < best.get_instance_id():
			best = candidate
	interaction_resource = best
	if is_instance_valid(interaction_resource):
		_record("interaction_resource_reserved", "Reserved physical %s for the active interaction" % required_type, null)
	return is_instance_valid(interaction_resource)

func _fetch_interaction_resource(owner_label: String, keep_load := false) -> void:
	if not keep_load and not keeper.carriedCarryables.is_empty():
		_drop_interaction_cargo()
		return
	if keeper.focussedCarryable == interaction_resource and _leaf() == "Keeper1InputProcessor":
		if pickup_failures >= 3:
			_fail("Repeated exact %s resource pickup attempts failed" % owner_label)
			return
		pickup_failures += 1
		_release_all()
		_tap(&"keeper1_pickup")
		delay = CARRY_PICKUP_SECONDS
		return
	if _move_open(interaction_resource.global_position):
		interaction_wait_steps = 0
		return
	_fail("No open path reaches the reserved %s resource" % owner_label)

func _deliver_cave_resource(owner_label: String, receiver: ResourceGrabber) -> void:
	if not keeper.carriedCarryables.has(interaction_resource):
		interaction_resource = null
		_wait_for_interaction("The reserved %s resource attached to an unexpected carrier" % owner_label)
		return
	var receiver_coord: Vector2i = Level.map.getTileCoord(receiver.global_position)
	if Level.map.getTileCoord(keeper.global_position) != receiver_coord:
		if _move_to_cave(receiver.global_position):
			interaction_wait_steps = 0
			return
		_wait_for_interaction("No open path reaches the %s resource receiver" % owner_label)
		return
	var actions := _axis(receiver.global_position)
	if not actions.is_empty():
		_hold(actions)
		interaction_wait_steps = 0
		return
	_wait_for_interaction("The %s receiver did not accept its exact physical resource" % owner_label)

func _drone_cave_has_owned_squidley() -> bool:
	var dispatcher = cave_task.get_node_or_null("DroneDispatcher")
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

func _exclusive_resource_search_type() -> String:
	if _power_core_status() == "SEARCH_WATER":
		return CONST.WATER
	if not is_instance_valid(cave_task):
		return ""
	match _active_cave_kind():
		CaveTaskKind.SCANNER:
			if not cave_task.canFocusUse(keeper):
				return CONST.IRON
		CaveTaskKind.DRONE:
			var receiver := cave_task.get_node_or_null("ResourceGrabber") as ResourceGrabber
			if is_instance_valid(receiver) and not bool(receiver.spent):
				return CONST.WATER
	return ""

func _finish_cave_task(reason: String, evidence = null) -> void:
	var label := str(CaveTaskKind.keys()[_active_cave_kind()]).to_lower()
	_record("cave_completed", reason, evidence)
	ModLoaderLog.info("Completed %s cave side task: %s" % [label, reason], LOG_NAME)
	_reset_cave_task()
	_change(State.EXPLORE, reason + "; resume the saved ordinary path")

func _wait_for_interaction(reason: String) -> void:
	_release_all()
	interaction_wait_steps += 1
	if interaction_wait_steps <= INTERACTION_WAIT_LIMIT:
		return
	_fail(reason)

func _reset_cave_task() -> void:
	cave_task = null
	interaction_resource = null
	scanner_receiver = null
	cave_activation_pending = false
	interaction_wait_steps = 0
	cave_approach_coord = NO_COORD
	cave_harvest_targets.clear()
	interaction_prior_drop_uids.clear()
	cave_resource_type = ""
	cave_observed_value = 0.0

func _abandon_interaction(reason: String) -> void:
	if ore != NO_COORD:
		_record_cache()
	elif is_instance_valid(cave_task):
		_reset_cave_task()
	elif is_instance_valid(artifact_chamber):
		_reset_artifact_retrieval()
	_record("interaction_abandoned", reason, null)

func _mine_gadget_chamber() -> void:
	if not is_instance_valid(artifact_chamber):
		_fail("The active gadget chamber disappeared")
		return

	match artifact_chamber.currentState:
		Chamber.State.REVEALED:
			_excavate_chamber(artifact_chamber, CONST.GADGET, "Gadget")
		Chamber.State.OPENING:
			_wait_for_interaction("Gadget chamber did not finish opening")
		Chamber.State.OPEN:
			_activate_artifact_chamber()
		Chamber.State.EMPTY:
			_wait_for_interaction("Activated gadget chamber did not attach its artifact")
		_:
			_fail("Gadget chamber returned to an unsupported state")

func _excavate_chamber(chamber: Chamber, tile_type: String, label: String) -> void:
	var plan := _chamber_cover_plan(chamber, tile_type)
	if plan.is_empty():
		_wait_for_interaction("No revealed %s cover has a reachable open approach" % label)
		return
	interaction_wait_steps = 0
	var approach: Vector2i = plan["approach_coord"]
	var target: Vector2i = plan["target"]
	if approach != NO_COORD and Level.map.getTileCoord(keeper.global_position) != approach:
		if not _move_open(Level.map.getTilePos(approach)):
			_fail("The revealed %s cover approach became unreachable" % label)
		return
	var actions := _axis(Level.map.getTilePos(target))
	if actions.is_empty():
		_wait_for_interaction("%s chamber did not reveal another cover tile" % label)
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

func _begin_detached_gadget_recovery(gadget: Drop) -> void:
	if gadget_recovery_coord != NO_COORD:
		_change(State.INTERACTION, "Resume clearance around the detached chamber gadget")
		return
	if gadget_recovery_attempts >= GADGET_RECOVERY_LIMIT:
		_fail("The chamber gadget detached more than three times before delivery")
		return
	gadget_recovery_attempts += 1
	gadget_recovery_coord = Level.map.getTileCoord(gadget.global_position)
	interaction_wait_steps = 0
	_change(
		State.INTERACTION,
		"The chamber gadget detached before delivery; clear its fixed neighboring tiles (%d/%d)"
		% [gadget_recovery_attempts, GADGET_RECOVERY_LIMIT]
	)

func _mine_gadget_recovery() -> void:
	var gadget := gadget_drop
	if not is_instance_valid(gadget) or gadget.absorbed or gadget.independent:
		gadget_recovery_coord = NO_COORD
		_change(State.RETURN, "The tracked gadget entered authoritative handoff during clearance")
		return
	if gadget.isCarried():
		_fail("The tracked chamber gadget attached to an unexpected carrier during clearance")
		return
	var plan := _artifact_recovery_clearance_plan(gadget_recovery_coord)
	if int(plan["remaining"]) == 0:
		interaction_wait_steps = 0
		_reattach_detached_gadget()
		return
	if not plan.has("target"):
		_wait_for_interaction("No open approach reaches the detached gadget clearance tiles")
		return
	interaction_wait_steps = 0
	var target: Vector2i = plan["target"]
	var target_tile = Level.map.getTile(target)
	if target_tile is Tile and ORE_TYPES.has(target_tile.type):
		_record_cache_site(Level.map.getTilePos(gadget_recovery_coord))
	var approach: Vector2i = plan["approach"]
	if Level.map.getTileCoord(keeper.global_position) != approach:
		if not _move_open(Level.map.getTilePos(approach)):
			_fail("The detached gadget clearance approach became unreachable")
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

func _reattach_detached_gadget() -> void:
	var gadget := gadget_drop
	if not is_instance_valid(gadget) or gadget.absorbed or gadget.independent:
		gadget_recovery_coord = NO_COORD
		_change(State.RETURN, "The tracked gadget entered authoritative handoff before reattachment")
		return
	if gadget.isCarried():
		_fail("The tracked chamber gadget attached to an unexpected carrier before reattachment")
		return
	if not keeper.carriedCarryables.is_empty():
		_fail("Cannot reacquire the chamber gadget with a non-exclusive load")
		return
	if keeper.focussedCarryable == gadget and _leaf() == "Keeper1InputProcessor":
		if pickup_failures >= 3:
			_fail("Repeated exact chamber gadget pickup attempts failed")
			return
		pickup_failures += 1
		_release_all()
		_tap(&"keeper1_pickup")
		delay = CARRY_PICKUP_SECONDS
		return
	if _move_open(gadget.global_position):
		interaction_wait_steps = 0
		return
	_wait_for_interaction("No open path reaches the detached chamber gadget")

func _activate_artifact_chamber() -> void:
	if not is_instance_valid(artifact_chamber) or artifact_chamber.currentState != Chamber.State.OPEN:
		_wait_for_interaction("Artifact chamber is not ready for acquisition")
		return
	if not keeper.carriedCarryables.is_empty():
		_drop_interaction_cargo()
		return
	var usable := artifact_chamber.get_node_or_null("Usable") as Node2D
	if not is_instance_valid(usable) or not artifact_chamber.canFocusUse(keeper):
		_wait_for_interaction("Open artifact chamber did not expose its usable target")
		return
	if keeper.focussedUsable == usable and _leaf() == "Keeper1InputProcessor":
		_release_all()
		_prepare_artifact_transport()
		_tap(&"ui_select")
		interaction_wait_steps = 0
		delay = 0.2
		return
	if Level.map.getTileCoord(keeper.global_position) == Level.map.getTileCoord(usable.global_position):
		var actions := _axis(usable.global_position)
		if not actions.is_empty():
			interaction_wait_steps = 0
			_hold(actions)
			return
		_wait_for_interaction("The open artifact chamber did not receive exact usable focus")
		return
	if _move_open(usable.global_position):
		interaction_wait_steps = 0
	else:
		_fail("No open path reaches the artifact chamber usable")

func _prepare_artifact_transport() -> void:
	_reset_artifact_transport()
	for candidate in Level.drops.get_all_drops().values():
		if candidate is Drop and candidate.type == artifact_chamber.drop_type:
			interaction_prior_drop_uids[candidate.UID] = true

func _drop_interaction_cargo() -> void:
	if _leaf() != "Keeper1InputProcessor":
		_fail("Cannot unload cargo without keeper input control")
		return
	if keeper.carriedCarryables.any(func(item): return item is Drop and item.type == CONST.POWERCORE):
		_fail("Cannot unload cargo without dropping an in-flight Power Core")
		return
	if keeper.carriedCarryables.any(func(item): return item is Drop and item.type == CONST.GADGET):
		_fail("Cannot unload mixed cargo without dropping the chamber gadget")
		return
	if keeper.carriedCarryables.any(func(item): return item is Drop and item.carryableType == "resource"):
		_record_cache_site(keeper.global_position)
	_release_all()
	_tap(&"keeper1_drop")
	delay = 0.2

func _carried_artifact() -> Drop:
	if not is_instance_valid(artifact_chamber):
		return null
	for carried in keeper.carriedCarryables:
		if not carried is Drop or carried.type != artifact_chamber.drop_type or carried.carryableType != "gadget":
			continue
		if is_instance_valid(gadget_drop) and carried != gadget_drop:
			continue
		if interaction_prior_drop_uids.has(carried.UID):
			continue
		return carried
	return null

func _reset_artifact_retrieval() -> void:
	artifact_chamber = null
	interaction_resource = null
	_reset_artifact_transport()

func _reset_artifact_transport() -> void:
	gadget_drop = null
	interaction_prior_drop_uids.clear()
	interaction_wait_steps = 0
	gadget_recovery_coord = NO_COORD
	gadget_recovery_attempts = 0

func _consume_upgrade_step(reason: String) -> bool:
	ui_steps += 1
	if ui_steps <= 30:
		return true
	_release_all()
	if _leaf() == "UpgradesInputProcessor":
		_tap(&"ui_cancel")
	_fail(reason)
	return false

func _defend() -> void:
	var leaf := _leaf()
	var wave_settled := not _wave("wavepresent") and not _wave("wavebattle")
	if (
		wave_settled
		and not is_instance_valid(gadget_drop)
		and (ore != NO_COORD or is_instance_valid(artifact_chamber) or is_instance_valid(cave_task))
	):
		_abandon_interaction("The settled wave invalidated the previous local interaction scan")
	if not keeper.isInsideStation:
		_change(State.RETURN, "The keeper left the battle station")
		return
	if _wave_needed() and leaf != "BattleInputProcessor":
		_release_all()
		if leaf == "StationInputProcessor":
			_tap(&"dome_battle"); delay = 0.5
		return
	if _wave("wavepresent") and leaf == "BattleInputProcessor":
		return
	_release_all()
	if _wave("wavebattle"):
		return
	if leaf == "BattleInputProcessor":
		_tap(&"ui_cancel"); delay = 0.5
	elif leaf == "StationInputProcessor":
		_change(State.RETURN, "The monster wave has settled; resume station task selection")
	elif leaf == "Keeper1InputProcessor":
		_change(State.EXPLORE, "The monster wave has settled")

func _recover() -> void:
	if _wave("wavepresent"):
		if (
			interrupted == State.EXPLORE
			and nav_travel_coord == NO_COORD
			and (explore_mode == ExploreMode.DESCEND or explore_mode == ExploreMode.BRANCH)
		):
			nav_travel_coord = Level.map.getTileCoord(keeper.global_position)
			explore_resume_mode = explore_mode
		_change(State.RETURN, "The monster wave interrupted stuck recovery")
		return
	var action := DIRECTIONS[probe_index]
	if _directed_distance(action, probe_origin) >= GameWorld.TILE_SIZE:
		_change(interrupted, "A recovery probe moved the keeper one tile")
		return
	probe_time += TICK
	if probe_time >= STALL_SECONDS:
		probe_count += 1
		if probe_count >= DIRECTIONS.size():
			_fail("All four recovery probes failed")
			return
		probe_index = (probe_index + 1) % DIRECTIONS.size()
		probe_time = 0.0; probe_origin = keeper.global_position
		action = DIRECTIONS[probe_index]
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
			if not Level.map.isRevealed(coord):
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
	ore = best
	ore_approach_coord = NO_COORD if float(best_route.astar_seconds) > float(best_route.direct_seconds) else Vector2i(best_route.approach_coord)
	vein = [ore]
	_record_interaction_decision("mine", subtype, best, best_distance, best_route)
	_change(State.INTERACTION, reason)
	return true

func _mine_exclusive_resource(required_type: String, owner_label: String) -> void:
	var tile = Level.map.getTile(ore)
	if not tile is Tile:
		var site: Vector2 = Level.map.getTilePos(vein.front()) if not vein.is_empty() else keeper.global_position
		_record_cache_site(site)
		vein.clear()
		ore = NO_COORD
		ore_approach_coord = NO_COORD
		ModLoaderLog.info("Mined %s for %s" % [required_type, owner_label], LOG_NAME)
		return
	if tile.type != required_type:
		_fail("Exclusive %s search targeted a %s tile" % [required_type, tile.type])
		return
	var current_coord: Vector2i = Level.map.getTileCoord(keeper.global_position)
	if ore_approach_coord != NO_COORD and absi(current_coord.x - ore.x) + absi(current_coord.y - ore.y) > 1:
		if _move_open(Level.map.getTilePos(ore_approach_coord)):
			return
		ore_approach_coord = NO_COORD
	_hold(_axis(Level.map.getTilePos(ore)))

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
		if not Level.map.visibleTileCoords.has(candidate):
			continue
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

func _adjacent_ore() -> Vector2i:
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

func _record_cache() -> void:
	if vein.is_empty():
		ore = NO_COORD
		ore_approach_coord = NO_COORD
		return
	var site: Vector2 = Level.map.getTilePos(vein.front())
	_record_cache_site(site)
	vein.clear()
	ore = NO_COORD
	ore_approach_coord = NO_COORD

func _record_cache_site(site: Vector2) -> void:
	if caches.all(func(existing): return existing.distance_to(site) > GameWorld.TILE_SIZE):
		caches.append(site)
	_invalidate_carry_preview()
	_maybe_request_cache_cleanup()

func _cached_resources() -> Array[Drop]:
	var result: Array[Drop] = []
	for candidate in Level.drops.get_all_drops().values():
		if not candidate is Drop:
			continue
		if candidate.carryableType != "resource" or candidate.absorbed or candidate.independent or candidate.isCarried():
			continue
		if _drop_targeted_by_transport(candidate):
			continue
		if ignored_cache_drops.has(candidate):
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

func _transport_pipeline_resources() -> Dictionary:
	var resources := {}
	for drone in get_tree().get_nodes_in_group(keeper.teamId + "-transport_drones"):
		if not _is_cave_squidley(drone):
			continue
		var carried_resource := str(drone.get("carriedResource"))
		if not carried_resource.is_empty():
			resources[carried_resource] = int(resources.get(carried_resource, 0)) + 1
	return resources

func _reachable_cached_resource_count() -> int:
	var reachable := 0
	for drop in _cached_resources():
		if not is_finite(_path_distance(keeper.global_position, drop.global_position)):
			continue
		if not is_finite(_path_distance(drop.global_position, _home_position())):
			continue
		reachable += 1
	return reachable

func _maybe_request_cache_cleanup() -> void:
	if state != State.INTERACTION or cache_cleanup_mode != CacheCleanupMode.NONE:
		return
	var full_load := _full_load_count(_carry_loss())
	var threshold := full_load * CACHE_CLEANUP_LOAD_MULTIPLIER
	var reachable := _reachable_cached_resource_count()
	if reachable < threshold:
		return
	var reason := "Known reachable cache backlog reached %d resources; cleanup threshold: %d"
	_change_cache_cleanup(CacheCleanupMode.PENDING_DEFENSE, reason % [reachable, threshold])

func _ignore_failed_cleanup_drop() -> void:
	if cache_cleanup_mode != CacheCleanupMode.ACTIVE or not is_instance_valid(carry):
		return
	ignored_cache_drops[carry] = true
	ModLoaderLog.info("A repeatedly failing resource was excluded from the active cache cleanup", LOG_NAME)

func _begin_carry(reason: String, preview := {}) -> bool:
	var preliminary: Dictionary = preview if not preview.is_empty() else _build_carry_plan(INF)
	var pickup_count := int(preliminary.get("pickup_count", 0))
	if pickup_count <= 0:
		return false
	carry_plan = preliminary
	carry = null
	if not _update_mobility_from_plan():
		carry_plan.clear()
		return false
	carry_plan = _build_carry_plan(_wave_time())
	pickup_count = int(carry_plan.get("pickup_count", 0))
	if pickup_count <= 0:
		carry_plan.clear()
		return false
	_change(State.CARRY, reason + "; planned pickups: " + str(pickup_count))
	return true

func _carry_window_plan() -> Dictionary:
	var wave_time := _wave_time()
	if not is_finite(wave_time):
		return {}
	if GameWorld.runTime >= carry_preview_refresh_at:
		carry_preview_cache = _build_carry_plan(INF)
		carry_preview_refresh_at = GameWorld.runTime + CARRY_PREVIEW_INTERVAL
	var preview: Dictionary = carry_preview_cache
	if int(preview.get("pickup_count", 0)) <= 0:
		return {}
	var planned_seconds := float(preview.get("collection_seconds", INF))
	planned_seconds += float(preview.get("return_seconds", INF))
	if wave_time > planned_seconds + STATION_ENTRY_SECONDS + TICK:
		return {}
	return preview

func _must_return_now() -> bool:
	var wave_time := _wave_time()
	if not is_finite(wave_time):
		return false
	var distance := _path_distance(keeper.global_position, _home_position())
	if not is_finite(distance):
		return true
	var current_load := keeper.carriedCarryables.size()
	var return_seconds := _return_seconds(distance, current_load, _planning_base_speed(), _carry_loss())
	return wave_time <= return_seconds + STATION_ENTRY_SECONDS

func _build_carry_plan(wave_time: float) -> Dictionary:
	var remaining := _cached_resources()
	var counts := {}
	var pickup_count := 0
	var collection_seconds := 0.0
	var return_distance := INF
	var return_seconds := INF
	var position := keeper.global_position
	var load := keeper.carriedCarryables.size()
	var base_speed := _planning_base_speed()
	var loss := _carry_loss()
	var inward_distances := {}
	while not remaining.is_empty() and _speed_ratio_for_count(load + 1, loss) >= MIN_SPEED_RATIO:
		var deficits := _reserved_resource_deficits(counts)
		var best: Drop
		var best_needed := false
		var best_outward_seconds := INF
		var best_return_distance := INF
		for drop in remaining:
			if not is_instance_valid(drop) or drop.absorbed or drop.independent or drop.isCarried():
				continue
			var outward_distance := _path_distance(position, drop.global_position)
			var instance_id: int = drop.get_instance_id()
			var inward_distance := float(inward_distances.get(instance_id, -1.0))
			if inward_distance < 0.0:
				inward_distance = _path_distance(drop.global_position, _home_position())
				inward_distances[instance_id] = inward_distance
			if not is_finite(outward_distance) or not is_finite(inward_distance):
				continue
			var outward_seconds := _return_seconds(outward_distance, load, base_speed, loss)
			var inward_seconds := _return_seconds(inward_distance, load + 1, base_speed, loss)
			var planned_total := collection_seconds + outward_seconds + CARRY_PICKUP_SECONDS + inward_seconds
			if is_finite(wave_time) and planned_total + STATION_ENTRY_SECONDS >= wave_time:
				continue
			var needed := int(deficits.get(drop.type, 0)) > 0
			if not _carry_candidate_is_better(drop, needed, outward_seconds, best, best_needed, best_outward_seconds):
				continue
			best = drop
			best_needed = needed
			best_outward_seconds = outward_seconds
			best_return_distance = inward_distance
		if not is_instance_valid(best):
			break
		remaining.erase(best)
		counts[best.type] = int(counts.get(best.type, 0)) + 1
		pickup_count += 1
		collection_seconds += best_outward_seconds + CARRY_PICKUP_SECONDS
		return_distance = best_return_distance
		load += 1
		return_seconds = _return_seconds(return_distance, load, base_speed, loss)
		position = best.global_position
	return {
		"counts": counts,
		"pickup_count": pickup_count,
		"final_load": load,
		"collection_seconds": collection_seconds,
		"return_distance": return_distance,
		"return_seconds": return_seconds,
	}

func _carry_candidate_is_better(
	drop: Drop,
	needed: bool,
	outward_seconds: float,
	best: Drop,
	best_needed: bool,
	best_outward_seconds: float,
) -> bool:
	if not is_instance_valid(best):
		return true
	if needed != best_needed:
		return needed
	if not is_equal_approx(outward_seconds, best_outward_seconds):
		return outward_seconds < best_outward_seconds
	if str(drop.type) != str(best.type):
		return str(drop.type) < str(best.type)
	if not is_equal_approx(drop.global_position.y, best.global_position.y):
		return drop.global_position.y < best.global_position.y
	if not is_equal_approx(drop.global_position.x, best.global_position.x):
		return drop.global_position.x < best.global_position.x
	return drop.get_instance_id() < best.get_instance_id()

func _invalidate_carry_preview() -> void:
	carry_preview_cache.clear()
	carry_preview_refresh_at = 0.0

func _choose_planned_carry() -> bool:
	var counts: Dictionary = carry_plan.get("counts", {})
	var deficits := _reserved_resource_deficits()
	var best: Drop
	var best_needed := false
	var best_distance := INF
	for candidate in _cached_resources():
		if int(counts.get(candidate.type, 0)) <= 0:
			continue
		var distance := _path_distance(keeper.global_position, candidate.global_position)
		if not is_finite(distance):
			continue
		var needed := int(deficits.get(candidate.type, 0)) > 0
		if not _carry_candidate_is_better(candidate, needed, distance, best, best_needed, best_distance):
			continue
		best = candidate
		best_needed = needed
		best_distance = distance
	if not is_instance_valid(best):
		return false
	carry = best
	return true

func _planned_pickup_is_safe(drop: Drop) -> bool:
	var next_load := keeper.carriedCarryables.size() + 1
	var loss := _carry_loss()
	if _speed_ratio_for_count(next_load, loss) < MIN_SPEED_RATIO:
		return false
	var outward_distance := _path_distance(keeper.global_position, drop.global_position)
	var inward_distance := _path_distance(drop.global_position, _home_position())
	if not is_finite(outward_distance) or not is_finite(inward_distance):
		return false
	var base_speed := _planning_base_speed()
	var seconds := _return_seconds(outward_distance, next_load - 1, base_speed, loss)
	seconds += CARRY_PICKUP_SECONDS + _return_seconds(inward_distance, next_load, base_speed, loss)
	return not is_finite(_wave_time()) or seconds + STATION_ENTRY_SECONDS < _wave_time()

func _reserved_resource_deficits(extra_resources := {}) -> Dictionary:
	var available := _stored_upgrade_resources()
	for drop in keeper.carriedCarryables:
		if drop is Drop and available.has(drop.type):
			available[drop.type] += 1
	var pipeline_resources := _transport_pipeline_resources()
	for resource in pipeline_resources:
		available[resource] = int(available.get(resource, 0)) + int(pipeline_resources[resource])
	for resource in extra_resources:
		available[resource] = int(available.get(resource, 0)) + int(extra_resources[resource])
	var excluded_intents := {}
	var seen := {}
	for _index in pending_intents.size():
		var target := _select_upgrade_target(available, false, excluded_intents, seen)
		var id: String = target.get("id", "")
		if id.is_empty():
			return {}
		excluded_intents[int(target["intent"])] = true
		seen[id] = true
		var cost: Dictionary = GameWorld.upgrades[id].get("cost", {})
		var deficits := _resource_deficits(cost, available)
		if not deficits.is_empty():
			return deficits
		for resource in cost:
			available[resource] = int(available.get(resource, 0)) - int(cost[resource])
	return {}

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

func _return_seconds(distance: float, count: int, base_speed: float, loss: float) -> float:
	var speed := _effective_speed(count, base_speed, loss)
	if not is_finite(speed) or speed <= 0.0:
		return INF
	return distance / speed

func _full_load_count(loss: float) -> int:
	var count := 0
	while count < 128 and _speed_ratio_for_count(count + 1, loss) >= MIN_SPEED_RATIO:
		count += 1
	return count

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

func _update_mobility_from_plan() -> bool:
	var distance := float(carry_plan.get("return_distance", INF))
	var planned_load := int(carry_plan.get("final_load", 0))
	if not is_finite(distance) or planned_load <= 0:
		return true
	var base_speed := _planning_base_speed()
	var loss := _carry_loss()
	var full_load := _full_load_count(loss)
	if full_load <= 0:
		_fail("The configured carry slowdown never permits one resource")
		return false
	var safe_load := 0
	for count in range(1, full_load + 1):
		if _return_seconds(distance, count, base_speed, loss) <= MOBILITY_RETURN_TARGET_SECONDS:
			safe_load = count
	var capacity_ratio := float(safe_load) / float(full_load)
	if capacity_ratio >= MOBILITY_CAPACITY_RATIO_THRESHOLD:
		return true

	var speed_target := _resolve_chain(SPEED_UPGRADES)
	var strength_target := _resolve_chain(CARRY_UPGRADES)
	var speed_id: String = speed_target.get("id", "")
	var strength_id: String = strength_target.get("id", "")
	if speed_id.is_empty() and strength_id.is_empty():
		return true
	var current_seconds := _return_seconds(distance, planned_load, base_speed, loss)
	var speed_gain := -INF
	if not speed_id.is_empty():
		var current_max_speed := float(Data.of(keeper.playerId + ".keeper1.maxSpeed"))
		var upgraded_max_speed = _upgrade_property_value(speed_id, "maxspeed", current_max_speed)
		if upgraded_max_speed == null:
			_fail("Supported speed upgrade has no maxSpeed property change: " + speed_id)
			return false
		var speed_buff := float(Data.ofOr(keeper.playerId + ".keeper.speedBuff", 0.0))
		speed_gain = current_seconds - _return_seconds(distance, planned_load, float(upgraded_max_speed) + speed_buff, loss)
	var strength_gain := -INF
	if not strength_id.is_empty():
		var upgraded_loss = _upgrade_property_value(strength_id, "speedlosspercarry", loss)
		if upgraded_loss == null:
			_fail("Supported carry upgrade has no speedLossPerCarry property change: " + strength_id)
			return false
		strength_gain = current_seconds - _return_seconds(distance, planned_load, base_speed, float(upgraded_loss))

	var previous_arm := mobility_arm
	mobility_arm = MobilityArm.STRENGTH if strength_gain > speed_gain + 0.0001 else MobilityArm.SPEED
	var was_pending := pending_intents.has(UpgradeIntent.MOBILITY)
	pending_intents[UpgradeIntent.MOBILITY] = true
	if not was_pending or previous_arm != mobility_arm:
		var arm_name := "strength" if mobility_arm == MobilityArm.STRENGTH else "speed"
		var reason := "Mobility upgrade requested from carry plan: %s; safe load %d/%d; gains %.2fs/%.2fs"
		_queue_record(reason % [arm_name, safe_load, full_load, speed_gain, strength_gain])
	return true

func _upgrade_property_value(id: String, property_name: String, current_value: float):
	if not GameWorld.upgrades.has(id):
		return null
	var changed_value := current_value
	var found := false
	for change in GameWorld.upgrades[id].get("propertychanges", []):
		var key_name := str(change.keyName).to_lower()
		var key := str(change.key).to_lower()
		if key_name != property_name and not key.ends_with("." + property_name):
			continue
		changed_value = float(change.getChangedValue(changed_value))
		found = true
	return changed_value if found else null

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
	for intent_class in INTENT_CLASSES:
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

func _freeze_upgrade_target() -> bool:
	if not active_upgrade_id.is_empty():
		return true
	var target := _next_upgrade_target()
	active_upgrade_id = target.get("id", "")
	if active_upgrade_id.is_empty():
		return false
	active_upgrade_intent = int(target["intent"])
	active_upgrade_arm = int(target.get("arm", -1))
	active_upgrade_fulfills = bool(target.get("fulfills", true))
	if active_upgrade_intent == UpgradeIntent.REPAIR and repair_target_health <= 0.0:
		repair_target_health = minf(
			_dome_max_health(),
			maxf(
				_dome_max_health() * REPAIR_HEALTH_RESERVE_RATIO,
				last_wave_health_loss
			)
		)
		ModLoaderLog.info(
			"UPGRADE repair target %.1f after %.1f net wave loss" % [repair_target_health, last_wave_health_loss],
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

func _active_upgrade_ready() -> bool:
	if active_upgrade_intent == UpgradeIntent.REPAIR and _dome_health() >= repair_target_health:
		return false
	return not active_upgrade_id.is_empty() and _upgrade_ready(active_upgrade_id)

func _clear_active_upgrade() -> void:
	active_upgrade_intent = -1
	active_upgrade_id = ""
	active_upgrade_arm = -1
	active_upgrade_fulfills = false

func _on_upgrade_bought(id: String, team_id: String, player_id: String) -> void:
	if not running or team_id != keeper.teamId or player_id != keeper.playerId:
		return
	if id != active_upgrade_id:
		return
	_invalidate_carry_preview()
	if active_upgrade_fulfills:
		pending_intents.erase(active_upgrade_intent)
		if active_upgrade_intent == UpgradeIntent.COMBAT:
			combat_attack_next = active_upgrade_arm != 0
		elif active_upgrade_intent == UpgradeIntent.DRILL:
			drill_hits_by_coord.clear()
	_clear_active_upgrade()
	_sync_repair_intent()
	ui_steps = 0
	closing_upgrade = not _freeze_upgrade_target() or not _active_upgrade_ready()
	_queue_record("Upgrade purchased: " + id)

func _on_upgrade_error(id: String, team_id: String, player_id: String) -> void:
	if not running or id != active_upgrade_id or team_id != keeper.teamId or player_id != keeper.playerId:
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
	if (
		cave_approach_coord != NO_COORD
		and Level.map.getTileCoord(keeper.global_position) != cave_approach_coord
	):
		return _move_open(Level.map.getTilePos(cave_approach_coord))
	var actions := _axis(target)
	if actions.is_empty():
		return false
	_hold(actions)
	return true

func _change(next: State, reason: String) -> void:
	_release_all()
	var previous := state
	if previous == State.DEFEND and next != State.DEFEND:
		_clear_laser_aim("Laser aiming became inactive")
	if (
		previous == State.EXPLORE
		and next != State.EXPLORE
		and next != State.RECOVER
		and mining_outcome == MiningOutcome.ACTIVE
		and nav_travel_coord == NO_COORD
	):
		if explore_mode == ExploreMode.DESCEND or explore_mode == ExploreMode.BRANCH:
			nav_travel_coord = Level.map.getTileCoord(keeper.global_position)
			explore_resume_mode = explore_mode
	if previous == State.CARRY and next != State.RECOVER:
		carry = null
		carry_plan.clear()
	if previous == State.UPGRADE and next != State.UPGRADE:
		repair_target_health = 0.0
		_sync_repair_intent()
	state = next; delay = 0.2; pickup_failures = 0
	_reset_progress()
	if state == State.RETURN:
		if nav_travel_coord == NO_COORD and mining_outcome == MiningOutcome.ACTIVE:
			explore_mode = ExploreMode.DESCEND
			nav_travel_coord = Level.map.getTileCoord(_home_position())
			explore_resume_mode = ExploreMode.DESCEND
		bypass_side = 1; bypass_reversed = false
	elif state == State.UPGRADE:
		closing_upgrade = false; ui_steps = 0
	if next == previous:
		return
	var previous_name := str(State.keys()[previous])
	var current_name := str(State.keys()[next])
	ModLoaderLog.info(previous_name + " -> " + current_name + ": " + reason, LOG_NAME)
	_record("teacher_state", reason, {"from": previous_name, "to": current_name})

func _change_exploration(next: ExploreMode, reason: String) -> void:
	if next == explore_mode:
		return
	var previous := explore_mode
	explore_mode = next
	var previous_name := str(ExploreMode.keys()[previous])
	var current_name := str(ExploreMode.keys()[next])
	ModLoaderLog.info("EXPLORE " + previous_name + " -> " + current_name + ": " + reason, LOG_NAME)
	_record("exploration_state", reason, {"from": previous_name, "to": current_name})

func _change_cache_cleanup(next: CacheCleanupMode, reason: String) -> void:
	if next == cache_cleanup_mode:
		return
	var previous := cache_cleanup_mode
	cache_cleanup_mode = next
	if next == CacheCleanupMode.NONE:
		ignored_cache_drops.clear()
	var previous_name := str(CacheCleanupMode.keys()[previous])
	var current_name := str(CacheCleanupMode.keys()[next])
	ModLoaderLog.info("CACHE_CLEANUP " + previous_name + " -> " + current_name + ": " + reason, LOG_NAME)

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
	interrupted = state; probe_index = (DIRECTIONS.find(action) + 1) % DIRECTIONS.size()
	probe_count = 0; probe_time = 0.0
	probe_origin = keeper.global_position
	_change(State.RECOVER, "No directed movement or drill progress for four seconds")

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
	if state == State.RECOVER:
		probe_time = 0.0
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

func _wave_needed() -> bool:
	return _wave("wavebattle") or _wave_time() <= STATION_ENTRY_SECONDS

func _on_drop_picked_up(drop, carrier) -> void:
	if carrier == keeper:
		pickup_failures = 0
		_invalidate_carry_preview()
		if (
			drop is Drop
			and is_instance_valid(artifact_chamber)
			and drop.type == artifact_chamber.drop_type
			and drop.carryableType == "gadget"
		):
			if not interaction_prior_drop_uids.has(drop.UID):
				gadget_drop = drop
				_queue_record("Keeper picked up the exact activated artifact")
			return
		if drop is Drop and _accept_pending_resource_cave_drop(drop):
			return
		if drop == interaction_resource:
			interaction_wait_steps = 0
			_queue_record("Keeper picked up the reserved interaction resource")
			return
		if state == State.CARRY and drop is Drop:
			var counts: Dictionary = carry_plan.get("counts", {})
			if int(counts.get(drop.type, 0)) > 0:
				counts[drop.type] = int(counts[drop.type]) - 1
				carry_plan["counts"] = counts
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
		if cache_cleanup_mode == CacheCleanupMode.PENDING_DEFENSE:
			_change_cache_cleanup(CacheCleanupMode.ACTIVE, "The next monster wave settled after cache cleanup was requested")
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
	var target_health := repair_target_health
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
	if not keeper.isInsideStation and state != State.UPGRADE and state != State.DEFEND and leaf != "Keeper1InputProcessor":
		return true
	if GameWorld.paused and leaf != "StationInputProcessor" and leaf != "UpgradesInputProcessor":
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

func _adopt_descent_frontier(coord: Vector2i, target_row: int, reason: String) -> void:
	attempted_descent_origins[coord] = true
	mining_outcome = MiningOutcome.ACTIVE
	mining_outcome_reason = ""
	branch_row = target_row
	branch_side = 1
	branch_entry_coord = NO_COORD
	active_corridor_cells.clear()
	bypass_side = 1
	bypass_reversed = false
	nav_travel_coord = coord
	explore_resume_mode = ExploreMode.DESCEND
	_release_all()
	_change_exploration(ExploreMode.DESCEND, reason)
	_reset_progress()
	delay = 0.2

func _record_completed_corridor(row: int) -> void:
	var cells: Dictionary = active_corridor_cells.duplicate()
	active_corridor_cells.clear()
	for index in range(completed_corridors.size()):
		var corridor: Dictionary = completed_corridors[index]
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
		completed_corridors.remove_at(index)
		completed_corridors.append({"row": row, "cells": known_cells})
		return
	completed_corridors.append({"row": row, "cells": cells})

func _find_backtrack_frontier() -> Dictionary:
	var saw_unreachable := false
	var saw_unsupported := false
	var saw_wave_unsafe := false
	for corridor_index in range(completed_corridors.size() - 1, -1, -1):
		var corridor: Dictionary = completed_corridors[corridor_index]
		var cells: Dictionary = corridor.get("cells", {})
		var best_coord := NO_COORD
		var best_distance := INF
		for raw_coord in cells:
			var coord := Vector2i(raw_coord)
			if attempted_descent_origins.has(coord):
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
			if outward_distance > best_distance:
				continue
			if is_equal_approx(outward_distance, best_distance) and best_coord != NO_COORD and coord.x < best_coord.x:
				continue
			best_coord = coord
			best_distance = outward_distance
		if best_coord != NO_COORD:
			return {
				"status": FrontierSearch.READY,
				"coord": best_coord,
				"row": int(corridor.get("row", best_coord.y)),
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

func _finish_terminal_descent(reason: String) -> void:
	mining_outcome = MiningOutcome.BACKTRACK_PENDING
	mining_outcome_reason = reason
	nav_travel_coord = NO_COORD
	explore_resume_mode = -1
	branch_entry_coord = NO_COORD
	active_corridor_cells.clear()
	if not _exclusive_resource_search_type().is_empty():
		_release_all()
		return
	_change_cache_cleanup(CacheCleanupMode.ACTIVE, reason + "; activate persistent cache cleanup")
	var cleanup_preview := _build_carry_plan(INF)
	if int(cleanup_preview.get("pickup_count", 0)) > 0 and _begin_carry(reason + "; begin cache cleanup", cleanup_preview):
		return
	if not running:
		return
	_change(State.RETURN, reason + "; return and keep cleanup active")

func _fail(reason: String) -> void:
	ModLoaderLog.error(reason + " state=" + str(State.keys()[state]), LOG_NAME)
	_record("teacher_failed", reason, null)
	failed.emit(reason)
