extends Node

signal failed(reason: String)

const GADGET_CATALOG = preload("res://mods-unpacked/LemonNekoGH-YoloDataCollector/gadget_catalog.gd")

enum State { NAVIGATE, MINE, CARRY, RETURN, UPGRADE, DEFEND, RECOVER }
enum NavMode { ALIGN, DESCEND, BRANCH, BYPASS }
enum CacheCleanupMode { NONE, PENDING_DEFENSE, ACTIVE }
enum UpgradeIntent { COMBAT, REPAIR, DRILL, MOBILITY }
enum MobilityArm { SPEED, STRENGTH }

const LOG_NAME := "YoloDataCollector:Teacher"
const STATUS_FILE := "airi-dome-keeper-status.json"
const RECORDING_ARG := "--airi-recording-dir="
const RECORDING_FPS_ARG := "--airi-recording-fps="
const RECORDING_MOVIE := "recording.avi"
const TICK := 0.1
const MOBILITY_RETURN_TARGET_SECONDS := 15.0
const STATION_ENTRY_SECONDS := 2.0
const CARRY_PICKUP_SECONDS := 0.35
const CARRY_PREVIEW_INTERVAL := 1.0
const GADGET_UI_STEP_LIMIT := 40
const GADGET_TASK_WAIT_LIMIT := 100
const MOBILITY_CAPACITY_RATIO_THRESHOLD := 0.75
const CACHE_CLEANUP_LOAD_MULTIPLIER := 2
const MIN_SPEED_RATIO := 0.55
const STALL_SECONDS := 4.0
const REVEAL_TILES := 1
const BRANCH_ROW_STEP := 1 + REVEAL_TILES * 2
const DRILL_HIT_INTENT_THRESHOLD := 5
const WAVE_NET_HEALTH_LOSS_RATIO_THRESHOLD := 0.15
const REPAIR_HEALTH_RATIO_THRESHOLD := 0.2
const NO_COORD := Vector2i(1 << 30, 1 << 30)
const ORE_TYPES: Array[String] = [CONST.IRON, CONST.SAND, CONST.WATER]
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
var recording := {}
var record_pending := false
var record_reason := ""
var previous_pause_when_out_of_focus := true
var previous_use_mouse_dome_gameplay := false
var state := State.NAVIGATE
var nav_mode := NavMode.ALIGN
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
var drill_hits_by_tile := {}
var wave_start_health := 0.0
var wave_start_max_health := 0.0
var wave_health_tracking := false
var observed_properties: Array[String] = []
var caches: Array[Vector2] = []
var vein: Array[Vector2i] = []
var ore := NO_COORD
var ore_approach_coord := NO_COORD
var branch_resume_coord := NO_COORD
var cache_cleanup_mode := CacheCleanupMode.NONE
var ignored_cache_drop_ids := {}
var carry: Drop
var carry_plan := {}
var carry_preview_cache := {}
var carry_preview_refresh_at := 0.0
var carry_preview_extra_site = null
var gadget_chamber: Chamber
var gadget_activation_pending := false
var gadget_delivery_pending := false
var gadget_drop_instance_id := 0
var gadget_prior_drop_ids := {}
var gadget_task_wait_steps := 0
var branch_row := -1000000
var branch_side := 1
var align_x := 0.0
var branch_entry_x := 0.0
var bypass_side := 1
var bypass_reversed := false
var shaft_exhausted := false
var tick_time := 0.0
var delay := 0.0
var pickup_failures := 0
var ui_steps := 0
var closing_upgrade := false
var gadget_offer_id := StringName()
var gadget_ui_steps := 0
var gadget_ui_delay := 0.0
var gadget_confirming := false
var progress_action := StringName()
var progress_origin := Vector2.ZERO
var stalled := 0.0
var interrupted := State.NAVIGATE
var probe_index := 0
var probe_count := 0
var probe_time := 0.0
var probe_origin := Vector2.ZERO

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	status_path = _temp_dir().path_join(STATUS_FILE)
	_configure_recording()
	_write_status()

func start() -> bool:
	if running:
		return true

	var error := _preflight()
	if error.is_empty():
		error = _load_bindings()
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
	drill_hits_by_tile.clear(); carry_plan.clear(); carry_preview_cache.clear()
	ore_approach_coord = NO_COORD; branch_resume_coord = NO_COORD
	cache_cleanup_mode = CacheCleanupMode.NONE; ignored_cache_drop_ids.clear()
	_reset_gadget_choice()
	_reset_gadget_retrieval()
	carry_preview_refresh_at = 0.0
	carry_preview_extra_site = null
	wave_health_tracking = _wave("wavepresent") or _wave("wavebattle")
	wave_start_health = _dome_health(); wave_start_max_health = _dome_max_health()
	_sync_repair_intent()
	observed_properties.assign([
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
	])
	for property in observed_properties:
		Data.listen(self, property)
	running = true; state = State.NAVIGATE; nav_mode = NavMode.ALIGN
	branch_row = -1000000; branch_side = 1
	align_x = dome.global_position.x; branch_entry_x = align_x
	shaft_exhausted = false
	caches.clear()
	_reset_progress()
	keeper.mined.connect(_on_mined)
	Level.drops.synchronizer.drop_picked_up.connect(_on_drop_picked_up)
	Level.monstersByTeamId[keeper.teamId].monsterSynchronizer.spawned.connect(_on_monster_spawned)
	GameWorld.upgradeBought.connect(_on_upgrade_bought)
	GameWorld.upgradeError.connect(_on_upgrade_error)
	ModLoaderLog.info("Started rule teacher", LOG_NAME)
	if not recording_path.is_empty():
		record_pending = false
		recording = {"fixed_fps": recording_fps, "events": []}
		_record("session_started", "Teacher collection started", null)
	return true

