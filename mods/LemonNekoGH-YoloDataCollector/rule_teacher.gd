extends Node

signal failed(reason: String)

enum State { NAVIGATE, MINE, CARRY, RETURN, UPGRADE, DEFEND, RECOVER }
enum NavMode { ALIGN, DESCEND, BRANCH, BYPASS }
enum UpgradeIntent { COMBAT, REPAIR, DRILL, MOBILITY }

const LOG_NAME := "YoloDataCollector:Teacher"
const STATUS_FILE := "airi-dome-keeper-status.json"
const RECORDING_ARG := "--airi-recording-dir="
const RECORDING_FPS_ARG := "--airi-recording-fps="
const RECORDING_MOVIE := "recording.avi"
const TICK := 0.1
const WAVE_LEAD := 12.0
const CARRY_LEAD := 24.0
const MIN_SPEED_RATIO := 0.55
const STALL_SECONDS := 4.0
const REVEAL_TILES := 1
const BRANCH_ROW_STEP := 1 + REVEAL_TILES * 2
const DRILL_HIT_INTENT_THRESHOLD := 5
const WAVE_NET_HEALTH_LOSS_RATIO_THRESHOLD := 0.15
const RETURN_MOBILITY_SECONDS_THRESHOLD := 20.0
const REPAIR_HEALTH_RATIO_THRESHOLD := 0.2
const NO_COORD := Vector2i(1 << 30, 1 << 30)
const ORE_TYPES: Array[String] = [CONST.IRON, CONST.SAND, CONST.WATER]
const INTENT_PRIORITY: Array[int] = [UpgradeIntent.COMBAT, UpgradeIntent.REPAIR, UpgradeIntent.DRILL, UpgradeIntent.MOBILITY]
const ATTACK_UPGRADES: Array[StringName] = [&"laserStrength1", &"laserStrength2", &"laserStrength3", &"laserStrength4"]
const HEALTH_UPGRADES: Array[StringName] = [&"dome1health1", &"dome1health2"]
const HEALTH_PATH: Array[StringName] = [&"domeHealthMeter", &"domesandrepair", &"dome1health1", &"dome1health2"]
const REPAIR_UPGRADES: Array[StringName] = [&"domeHealthMeter", &"domesandrepair"]
const DRILL_UPGRADES: Array[StringName] = [&"drill1", &"drill2", &"drill3", &"drill4"]
const SPEED_UPGRADES: Array[StringName] = [&"jetpackSpeed1", &"jetpackSpeed2", &"jetpackSpeed3", &"jetpackSpeed4"]
const CARRY_UPGRADES: Array[StringName] = [&"jetpackStrength1", &"jetpackStrength2", &"jetpackStrength3", &"jetpackStrength4"]
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_right", &"ui_down", &"ui_left"]
const ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_select", &"ui_cancel",
	&"keeper1_pickup", &"dome_battle", &"dome_upgrades",
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
var mobility_speed_next := true
var drill_hits_by_tile := {}
var wave_start_health := 0.0
var wave_start_max_health := 0.0
var wave_health_tracking := false
var return_started_at := -1.0
var observed_properties: Array[String] = []
var caches: Array[Vector2] = []
var vein: Array[Vector2i] = []
var ore := NO_COORD
var carry: Drop
var branch_row := -1000000
var branch_side := 1
var align_x := 0.0
var branch_entry_x := 0.0
var bypass_side := 1
var bypass_reversed := false
var tick_time := 0.0
var delay := 0.0
var pickup_failures := 0
var ui_steps := 0
var closing_upgrade := false
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
	var error := _preflight()
	if error.is_empty():
		error = _load_bindings()
	if not error.is_empty():
		ModLoaderLog.error(error, LOG_NAME)
		return false

	previous_pause_when_out_of_focus = Options.pauseWhenOutOfFocus
	Options.pauseWhenOutOfFocus = false
	InputSystem.game_not_in_focus = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pending_intents.clear()
	pending_intents[UpgradeIntent.DRILL] = true
	active_upgrade_intent = -1; active_upgrade_id = ""
	combat_attack_next = _bought_count(ATTACK_UPGRADES) <= _bought_count(HEALTH_UPGRADES)
	mobility_speed_next = _bought_count(SPEED_UPGRADES) <= _bought_count(CARRY_UPGRADES)
	drill_hits_by_tile.clear(); return_started_at = -1.0
	wave_health_tracking = _wave("wavepresent") or _wave("wavebattle")
	wave_start_health = _dome_health(); wave_start_max_health = _dome_max_health()
	_sync_repair_intent()
	observed_properties.assign([
		keeper.teamId + ".monsters.wavepresent", keeper.teamId + ".monsters.wavebattle",
		keeper.teamId + ".event.keepers.insidedome", keeper.teamId + ".dome.health",
		keeper.teamId + ".dome.maxhealth", keeper.teamId + ".inventory.iron",
		keeper.teamId + ".inventory.sand", keeper.teamId + ".inventory.water",
	])
	for property in observed_properties:
		Data.listen(self, property)
	running = true; state = State.NAVIGATE; nav_mode = NavMode.ALIGN
	branch_row = -1000000; branch_side = 1
	align_x = dome.global_position.x; branch_entry_x = align_x
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
	var was_running := running
	if was_running:
		InputSystem.game_not_in_focus = false
	_release_all()
	for property in observed_properties:
		Data.unlisten(self, property)
	observed_properties.clear()
	if is_instance_valid(keeper) and keeper.mined.is_connected(_on_mined):
		keeper.mined.disconnect(_on_mined)
	if Level.drops.synchronizer.drop_picked_up.is_connected(_on_drop_picked_up):
		Level.drops.synchronizer.drop_picked_up.disconnect(_on_drop_picked_up)
	if Level.monstersByTeamId[keeper.teamId].monsterSynchronizer.spawned.is_connected(_on_monster_spawned):
		Level.monstersByTeamId[keeper.teamId].monsterSynchronizer.spawned.disconnect(_on_monster_spawned)
	if GameWorld.upgradeBought.is_connected(_on_upgrade_bought):
		GameWorld.upgradeBought.disconnect(_on_upgrade_bought)
	if GameWorld.upgradeError.is_connected(_on_upgrade_error):
		GameWorld.upgradeError.disconnect(_on_upgrade_error)
	running = false; keeper = null; carry = null
	if was_running:
		Options.pauseWhenOutOfFocus = previous_pause_when_out_of_focus
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
			"health": _dome_health(),
			"max_health": _dome_max_health(),
			"stored_resources": _status_stored_resources(),
		},
		"wave": {
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
	var attack_strength := (
		float(Data.ofOr(keeper.teamId + ".laser.dps", 0.0))
		* float(Data.ofOr(keeper.teamId + ".laser.dpsmod", 1.0))
	)
	return {
		"base_movement_speed": float(Data.of(keeper.playerId + ".keeper1.maxSpeed")),
		"attack_strength": attack_strength,
		"carry_slowdown_percent": float(keeper.get("carrySlowdown")) * 100.0,
		"current_movement_speed": keeper.currentSpeed() * _speed_ratio(0),
		"drill_strength": float(Data.of(keeper.playerId + ".keeper1.drillStrength")),
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
	for intent in INTENT_PRIORITY:
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
	var wave_time := _wave_time()
	if wave_time <= CARRY_LEAD:
		if _choose_carry(false):
			_change(State.CARRY, "Wave is approaching; collect a reachable cached resource")
		elif wave_time <= WAVE_LEAD or not keeper.isInsideDome:
			_change(State.RETURN, "Wave is approaching; return to the dome")
		else:
			_release_all()
		return
	ore = _nearest_ore()
	if ore != NO_COORD:
		vein = [ore]; _change(State.MINE, "A revealed ore vein is in view")
		return

	var cell: Vector2i = Level.map.getTileCoord(keeper.global_position)
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
				_fail("No deeper fishbone shaft exists beyond the revealed border")
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
	if _wave_time() <= CARRY_LEAD:
		_record_cache()
		if _choose_carry(false):
			_change(State.CARRY, "Wave is approaching; collect a reachable cached resource")
		else:
			_change(State.RETURN, "Wave is approaching; no reachable cached resource remains")
		return
	if ore != NO_COORD and Level.map.getTile(ore) is Tile:
		_hold(_axis(Level.map.getTilePos(ore)))
		return
	ore = _adjacent_ore()
	if ore != NO_COORD:
		vein.append(ore)
		_hold(_axis(Level.map.getTilePos(ore)))
		return
	_record_cache(); _change(State.NAVIGATE, "The revealed ore vein has been cleared")

func _carry() -> void:
	if _wave("wavepresent"):
		_change(State.RETURN, "The monster wave has started")
		return
	if _speed_ratio(1) < MIN_SPEED_RATIO:
		_change(State.RETURN, "Another pickup would exceed the accepted carry slowdown")
		return
	if not is_instance_valid(carry) or carry.isCarried():
		carry = null
		if not _choose_carry():
			_change(State.RETURN, "No reachable cached resource remains")
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
		_release_all(); _tap(&"keeper1_pickup"); delay = 0.35
		return
	if _move_open(carry.global_position):
		return
	pickup_failures += 1; carry = null
	if pickup_failures >= 3:
		_change(State.RETURN, "Repeated resource pickup or path attempts failed")

func _return() -> void:
	if keeper.isInsideStation:
		_release_all(); var leaf := _leaf()
		if leaf == "StationInputProcessor":
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
	if _wave_needed() and leaf != "BattleInputProcessor":
		_release_all()
		if leaf == "StationInputProcessor":
			_tap(&"dome_battle"); delay = 0.5
		return
	if _wave("wavepresent") and leaf == "BattleInputProcessor":
		_aim()
		return
	_release_all()
	if _wave("wavebattle"):
		return
	if leaf == "BattleInputProcessor":
		_tap(&"ui_cancel"); delay = 0.5
	elif leaf == "StationInputProcessor":
		_tap(&"ui_cancel")
		_change(State.NAVIGATE, "The monster wave has settled")
		delay = 0.5
	elif leaf == "Keeper1InputProcessor":
		_change(State.NAVIGATE, "The monster wave has settled")

func _recover() -> void:
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
	if caches.all(func(existing): return existing.distance_to(site) > GameWorld.TILE_SIZE):
		caches.append(site)
	vein.clear()
	ore = NO_COORD

func _loose_resources() -> Array:
	var result := []
	for drop in Level.drops.get_all_drops().values():
		if drop is Drop and drop.carryableType == "resource" and not drop.absorbed and not drop.independent and not drop.isCarried():
			result.append(drop)
	return result

func _choose_carry(commit := true) -> bool:
	var deficits := _reserved_resource_deficits()
	var best: Drop
	var best_score := INF
	var home := Vector2(dome.global_position.x, -GameWorld.TILE_SIZE) + CONST.TILE_OFFSET
	for drop in _loose_resources():
		if not caches.any(func(site): return site.distance_to(drop.global_position) <= GameWorld.TILE_SIZE * 3.0):
			continue
		var outward := _path(keeper.global_position, drop.global_position)
		var inward := _path(drop.global_position, home)
		if outward.is_empty() or inward.is_empty():
			continue
		var ratio := _speed_ratio(1)
		var distance: float = float(outward.size() + inward.size()) * float(GameWorld.TILE_SIZE)
		if distance / maxf(keeper.currentSpeed() * ratio, 1.0) + 4.0 >= _wave_time():
			continue
		var score: float = float(outward.size()) * float(GameWorld.TILE_SIZE) / ratio
		if int(deficits.get(drop.type, 0)) <= 0:
			score += 100000.0
		if score < best_score:
			best = drop
			best_score = score
	if not is_instance_valid(best):
		return false
	if commit:
		carry = best
	return true

func _reserved_resource_deficits() -> Dictionary:
	var available := {}
	for resource in ORE_TYPES:
		available[resource] = int(Data.getInventory(resource, keeper.teamId))
	for drop in keeper.carriedCarryables:
		if drop is Drop and available.has(drop.type):
			available[drop.type] += 1
	var seen := {}
	for intent in INTENT_PRIORITY:
		if not pending_intents.has(intent):
			continue
		var target := _resolve_intent(intent)
		var id: String = target.get("id", "")
		if id.is_empty() or seen.has(id):
			continue
		seen[id] = true
		var cost: Dictionary = GameWorld.upgrades[id].get("cost", {})
		var deficits := {}
		for resource in cost:
			var missing := int(cost[resource]) - int(available.get(resource, 0))
			if missing > 0:
				deficits[resource] = missing
		if not deficits.is_empty():
			return deficits
		for resource in cost:
			available[resource] = int(available.get(resource, 0)) - int(cost[resource])
	return {}

func _speed_ratio(extra: int) -> float:
	var count := keeper.carriedCarryables.size() + extra
	var loss := float(Data.of(keeper.playerId + ".keeper1.speedLossPerCarry"))
	var ratio := 1.0 - 0.005 * loss * count * (count + 1)
	return maxf(ratio, 0.0)

func _aim() -> void:
	var weapon = _laser(); var target = _visible_monster()
	if weapon == null or not weapon.inputReady or target == null:
		_release_all()
		return
	var aim: Vector2 = target.getCenter() - weapon.global_position
	var error := wrapf(aim.angle() - (weapon.rotation - CONST.PI_HALF), -PI, PI)
	if aim.x < 0.0 and error > CONST.PI_HALF:
		error -= TAU
	elif aim.x > 0.0 and error < -CONST.PI_HALF:
		error += TAU
	if absf(error) > 0.06:
		_hold([&"ui_right" if error > 0.0 else &"ui_left"])
	else:
		_hold([StringName(dome.techId + "_fire")])
		_queue_record("Laser attacked an active monster")

func _visible_monster():
	var wave = Level.monstersByTeamId.get(keeper.teamId)
	var best = null
	var best_distance := INF
	if not is_instance_valid(wave):
		return null
	for monster in wave.monstersInWave:
		if not is_instance_valid(monster) or monster.dead or monster.leaving or not monster.canBeHit():
			continue
		var screen_position: Vector2 = monster.get_global_transform_with_canvas().origin
		if not monster.is_visible_in_tree() or not get_viewport().get_visible_rect().has_point(screen_position):
			continue
		var distance := dome.global_position.distance_squared_to(monster.getCenter())
		if distance < best_distance or (is_equal_approx(distance, best_distance) and monster.get_instance_id() < best.get_instance_id()):
			best = monster
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
			target = _resolve_alternating(SPEED_UPGRADES, CARRY_UPGRADES, mobility_speed_next)
			target["fulfills"] = true
	target["intent"] = intent
	return target

func _next_upgrade_target(prune_exhausted := true) -> Dictionary:
	for intent in INTENT_PRIORITY:
		if not pending_intents.has(intent):
			continue
		var target := _resolve_intent(intent)
		if bool(target.get("exhausted", false)):
			if prune_exhausted:
				pending_intents.erase(intent)
				_queue_record("Upgrade plan changed")
			continue
		if not str(target.get("id", "")).is_empty():
			return target
	return {}

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
	if active_upgrade_fulfills:
		pending_intents.erase(active_upgrade_intent)
		if active_upgrade_intent == UpgradeIntent.COMBAT:
			combat_attack_next = active_upgrade_arm != 0
		elif active_upgrade_intent == UpgradeIntent.MOBILITY:
			mobility_speed_next = active_upgrade_arm != 0
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

func _move_open(target: Vector2) -> bool:
	var points := _path(keeper.global_position, target)
	if points.is_empty():
		return false
	_hold(_axis(points[mini(1, points.size() - 1)]))
	return true

func _change(next: State, reason: String) -> void:
	_release_all()
	var previous := state
	if next == State.RETURN and return_started_at < 0.0 and not keeper.isInsideDome:
		return_started_at = GameWorld.runTime
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
	return _wave("wavebattle") or _wave("wavepresent") or _wave_time() <= WAVE_LEAD

func _on_drop_picked_up(_drop, carrier) -> void:
	if carrier == keeper:
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
	elif property.ends_with(".event.keepers.insidedome") and not bool(old_value) and bool(new_value):
		if return_started_at >= 0.0 and GameWorld.runTime - return_started_at > RETURN_MOBILITY_SECONDS_THRESHOLD:
			pending_intents[UpgradeIntent.MOBILITY] = true
		return_started_at = -1.0
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

func _fail(reason: String) -> void:
	ModLoaderLog.error(reason + " state=" + str(State.keys()[state]), LOG_NAME)
	stop()
	failed.emit(reason)