func stop() -> void:
	if not running:
		return
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
	running = false; keeper = null; carry = null; carry_plan.clear(); carry_preview_cache.clear()
	cache_cleanup_mode = CacheCleanupMode.NONE; ignored_cache_drop_ids.clear()
	_reset_gadget_choice()
	_reset_gadget_retrieval()
	carry_preview_extra_site = null
	Options.pauseWhenOutOfFocus = previous_pause_when_out_of_focus
	Options.useMouseDomeGameplay = previous_use_mouse_dome_gameplay
	InputSystem.game_not_in_focus = not DisplayServer.window_is_focused()
	recording.clear()

func _process(delta: float) -> void:
	status_elapsed += delta
	if status_elapsed >= 1.0:
		status_elapsed = 0.0
		_write_status()
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
	if _handle_gadget_choice(delta):
		_release_all(); _reset_progress()
		return
	if not running:
		return
	var carried_gadget := _carried_gadget()
	if is_instance_valid(carried_gadget):
		if keeper.carriedCarryables.size() != 1:
			_fail("A chamber gadget attached to a non-exclusive load")
			return
		if not gadget_activation_pending or not is_instance_valid(gadget_chamber) or gadget_chamber.currentState == Chamber.State.EMPTY:
			gadget_drop_instance_id = carried_gadget.get_instance_id()
			gadget_delivery_pending = true
			if state != State.RETURN:
				_change(State.RETURN, "The chamber gadget requires an exclusive direct return")
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
		State.NAVIGATE: _navigate()
		State.MINE: _mine()
		State.CARRY: _carry()
		State.RETURN: _return()
		State.UPGRADE: _upgrade()
		State.DEFEND: _defend()
		State.RECOVER: _recover()

func _physics_process(_delta: float) -> void:
	if not running or state != State.DEFEND:
		return
	if (
		delay > 0.0
		or not StageManager.isInLevel()
		or not Level.initialized
		or not is_instance_valid(keeper)
		or not is_instance_valid(dome)
	):
		_release_all()
		return
	if (
		_blocked()
		or not keeper.isInsideStation
		or not _wave("wavepresent")
		or _leaf() != "BattleInputProcessor"
	):
		_release_all()
		return
	_aim()

func _configure_recording() -> void:
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(RECORDING_ARG):
			directory = argument.trim_prefix(RECORDING_ARG).simplify_path()
		elif argument.begins_with(RECORDING_FPS_ARG):
			recording_fps = int(argument.trim_prefix(RECORDING_FPS_ARG))
	if directory.is_empty() and recording_fps == 0:
		return
	var movie := ProjectSettings.globalize_path(Engine.get_write_movie_path()).simplify_path()
	if not directory.is_absolute_path() or not DirAccess.dir_exists_absolute(directory) or recording_fps <= 0:
		push_error("Recording directory and FPS are invalid")
		get_tree().quit(1)
	elif not OS.has_feature("movie") or movie != directory.path_join(RECORDING_MOVIE):
		push_error("Movie Maker output does not match the recording session")
		get_tree().quit(1)
	else:
		recording_path = directory.path_join("recording.json")

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
	if recording.is_empty() or record_pending:
		return
	record_pending = true
	record_reason = reason
	await get_tree().process_frame
	record_pending = false
	_record("observation", record_reason, null)

func _record(type: String, reason: String, transition) -> void:
	if recording.is_empty():
		return
	recording["events"].append({
		"movie_frame": Engine.get_process_frames(), "type": type, "reason": reason,
		"transition": transition, "state": get_status_snapshot(),
	})
	var file := FileAccess.open(recording_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write replay: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(recording))

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
			"nav_mode": NavMode.keys()[nav_mode] if state == State.NAVIGATE else null,
		},
		"keeper": {
			"carried_resources": _status_carried_resources(),
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
	if not StageManager.isInLevel() or not Level.initialized or Level.map == null:
		return "Start a run before starting teacher collection"
	if Level.isMultiplayer() or Keepers.local.getCount() != 1 or Options.useGamepad(0):
		return "Teacher requires one offline keyboard keeper"
	keeper = Keepers.getLocalKeeperByDeviceId(0)
	if not is_instance_valid(keeper) or keeper.techId != "keeper1":
		return "Teacher requires Engineer on keyboard device 0"
	dome = Level.getDome(keeper.teamId)
	if not is_instance_valid(dome) or dome.techId != "dome1" or _laser() == null:
		return "Teacher requires one normal Laser Dome weapon"
	var full_load := _full_load_count(_carry_loss())
	if full_load <= 0 or full_load >= 128:
		return "Engineer carry slowdown does not produce a bounded supported load"
	if not is_finite(_planning_base_speed()) or _planning_base_speed() <= 0.0:
		return "Engineer movement speed must be positive and finite"
	return ""

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

func _navigate() -> void:
	if _claim_gadget_chamber():
		if _wave("wavepresent"):
			_change(State.RETURN, "The active monster wave interrupted gadget retrieval")
		else:
			_handle_gadget_chamber()
		return
	if _wave("wavepresent"):
		_change(State.RETURN, "The monster wave has started")
		return
	if cache_cleanup_mode == CacheCleanupMode.ACTIVE:
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
	if shaft_exhausted:
		var target := _next_upgrade_target()
		var id: String = target.get("id", "")
		if _wave_needed() or (not id.is_empty() and _upgrade_ready(id)):
			_change(State.RETURN, "The exhausted fishbone shaft is idle and a station task is ready")
			return
		_release_all()
		return
	if keeper.isInsideDome and _must_return_now():
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
	var carry_preview := _carry_window_plan()
	if not carry_preview.is_empty():
		if _begin_carry("The planned carry window has opened", carry_preview):
			return
		if not running:
			return
	if _must_return_now():
		_change(State.RETURN, "No cache trip remains safe; return to the dome")
		return
	if branch_resume_coord != NO_COORD:
		var current_coord: Vector2i = Level.map.getTileCoord(keeper.global_position)
		if current_coord == branch_resume_coord:
			branch_resume_coord = NO_COORD
			_change_navigation(NavMode.BRANCH, "The keeper returned to the interrupted fishbone branch")
			_release_all()
			delay = 0.2
			return
		if _move_open(Level.map.getTilePos(branch_resume_coord)):
			return
		_fail("No open path remains to the interrupted fishbone branch")
		return

	var cell: Vector2i = Level.map.getTileCoord(keeper.global_position)
	ore = _nearest_ore()
	if ore != NO_COORD:
		ore_approach_coord = _faster_open_ore_approach(ore)
		vein = [ore]; _change(State.MINE, "A revealed ore vein is in view")
		return

	if nav_mode == NavMode.ALIGN:
		if absf(keeper.global_position.x - align_x) > 6.0:
			_hold([&"ui_right" if keeper.global_position.x < align_x else &"ui_left"])
			return
		if branch_row < -1000:
			branch_row = maxi(cell.y + BRANCH_ROW_STEP, 1)
		_change_navigation(NavMode.DESCEND, "The keeper is aligned with the shaft")
	if nav_mode == NavMode.DESCEND:
		if cell.y < branch_row:
			var below = Level.map.getTile(cell + Vector2i.DOWN)
			if below is Tile and below.type == CONST.BORDER:
				_release_all()
				_change_navigation(NavMode.BYPASS, "Revealed border blocks the shaft below")
				bypass_side = 1
				bypass_reversed = false
				_reset_progress()
				delay = 0.2
				return
			_hold([&"ui_down"])
			return
		branch_entry_x = Level.map.getTilePos(cell).x
		_change_navigation(NavMode.BRANCH, "The target fishbone branch row was reached")
	if nav_mode == NavMode.BYPASS:
		var bypass_below = Level.map.getTile(cell + Vector2i.DOWN)
		if not (bypass_below is Tile and bypass_below.type == CONST.BORDER):
			_release_all()
			align_x = Level.map.getTilePos(cell).x
			_change_navigation(NavMode.ALIGN, "A deeper column was found beyond the border")
			bypass_reversed = false
			_reset_progress()
			delay = 0.2
			return
		var bypass_next = Level.map.getTile(cell + Vector2i(bypass_side, 0))
		if bypass_next is Tile and bypass_next.type == CONST.BORDER:
			_release_all()
			if bypass_reversed:
				_exhaust_shaft("Both lateral bypass directions ended at revealed border")
				return
			bypass_reversed = true
			bypass_side = -1
			_reset_progress()
			delay = 0.2
			return
		_hold([&"ui_right" if bypass_side > 0 else &"ui_left"])
		return
	var branch_next = Level.map.getTile(cell + Vector2i(branch_side, 0))
	if branch_next is Tile and branch_next.type == CONST.BORDER:
		_release_all()
		branch_side *= -1
		align_x = branch_entry_x
		_change_navigation(NavMode.ALIGN, "The revealed branch endpoint was reached")
		if branch_side > 0:
			branch_row += BRANCH_ROW_STEP
		_reset_progress()
		delay = 0.2
		return
	_hold([&"ui_right" if branch_side > 0 else &"ui_left"])

func _mine() -> void:
	if _claim_gadget_chamber():
		if not vein.is_empty():
			_record_cache()
		_change(State.NAVIGATE, "A revealed gadget chamber takes priority over the ore vein")
		return
	var active_cache_site = Level.map.getTilePos(vein.front()) if not vein.is_empty() else null
	var carry_preview := _carry_window_plan(active_cache_site)
	if not carry_preview.is_empty():
		_record_cache()
		if _begin_carry("The planned carry window opened while mining", carry_preview):
			return
		if not running:
			return
		_change(State.RETURN, "The carry window opened, but no pickup remains safe")
		return
	if _must_return_now():
		_record_cache()
		_change(State.RETURN, "No cache trip remains safe; stop mining and return")
		return
	if ore == NO_COORD or not Level.map.getTile(ore) is Tile:
		ore_approach_coord = NO_COORD
		ore = _adjacent_ore()
	if ore == NO_COORD:
		_record_cache(); _change(State.NAVIGATE, "The revealed ore vein has been cleared")
		return
	if not vein.has(ore):
		vein.append(ore)
		ore_approach_coord = _faster_open_ore_approach(ore)
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
	if _claim_gadget_chamber():
		_change(State.NAVIGATE, "A revealed gadget chamber interrupted the resource carry plan")
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
	if _move_open(carry.global_position):
		return
	pickup_failures += 1
	if pickup_failures >= 3:
		_ignore_failed_cleanup_drop()
		_change(State.RETURN, "Repeated resource pickup or path attempts failed")
		return
	carry = null

func _return() -> void:
	if gadget_delivery_pending and not is_instance_valid(_carried_gadget()):
		_wait_for_gadget_task("Delivered chamber gadget did not open its mandatory choice popup")
		return
	if _claim_gadget_chamber() and not gadget_delivery_pending:
		if not _wave("wavepresent") and not _wave("wavebattle") and keeper.isInsideStation:
			_release_all()
			if _leaf() == "StationInputProcessor":
				_tap(&"ui_cancel")
			_change(State.NAVIGATE, "The settled interruption resumes the saved gadget chamber")
			delay = 0.5
			return
		if not _wave("wavepresent") and not _wave("wavebattle"):
			_change(State.NAVIGATE, "The revealed gadget chamber cancels the ordinary return")
			return
	if keeper.isInsideStation:
		_release_all(); var leaf := _leaf()
		if leaf == "StationInputProcessor":
			if is_instance_valid(gadget_chamber) and (_wave("wavepresent") or _wave("wavebattle")):
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
			_change(State.NAVIGATE, "No upgrade or defense task requires the station")
			delay = 0.5
		elif leaf == "Keeper1InputProcessor":
			_change(State.NAVIGATE, "No upgrade or defense task requires the station")
		return

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

func _handle_gadget_choice(delta: float) -> bool:
	var processor = InputSystem.getLastChild(keeper.deviceId)
	var is_gadget_processor := is_instance_valid(processor) and str(processor.name) == "GadgetChoiceInputProcessor"
	if InputSystem.processors_changing:
		return is_gadget_processor or not gadget_offer_id.is_empty() or gadget_confirming
	if not is_gadget_processor:
		if not gadget_offer_id.is_empty() or gadget_confirming:
			_finish_gadget_choice()
		return false

	gadget_ui_delay = maxf(gadget_ui_delay - delta, 0.0)
	if gadget_ui_delay > 0.0:
		return true
	if not is_instance_valid(processor.popup):
		_wait_for_gadget_choice("Gadget choice popup did not become available")
		return true
	var popup = processor.popup
	if str(popup.droptype) != CONST.GADGET:
		_fail("Unsupported artifact choice type: " + str(popup.droptype))
		return true
	if not bool(popup.animationDone) or popup.offersById.is_empty():
		_wait_for_gadget_choice("Gadget offers did not become available")
		return true

	if gadget_offer_id.is_empty():
		gadget_offer_id = _choose_gadget_offer(popup)
		gadget_ui_steps = 0
		if gadget_offer_id.is_empty():
			_fail("Gadget popup has neither a supported offer nor the shred fallback")
			return true

	var target = popup.offersById.get(String(gadget_offer_id))
	if not is_instance_valid(target) or bool(target.disabled):
		_fail("Chosen gadget offer is no longer selectable: " + String(gadget_offer_id))
		return true
	if gadget_confirming:
		_wait_for_gadget_choice("Game did not confirm gadget selection")
		return true

	var current = popup.get_viewport().gui_get_focus_owner()
	if not is_instance_valid(current) or not current is Control:
		_wait_for_gadget_choice("Gadget popup did not expose a focused option")
		return true
	if current == target:
		var selected: Variant = popup.selectedGadget
		if not selected is Dictionary or StringName(str(selected.get("id", ""))) != gadget_offer_id:
			_wait_for_gadget_choice("Focused gadget offer did not become selected")
			return true
		_tap(&"ui_select")
		gadget_confirming = true
		gadget_ui_steps = 0
		gadget_ui_delay = TICK
		return true

	if not _consume_gadget_ui_step("Could not focus the chosen gadget through normal UI actions"):
		return true
	var options = popup.find_child("Gadgets")
	if not is_instance_valid(options):
		_fail("Gadget popup has no options container")
		return true
	if current.get_parent() != options:
		_tap(&"ui_down")
		gadget_ui_delay = 0.15
		return true
	var focus_delta: Vector2 = target.global_position - current.global_position
	if absf(focus_delta.x) >= absf(focus_delta.y):
		_tap(&"ui_right" if focus_delta.x > 0.0 else &"ui_left")
	else:
		_tap(&"ui_down" if focus_delta.y > 0.0 else &"ui_up")
	gadget_ui_delay = 0.15
	return true

func _choose_gadget_offer(popup) -> StringName:
	var supported: Array[StringName] = []
	for offered_value in popup.offersById.keys():
		var offered_id := StringName(str(offered_value))
		var panel = popup.offersById[offered_value]
		if is_instance_valid(panel) and not bool(panel.disabled) and GADGET_CATALOG.is_supported(offered_id):
			supported.append(offered_id)
	supported.sort_custom(_gadget_offer_less)
	var target := _next_upgrade_target(false)
	if not target.is_empty():
		var benefit := _gadget_benefit_for_intent(int(target["intent"]))
		for offered_id in supported:
			if GADGET_CATALOG.benefit_mask(offered_id) & benefit != 0:
				return offered_id
	if not supported.is_empty():
		return supported.front()
	if popup.offersById.has(String(GADGET_CATALOG.SHRED_ID)):
		return GADGET_CATALOG.SHRED_ID
	return StringName()

func _gadget_benefit_for_intent(intent: int) -> int:
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

func _gadget_offer_less(left: StringName, right: StringName) -> bool:
	var left_base := String(GADGET_CATALOG.base_id(left))
	var right_base := String(GADGET_CATALOG.base_id(right))
	if left_base == right_base:
		return String(left) < String(right)
	return left_base < right_base

func _consume_gadget_ui_step(reason: String) -> bool:
	gadget_ui_steps += 1
	if gadget_ui_steps <= GADGET_UI_STEP_LIMIT:
		return true
	_fail(reason)
	return false

func _wait_for_gadget_choice(reason: String) -> void:
	if _consume_gadget_ui_step(reason):
		gadget_ui_delay = TICK

func _finish_gadget_choice() -> void:
	var selected_id := gadget_offer_id
	var was_confirming := gadget_confirming
	_reset_gadget_choice()
	if not was_confirming:
		_fail("Gadget choice closed before the teacher submitted a selection")
		return
	if not GADGET_CATALOG.is_shred(selected_id) and not GameWorld.boughtUpgrades.has(String(selected_id)):
		_fail("Selected gadget was not installed: " + String(selected_id))
		return
	var base_id := String(GADGET_CATALOG.base_id(selected_id))
	var reason := "Gadget offer shredded" if GADGET_CATALOG.is_shred(selected_id) else "Gadget selected: " + base_id
	_record("gadget_choice", reason, null)
	_reset_gadget_retrieval()

func _reset_gadget_choice() -> void:
	gadget_offer_id = StringName()
	gadget_ui_steps = 0
	gadget_ui_delay = 0.0
	gadget_confirming = false

func _claim_gadget_chamber() -> bool:
	if gadget_activation_pending:
		return true
	if is_instance_valid(gadget_chamber):
		if gadget_chamber.currentState != Chamber.State.HIDDEN and gadget_chamber.currentState != Chamber.State.EMPTY:
			return true
		gadget_chamber = null
		gadget_activation_pending = false
		gadget_task_wait_steps = 0

	var best: Chamber
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("chamber"):
		if not candidate is Chamber:
			continue
		if candidate.type != CONST.GADGET or candidate.drop_type != CONST.GADGET:
			continue
		if candidate.currentState == Chamber.State.HIDDEN or candidate.currentState == Chamber.State.EMPTY:
			continue
		if not candidate.is_visible_in_tree():
			continue
		var distance := keeper.global_position.distance_squared_to(candidate.global_position)
		var candidate_coord := Vector2i(candidate.coord)
		var best_coord := Vector2i(best.coord) if is_instance_valid(best) else NO_COORD
		var earlier_coord := (
			candidate_coord.y < best_coord.y
			or (candidate_coord.y == best_coord.y and candidate_coord.x < best_coord.x)
		)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and earlier_coord):
			best = candidate
			best_distance = distance
	gadget_chamber = best
	return is_instance_valid(gadget_chamber)

func _handle_gadget_chamber() -> void:
	if not is_instance_valid(gadget_chamber):
		_fail("The active gadget chamber disappeared")
		return
	if _wave("wavepresent"):
		_change(State.RETURN, "The monster wave interrupted gadget chamber retrieval")
		return
	var carried := _carried_gadget()
	if is_instance_valid(carried):
		if keeper.carriedCarryables.size() != 1:
			_fail("A chamber gadget attached before its load became exclusive")
			return
		if gadget_chamber.currentState != Chamber.State.EMPTY:
			_wait_for_gadget_task("The chamber did not confirm the gadget release")
			return
		gadget_drop_instance_id = carried.get_instance_id()
		gadget_delivery_pending = true
		_change(State.RETURN, "The chamber gadget attached and must return alone")
		return
	if gadget_activation_pending:
		_wait_for_gadget_attachment()
		return
	if not keeper.carriedCarryables.is_empty():
		_drop_cargo_for_gadget()
		return

	match gadget_chamber.currentState:
		Chamber.State.REVEALED:
			var cover_plan := _gadget_cover_plan()
			if cover_plan.is_empty():
				_wait_for_gadget_task("No revealed gadget cover has a reachable open approach")
				return
			gadget_task_wait_steps = 0
			var approach: Vector2i = cover_plan["approach"]
			var target: Vector2i = cover_plan["target"]
			if Level.map.getTileCoord(keeper.global_position) != approach:
				if not _move_open(Level.map.getTilePos(approach)):
					_fail("The revealed gadget cover approach became unreachable")
				return
			_hold(_axis(Level.map.getTilePos(target)))
		Chamber.State.OPENING:
			_release_all()
			_wait_for_gadget_task("Gadget chamber did not finish opening")
		Chamber.State.OPEN:
			_activate_gadget_chamber()
		Chamber.State.EMPTY:
			_fail("Gadget chamber became empty without attaching its artifact")
		_:
			_fail("Gadget chamber returned to an unsupported state")

func _gadget_cover_plan() -> Dictionary:
	if not is_instance_valid(gadget_chamber.tileCover):
		return {}
	var best := {}
	var best_distance := INF
	for local_cell in gadget_chamber.tileCover.get_used_cells(MapData.DEFAULT_LAYER):
		var target := Vector2i(gadget_chamber.coord + Vector2(local_cell))
		if not Level.map.isRevealed(target):
			continue
		var tile = Level.map.getTile(target)
		if not tile is Tile or tile.type != CONST.GADGET:
			continue
		for direction in CARDINAL_OFFSETS:
			var approach: Vector2i = target + direction
			var distance := _path_distance(keeper.global_position, Level.map.getTilePos(approach))
			if not is_finite(distance):
				continue
			if distance < best_distance:
				best = {"target": target, "approach": approach}
				best_distance = distance
	return best

func _activate_gadget_chamber() -> void:
	if not keeper.carriedCarryables.is_empty():
		_drop_cargo_for_gadget()
		return
	var usable := gadget_chamber.get_node_or_null("Usable") as Node2D
	if not is_instance_valid(usable) or not gadget_chamber.canFocusUse(keeper):
		_wait_for_gadget_task("Open gadget chamber did not expose its usable target")
		return
	if keeper.focussedUsable == usable and _leaf() == "Keeper1InputProcessor":
		_release_all()
		gadget_prior_drop_ids.clear()
		for candidate in Level.drops.get_all_drops().values():
			if candidate is Drop and candidate.type == CONST.GADGET:
				gadget_prior_drop_ids[candidate.get_instance_id()] = true
		_tap(&"ui_select")
		gadget_activation_pending = true
		gadget_task_wait_steps = 0
		delay = 0.2
		return
	if Level.map.getTileCoord(keeper.global_position) == Level.map.getTileCoord(usable.global_position):
		var actions := _axis(usable.global_position)
		if not actions.is_empty():
			gadget_task_wait_steps = 0
			_hold(actions)
			return
		_wait_for_gadget_task("The open gadget chamber did not receive exact usable focus")
		return
	if not _move_open(usable.global_position):
		_fail("No open path reaches the gadget chamber usable")
	else:
		gadget_task_wait_steps = 0

func _wait_for_gadget_attachment() -> void:
	var carried := _carried_gadget()
	if is_instance_valid(carried) and gadget_chamber.currentState == Chamber.State.EMPTY:
		if keeper.carriedCarryables.size() != 1:
			_fail("The chamber gadget did not attach as an exclusive load")
			return
		gadget_drop_instance_id = carried.get_instance_id()
		gadget_delivery_pending = true
		_change(State.RETURN, "The chamber gadget attached and must return alone")
		return
	_wait_for_gadget_task("Activated gadget chamber did not attach its artifact")

func _drop_cargo_for_gadget() -> void:
	if _leaf() != "Keeper1InputProcessor":
		_fail("Cannot unload cargo without keeper input control")
		return
	if keeper.carriedCarryables.any(func(item): return item is Drop and item.type == CONST.GADGET):
		_fail("Cannot unload mixed cargo without dropping the chamber gadget")
		return
	if keeper.carriedCarryables.any(func(item): return item is Drop and item.carryableType == "resource"):
		_record_cache_site(keeper.global_position)
	_release_all()
	_tap(&"keeper1_drop")
	_wait_for_gadget_task("Existing cargo could not be unloaded for exclusive gadget transport")
	delay = 0.2

func _wait_for_gadget_task(reason: String) -> void:
	_release_all()
	gadget_task_wait_steps += 1
	if gadget_task_wait_steps <= GADGET_TASK_WAIT_LIMIT:
		return
	_fail(reason)

func _carried_gadget() -> Drop:
	for carried in keeper.carriedCarryables:
		if not carried is Drop or carried.type != CONST.GADGET or carried.carryableType != "gadget":
			continue
		var instance_id: int = carried.get_instance_id()
		if gadget_drop_instance_id != 0 and instance_id != gadget_drop_instance_id:
			continue
		if gadget_activation_pending and gadget_prior_drop_ids.has(instance_id):
			continue
		return carried
	return null

func _reset_gadget_retrieval() -> void:
	gadget_chamber = null
	gadget_activation_pending = false
	gadget_delivery_pending = false
	gadget_drop_instance_id = 0
	gadget_prior_drop_ids.clear()
	gadget_task_wait_steps = 0

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
	if not keeper.isInsideStation:
		_change(State.RETURN, "The keeper left the battle station")
		return
	if is_instance_valid(gadget_chamber) and not gadget_delivery_pending and not _wave("wavepresent") and not _wave("wavebattle"):
		_release_all()
		if leaf == "BattleInputProcessor":
			_tap(&"ui_cancel")
			delay = 0.5
		elif leaf == "StationInputProcessor":
			_change(State.RETURN, "The settled wave releases the saved gadget task")
		elif leaf == "Keeper1InputProcessor":
			_change(State.NAVIGATE, "The settled wave releases the saved gadget task")
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
		_change(State.NAVIGATE, "The monster wave has settled")

func _recover() -> void:
	if _wave("wavepresent"):
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

func _nearest_ore() -> Vector2i:
	var best := NO_COORD
	var best_distance := INF
	for type in ORE_TYPES:
		for tile in Level.map.tilesByType.get(type, []):
			if not is_instance_valid(tile) or not tile.is_visible_in_tree():
				continue
			var screen_position: Vector2 = tile.get_global_transform_with_canvas().origin
			if not get_viewport().get_visible_rect().has_point(screen_position):
				continue
			var distance := keeper.global_position.distance_squared_to(tile.global_position)
			if distance < best_distance:
				best = Vector2i(tile.coord)
				best_distance = distance
	return best

func _faster_open_ore_approach(target: Vector2i) -> Vector2i:
	var best := NO_COORD
	var best_distance := INF
	for offset in CARDINAL_OFFSETS:
		var candidate := target + offset
		if not Level.map.visibleTileCoords.has(candidate):
			continue
		var distance := _path_distance(keeper.global_position, Level.map.getTilePos(candidate))
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best == NO_COORD:
		return NO_COORD
	var speed := _effective_speed(keeper.carriedCarryables.size(), _planning_base_speed(), _carry_loss())
	if best_distance / speed >= _direct_ore_approach_seconds(target, speed):
		return NO_COORD
	return best

func _direct_ore_approach_seconds(target: Vector2i, speed: float) -> float:
	var cursor: Vector2i = Level.map.getTileCoord(keeper.global_position)
	var seconds := 0.0
	while absi(cursor.x - target.x) + absi(cursor.y - target.y) > 1:
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
			var cell := Vector2i(tile.coord)
			for previous in vein:
				if absi(cell.x - previous.x) + absi(cell.y - previous.y) == 1:
					return cell
	return NO_COORD

func _record_cache() -> void:
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

func _cached_resources(extra_cache_site = null) -> Array[Drop]:
	var result: Array[Drop] = []
	for candidate in Level.drops.get_all_drops().values():
		if not candidate is Drop:
			continue
		if candidate.carryableType != "resource" or candidate.absorbed or candidate.independent or candidate.isCarried():
			continue
		if ignored_cache_drop_ids.has(candidate.get_instance_id()):
			continue
		var near_cache := caches.any(func(site): return site.distance_to(candidate.global_position) <= GameWorld.TILE_SIZE * 3.0)
		if not near_cache and extra_cache_site is Vector2:
			near_cache = extra_cache_site.distance_to(candidate.global_position) <= GameWorld.TILE_SIZE * 3.0
		if near_cache:
			result.append(candidate)
	return result

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
	if state != State.MINE or cache_cleanup_mode != CacheCleanupMode.NONE:
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
	ignored_cache_drop_ids[carry.get_instance_id()] = true
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

func _carry_window_plan(extra_cache_site = null) -> Dictionary:
	var wave_time := _wave_time()
	if not is_finite(wave_time):
		return {}
	if GameWorld.runTime >= carry_preview_refresh_at or extra_cache_site != carry_preview_extra_site:
		carry_preview_cache = _build_carry_plan(INF, extra_cache_site)
		carry_preview_refresh_at = GameWorld.runTime + CARRY_PREVIEW_INTERVAL
		carry_preview_extra_site = extra_cache_site
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

func _build_carry_plan(wave_time: float, extra_cache_site = null) -> Dictionary:
	var remaining := _cached_resources(extra_cache_site)
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
	carry_preview_extra_site = null

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
	var weapon = _laser(); var target = _visible_monster()
	if weapon == null or not weapon.inputReady or target == null:
		_release_all()
		return
	var damageable: bool = target.canBeHit() and not target.invulnerable
	var aim: Vector2 = target.getCenter() - weapon.global_position
	var error := wrapf(aim.angle() - (weapon.rotation - CONST.PI_HALF), -PI, PI)
	if aim.x < 0.0 and error > CONST.PI_HALF:
		error -= TAU
	elif aim.x > 0.0 and error < -CONST.PI_HALF:
		error += TAU
	var collider = null
	for raycast in weapon.raycasts:
		if not raycast.enabled:
			continue
		collider = raycast.get_collider()
		if collider != null:
			break
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
	if started_firing:
		_queue_record("Laser began firing at an acquired monster")

func _visible_monster():
	var wave = Level.monstersByTeamId.get(keeper.teamId)
	var best = null
	var best_damageable := false
	var best_distance := INF
	if not is_instance_valid(wave):
		return null
	for monster in wave.monstersInWave:
		if not is_instance_valid(monster) or monster.dead or monster.leaving:
			continue
		if monster.type == Monster.Type.WORM_ROCK:
			continue
		var screen_position: Vector2 = monster.get_global_transform_with_canvas().origin
		if not monster.is_visible_in_tree() or not get_viewport().get_visible_rect().has_point(screen_position):
			continue
		var damageable: bool = monster.canBeHit() and not monster.invulnerable
		var distance := dome.global_position.distance_squared_to(monster.getCenter())
		if best != null and not damageable and best_damageable:
			continue
		var closer := distance < best_distance
		var earlier: bool = is_equal_approx(distance, best_distance) and monster.get_instance_id() < best.get_instance_id()
		if best != null and damageable == best_damageable and not closer and not earlier:
			continue
		best = monster
		best_damageable = damageable
		best_distance = distance
	return best

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
	for intent_class in INTENT_CLASSES:
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
			if best.is_empty() or _upgrade_target_is_better(target, best, available):
				best = target
		if not best.is_empty():
			return best
	return {}

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
	return true

func _upgrade_ready(id: String) -> bool:
	if not GameWorld.upgrades.has(id) or not GameWorld.isUpgradeAddable(id):
		return false
	if id.ends_with(".domesandrepair") or id == "domesandrepair":
		if _dome_health() >= _dome_max_health():
			return false
	return GameWorld.canAfford(GameWorld.upgrades[id].get("cost", {}), keeper.teamId)

func _active_upgrade_ready() -> bool:
	if active_upgrade_intent == UpgradeIntent.REPAIR and _dome_health() / _dome_max_health() >= REPAIR_HEALTH_RATIO_THRESHOLD:
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
			drill_hits_by_tile.clear()
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
	for offset in CONST.PATHFINDING_OFFSETS:
		var result = Level.map.findPath(from + Vector2(offset), to, keeper.teamId)
		if result is PackedVector2Array and not result.is_empty():
			return result
	return PackedVector2Array()

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

func _change(next: State, reason: String) -> void:
	_release_all()
	var previous := state
	if (
		previous == State.NAVIGATE
		and nav_mode == NavMode.BRANCH
		and next != State.NAVIGATE
		and next != State.RECOVER
		and branch_resume_coord == NO_COORD
	):
		branch_resume_coord = Level.map.getTileCoord(keeper.global_position)
	if previous == State.CARRY and next != State.RECOVER:
		carry = null
		carry_plan.clear()
	state = next; delay = 0.2; pickup_failures = 0
	_reset_progress()
	if state == State.RETURN:
		nav_mode = NavMode.ALIGN
		align_x = dome.global_position.x
		bypass_side = 1; bypass_reversed = false
	elif state == State.UPGRADE:
		closing_upgrade = false; ui_steps = 0
	if next == previous:
		return
	var previous_name := str(State.keys()[previous])
	var current_name := str(State.keys()[next])
	ModLoaderLog.info(previous_name + " -> " + current_name + ": " + reason, LOG_NAME)
	_record("teacher_state", reason, {"from": previous_name, "to": current_name})

func _change_navigation(next: NavMode, reason: String) -> void:
	if next == nav_mode:
		return
	var previous := nav_mode
	nav_mode = next
	var previous_name := str(NavMode.keys()[previous])
	var current_name := str(NavMode.keys()[next])
	ModLoaderLog.info("NAVIGATE " + previous_name + " -> " + current_name + ": " + reason, LOG_NAME)
	_record("navigation_state", reason, {"from": previous_name, "to": current_name})

func _change_cache_cleanup(next: CacheCleanupMode, reason: String) -> void:
	if next == cache_cleanup_mode:
		return
	var previous := cache_cleanup_mode
	cache_cleanup_mode = next
	if next == CacheCleanupMode.NONE:
		ignored_cache_drop_ids.clear()
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
	if state == State.NAVIGATE and nav_mode == NavMode.BYPASS:
		_exhaust_shaft("The revealed-border bypass made no directed progress")
		return
	interrupted = state; probe_index = (DIRECTIONS.find(action) + 1) % DIRECTIONS.size()
	probe_count = 0; probe_time = 0.0
	probe_origin = keeper.global_position
	_change(State.RECOVER, "No directed movement or drill progress for four seconds")

func _on_mined(_amount = 0.0) -> void:
	var tile := keeper.drill_hit_test_ray.get_collider() as Tile
	if is_instance_valid(tile):
		var tile_id := tile.get_instance_id()
		var hits := int(drill_hits_by_tile.get(tile_id, 0)) + 1
		if hits >= DRILL_HIT_INTENT_THRESHOLD:
			var was_pending := pending_intents.has(UpgradeIntent.DRILL)
			pending_intents[UpgradeIntent.DRILL] = true
			if not was_pending:
				_queue_record("Drill upgrade requested after repeated hits")
		if tile.health <= 0.0:
			drill_hits_by_tile.erase(tile_id)
		else:
			drill_hits_by_tile[tile_id] = hits
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
		if drop is Drop and drop.type == CONST.GADGET and drop.carryableType == "gadget":
			var instance_id: int = drop.get_instance_id()
			if not gadget_activation_pending or not gadget_prior_drop_ids.has(instance_id):
				gadget_drop_instance_id = instance_id
				_queue_record("Keeper picked up a chamber gadget")
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
	if property.ends_with(".monsters.wavepresent") and bool(new_value) and not bool(old_value):
		wave_start_health = _dome_health(); wave_start_max_health = _dome_max_health()
		wave_health_tracking = true
	elif property.ends_with(".monsters.wavebattle") and bool(old_value) and not bool(new_value):
		if wave_health_tracking and wave_start_max_health > 0.0:
			var loss_ratio := maxf(wave_start_health - _dome_health(), 0.0) / wave_start_max_health
			if loss_ratio > WAVE_NET_HEALTH_LOSS_RATIO_THRESHOLD:
				pending_intents[UpgradeIntent.COMBAT] = true
		wave_health_tracking = false
		if cache_cleanup_mode == CacheCleanupMode.PENDING_DEFENSE:
			_change_cache_cleanup(CacheCleanupMode.ACTIVE, "The next monster wave settled after cache cleanup was requested")
	if property.ends_with(".dome.health") or property.ends_with(".dome.maxhealth"):
		_sync_repair_intent()
	_queue_record("Game data changed: " + property.get_slice(".", property.get_slice_count(".") - 1))

func _sync_repair_intent() -> void:
	if _dome_max_health() > 0.0 and _dome_health() / _dome_max_health() < REPAIR_HEALTH_RATIO_THRESHOLD:
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

func _exhaust_shaft(reason: String) -> void:
	shaft_exhausted = true
	branch_resume_coord = NO_COORD
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
