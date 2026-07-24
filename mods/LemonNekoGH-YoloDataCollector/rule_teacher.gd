extends Node

signal failed(reason: String)

enum State {
	ALIGN_SHAFT,
	MINE,
	RETURN,
	RESUME_MINE,
	RECOVER_DOWN,
	RECOVER_HORIZONTAL,
	RECOVER_PATH,
	DEFEND,
}

const LOG_NAME := "YoloDataCollector:Teacher"
const TICK_INTERVAL := 0.1
const TILE_STEP := 24.0
const RETURN_LOAD := 2
const WAVE_LEAD_SECONDS := 8.0
const AIM_START_RADIANS := 0.06
const STALL_SECONDS := 4.0
const MAX_WAYPOINTS := 512
const HORIZONTAL_MINE_TILES := 5
const PATH_RECOVERY_ACTIONS: Array[StringName] = [
	&"ui_right",
	&"ui_down",
	&"ui_left",
	&"ui_up",
]
const REQUIRED_ACTIONS: Array[StringName] = [
	&"ui_left",
	&"ui_right",
	&"ui_up",
	&"ui_down",
	&"ui_select",
	&"ui_cancel",
	&"keeper1_pickup",
	&"dome_battle",
	&"dome1_fire",
]

var running := false
var state := State.ALIGN_SHAFT
var keeper: Keeper
var dome: Dome
var bindings: Dictionary = {}
var held: Dictionary = {}
var tick_time := 0.0
var action_delay := 0.0
var stalled_time := 0.0
var shaft_x := 0.0
var mine_target := Vector2.ZERO
var mine_side := 1.0
var mine_resume_position := Vector2.ZERO
var has_mine_resume := false
var last_position := Vector2.ZERO
var waypoints := PackedVector2Array()
var waypoint_index := 0
var station_wait_time := 0.0
var recovery_elapsed := 0.0
var recovery_origin := Vector2.ZERO
var recovery_horizontal := &""
var path_recovery_return_state: State = State.ALIGN_SHAFT
var path_recovery_index := 0
var path_recovery_attempts := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start() -> bool:
	var error := _game_preflight()
	if error.is_empty():
		error = _prepare_bindings()
	if not error.is_empty():
		ModLoaderLog.error(error, LOG_NAME)
		return false

	running = true
	state = State.ALIGN_SHAFT
	action_delay = 0.0
	mine_side = 1.0
	has_mine_resume = false
	shaft_x = dome.global_position.x
	waypoints.clear()
	waypoint_index = 0
	station_wait_time = 0.0
	_reset_progress()
	if not keeper.mined.is_connected(_on_mined):
		keeper.mined.connect(_on_mined)
	ModLoaderLog.info(
		"Started state=" + str(State.keys()[state])
		+ " position=" + str(keeper.global_position),
		LOG_NAME,
	)
	return true


func stop() -> void:
	_release_all()
	if is_instance_valid(keeper) and keeper.mined.is_connected(_on_mined):
		keeper.mined.disconnect(_on_mined)
	running = false
	keeper = null
	has_mine_resume = false
	waypoints.clear()
	_reset_progress()


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if not running:
		return
	if not _runtime_is_valid():
		_fail("Teacher lost its supported game state")
		return
	if _blocking_overlay_visible():
		_release_all()
		_reset_progress()
		return
	if (
		state != State.DEFEND
		and not keeper.isInsideStation
		and _input_leaf_name() != "Keeper1InputProcessor"
	):
		_release_all()
		_reset_progress()
		return

	action_delay = maxf(action_delay - delta, 0.0)
	if (
		state != State.DEFEND
		and state != State.RECOVER_DOWN
		and state != State.RECOVER_HORIZONTAL
		and state != State.RECOVER_PATH
	):
		_track_progress(delta)
	if not running or action_delay > 0.0:
		return
	tick_time += delta
	if tick_time < TICK_INTERVAL:
		return
	tick_time = 0.0

	match state:
		State.ALIGN_SHAFT:
			_tick_align_shaft()
		State.MINE:
			_tick_mine()
		State.RETURN:
			_tick_return()
		State.RESUME_MINE:
			_tick_resume_mine()
		State.RECOVER_DOWN:
			_tick_recover_down()
		State.RECOVER_HORIZONTAL:
			_tick_recover_horizontal()
		State.RECOVER_PATH:
			_tick_recover_path()
		State.DEFEND:
			_tick_defend()


func _game_preflight() -> String:
	if not StageManager.isInLevel() or not Level.initialized or Level.map == null:
		return "Start a run before starting teacher collection"
	if Level.isMultiplayer() or Keepers.local.getCount() != 1 or Options.useGamepad(0):
		return "Teacher requires one offline keyboard keeper"

	keeper = Keepers.getLocalKeeperByDeviceId(0)
	if not is_instance_valid(keeper) or keeper.techId != "keeper1":
		return "Teacher requires Engineer on keyboard device 0"
	dome = Level.getDome(keeper.teamId)
	if not is_instance_valid(dome) or dome.techId != "dome1":
		return "Teacher requires the Laser Dome"
	if _laser() == null:
		return "Teacher requires exactly one normal Laser weapon"
	return ""


func _prepare_bindings() -> String:
	bindings.clear()
	for action in REQUIRED_ACTIONS:
		var binding := _key_binding(action)
		if binding == null:
			return "Missing keyboard binding for action: " + str(action)
		bindings[action] = binding
	return ""


func _runtime_is_valid() -> bool:
	if (
		not StageManager.isInLevel()
		or StageManager.isSwitchingStage()
		or not Level.initialized
		or Level.map == null
	):
		return false
	if GameWorld.gameover or GameWorld.lost or GameWorld.won or not is_instance_valid(keeper):
		return false
	if not is_instance_valid(StageManager.currentStage) or StageManager.currentStage.stage_ending:
		return false
	if keeper.killed or keeper.disabled or Keepers.getLocalKeeperByDeviceId(0) != keeper:
		return false
	return is_instance_valid(dome) and Level.getDome(keeper.teamId) == dome


func _tick_align_shaft() -> void:
	if _wave_imminent():
		_change_state(State.RETURN)
		return
	var target := Vector2(shaft_x, CONST.TILE_OFFSET.y)
	if absf(keeper.global_position.x - shaft_x) > 6.0:
		target.y = keeper.global_position.y
	if keeper.global_position.distance_squared_to(target) > 36.0:
		var actions := _axis_actions(target)
		if actions.has(&"ui_left") or actions.has(&"ui_right"):
			mine_side = 1.0 if actions.has(&"ui_right") else -1.0
		_set_actions(actions)
		return
	_change_state(State.MINE)


func _tick_mine() -> void:
	if _wave_imminent() or keeper.carriedCarryables.size() >= RETURN_LOAD:
		_start_return_from_mine()
		return
	if (
		is_instance_valid(keeper.focussedCarryable)
		and keeper.focussedCarryable.carryableType == "resource"
	):
		_release_all()
		_tap(&"keeper1_pickup")
		action_delay = 0.4
		return

	var horizontal_remaining: float = (
		(mine_target.x - keeper.global_position.x) * mine_side
	)
	if horizontal_remaining <= 6.0:
		_start_down_recovery()
		return
	var actions: Array[StringName] = [
		&"ui_right" if mine_side > 0.0 else &"ui_left"
	]
	_set_actions(actions)


func _start_return_from_mine() -> void:
	mine_resume_position = keeper.global_position
	has_mine_resume = true
	_change_state(State.RETURN)


func _tick_return() -> void:
	if keeper.isInsideStation:
		_release_all()
		var leaf_name := _input_leaf_name()
		var wave_needed := _wave_imminent()
		var station_input_ready := (
			leaf_name == "StationInputProcessor" and not InputSystem.processors_changing
		)
		if wave_needed and leaf_name == "BattleInputProcessor":
			_change_state(State.DEFEND, 0.5)
		elif wave_needed and station_input_ready:
			_tap(&"dome_battle")
			action_delay = 0.6
		elif (
			not wave_needed
			and keeper.carriedCarryables.is_empty()
			and not InputSystem.processors_changing
		):
			if leaf_name == "BattleInputProcessor" or station_input_ready:
				_tap(&"ui_cancel")
				action_delay = 0.6
		return
	if keeper.carriedCarryables.is_empty() and not _wave_imminent():
		var next_state := State.RESUME_MINE if has_mine_resume else State.ALIGN_SHAFT
		_change_state(next_state, 0.5)
		return
	var focussed_usable: Variant = keeper.focussedUsable
	var dome_station_focussed := (
		focussed_usable is Node and focussed_usable.get_parent() is DomeStation
	)
	if (
		dome_station_focussed
		and _input_leaf_name() == "Keeper1InputProcessor"
		and not InputSystem.processors_changing
	):
		_release_all()
		_tap(&"ui_select")
		action_delay = 0.8
		return

	if _follow_path():
		station_wait_time = 0.0
		return
	var target: Vector2 = dome.stations[0].global_position
	if keeper.global_position.y > dome.global_position.y:
		target.x = shaft_x
	if keeper.global_position.distance_squared_to(target) <= 16.0:
		_release_all()
		station_wait_time += TICK_INTERVAL
		if station_wait_time > 3.0:
			_fail("Teacher reached the Laser station but could not focus it")
		return
	station_wait_time = 0.0
	_set_actions(_axis_actions(target))


func _tick_defend() -> void:
	var wave_needed := _wave_imminent()
	var leaf_name := _input_leaf_name()
	if wave_needed:
		if not keeper.isInsideStation:
			_change_state(State.RETURN)
			return
		if leaf_name != "BattleInputProcessor":
			_release_all()
			stalled_time = 0.0
			if leaf_name == "StationInputProcessor" and not InputSystem.processors_changing:
				_tap(&"dome_battle")
				action_delay = 0.6
			return
		if not _wave_present():
			_release_all()
			stalled_time = 0.0
			return
		_track_defense_target()
		return

	_release_all()
	if _wave_battle_active():
		stalled_time = 0.0
	else:
		stalled_time += TICK_INTERVAL
		if stalled_time > 5.0:
			_fail("Teacher could not leave battle input")
			return
		if not keeper.isInsideStation:
			if leaf_name == "Keeper1InputProcessor" and not InputSystem.processors_changing:
				var next_state := State.RESUME_MINE if has_mine_resume else State.ALIGN_SHAFT
				_change_state(next_state, 0.5)
			return
		if (
			not InputSystem.processors_changing
			and (leaf_name == "BattleInputProcessor" or leaf_name == "StationInputProcessor")
		):
			_tap(&"ui_cancel")
			action_delay = 0.6


func _tick_resume_mine() -> void:
	if _wave_imminent():
		_change_state(State.RETURN)
		return
	if _follow_path():
		return
	has_mine_resume = false
	_change_state(State.MINE, 0.1)


func _tick_recover_down() -> void:
	if _wave_imminent():
		_start_return_from_mine()
		return
	recovery_elapsed += TICK_INTERVAL
	if keeper.global_position.y - recovery_origin.y >= TILE_STEP:
		_change_state(State.MINE, 0.1)
		return
	if keeper.global_position.distance_to(last_position) >= 2.0:
		last_position = keeper.global_position
		recovery_elapsed = 0.0
	if recovery_elapsed >= STALL_SECONDS:
		_start_horizontal_recovery()
		return
	var actions: Array[StringName] = [&"ui_down"]
	_set_actions(actions)


func _tick_recover_horizontal() -> void:
	if _wave_imminent():
		_start_return_from_mine()
		return
	recovery_elapsed += TICK_INTERVAL
	var horizontal_distance := keeper.global_position.x - recovery_origin.x
	var moved_one_tile := (
		(recovery_horizontal == &"ui_right" and horizontal_distance >= TILE_STEP)
		or (recovery_horizontal == &"ui_left" and horizontal_distance <= -TILE_STEP)
	)
	if moved_one_tile:
		mine_side = 1.0 if recovery_horizontal == &"ui_right" else -1.0
		_change_state(State.MINE, 0.1)
		return
	if keeper.global_position.distance_to(last_position) >= 2.0:
		last_position = keeper.global_position
		recovery_elapsed = 0.0
	if recovery_elapsed >= STALL_SECONDS:
		_fail("Teacher could not move down or horizontally from the mining boundary")
		return
	var actions: Array[StringName] = [recovery_horizontal]
	_set_actions(actions)


func _tick_recover_path() -> void:
	if _wave_imminent() and path_recovery_return_state != State.RETURN:
		_change_state(State.RETURN)
		return
	var action: StringName = PATH_RECOVERY_ACTIONS[path_recovery_index]
	if _path_recovery_distance(action) >= TILE_STEP:
		_change_state(path_recovery_return_state, 0.1)
		return
	recovery_elapsed += TICK_INTERVAL
	if keeper.global_position.distance_to(last_position) >= 2.0:
		last_position = keeper.global_position
		recovery_elapsed = 0.0
	if recovery_elapsed >= STALL_SECONDS:
		path_recovery_attempts += 1
		if path_recovery_attempts >= PATH_RECOVERY_ACTIONS.size():
			_fail("Teacher exhausted four-direction path recovery")
			return
		path_recovery_index = (path_recovery_index + 1) % PATH_RECOVERY_ACTIONS.size()
		recovery_elapsed = 0.0
		recovery_origin = keeper.global_position
		last_position = keeper.global_position
		action = PATH_RECOVERY_ACTIONS[path_recovery_index]
	var actions: Array[StringName] = [action]
	_set_actions(actions)


func _track_defense_target() -> void:
	var weapon = _laser()
	if weapon == null or not weapon.is_multiplayer_authority():
		_fail("Teacher lost Laser authority")
		return
	if not weapon.inputReady:
		_release_all()
		stalled_time += TICK_INTERVAL
		if stalled_time > 5.0:
			_fail("Laser did not become ready")
		return
	var target: Monster = _nearest_visible_monster()
	if target == null:
		_release_all()
		stalled_time += TICK_INTERVAL
		if stalled_time >= 2.0:
			ModLoaderLog.debug("Defense is waiting for a visible monster", LOG_NAME)
			stalled_time = 0.0
		return
	stalled_time = 0.0

	var aim_vector: Vector2 = target.getCenter() - weapon.global_position
	var angle_diff: float = aim_vector.angle() - (weapon.rotation - CONST.PI_HALF)
	angle_diff = wrapf(angle_diff, -PI, PI)
	if aim_vector.x < 0.0 and angle_diff > CONST.PI_HALF:
		angle_diff -= TAU
	elif aim_vector.x > 0.0 and angle_diff < -CONST.PI_HALF:
		angle_diff += TAU

	var actions: Array[StringName] = []
	if absf(angle_diff) > AIM_START_RADIANS:
		actions.append(&"ui_right" if angle_diff > 0.0 else &"ui_left")
	else:
		actions.append(&"dome1_fire")
	_set_actions(actions)


func _nearest_visible_monster():
	var monsters = Level.monstersByTeamId.get(keeper.teamId)
	if not is_instance_valid(monsters):
		return null
	var best = null
	var best_distance := INF
	for monster in monsters.monstersInWave:
		if (
			not is_instance_valid(monster)
			or monster.dead
			or monster.leaving
			or not monster.hittable
		):
			continue
		if not _is_on_screen(monster):
			continue
		var distance := dome.global_position.distance_squared_to(monster.getCenter())
		if distance < best_distance:
			best = monster
			best_distance = distance
	return best


func _laser():
	if not is_instance_valid(dome):
		return null
	var found = null
	for station in dome.stations:
		for weapon in station.controlledWeapons:
			if weapon is LaserWeapon:
				if found != null or weapon.inverse:
					return null
				found = weapon
	return found


func _plan_path(destination: Vector2, failure_reason: String) -> String:
	waypoints.clear()
	waypoint_index = 0
	for offset in CONST.PATHFINDING_OFFSETS:
		var start_position: Vector2 = keeper.global_position + Vector2(offset)
		var result: Variant = Level.map.findPath(start_position, destination, keeper.teamId)
		if not result is PackedVector2Array:
			continue
		var candidate := PackedVector2Array(result)
		if candidate.is_empty():
			continue
		if candidate.size() > MAX_WAYPOINTS:
			return "Path exceeded its safety limit"
		waypoints = candidate
		return ""
	return failure_reason


func _follow_path() -> bool:
	while waypoint_index < waypoints.size():
		var waypoint: Vector2 = waypoints[waypoint_index]
		if keeper.global_position.distance_squared_to(waypoint) > 36.0:
			var target := waypoint
			if (
				keeper.global_position.y < 0.0
				and waypoint.y >= 0.0
				and absf(keeper.global_position.x - waypoint.x) > 6.0
			):
				target = Vector2(waypoint.x, keeper.global_position.y)
			_set_actions(_axis_actions(target))
			return true
		waypoint_index += 1
	return false


func _shaft_entrance() -> Vector2:
	return Vector2(shaft_x, -GameWorld.TILE_SIZE) + CONST.TILE_OFFSET


func _axis_actions(target: Vector2) -> Array[StringName]:
	var delta := target - keeper.global_position
	if delta.length_squared() < 16.0:
		return []
	if absf(delta.x) > absf(delta.y):
		return [&"ui_right" if delta.x > 0.0 else &"ui_left"]
	return [&"ui_down" if delta.y > 0.0 else &"ui_up"]


func _wave_present() -> bool:
	var key := keeper.teamId + ".monsters.wavepresent"
	return Data.has(key) and bool(Data.of(key))


func _wave_battle_active() -> bool:
	var key := keeper.teamId + ".monsters.wavebattle"
	return Data.has(key) and bool(Data.of(key))


func _wave_imminent() -> bool:
	if _wave_present():
		return true
	var key := keeper.teamId + ".monsters.waveCooldown"
	return GameWorld.runStarted and Data.has(key) and float(Data.of(key)) <= WAVE_LEAD_SECONDS


func _is_on_screen(node: CanvasItem) -> bool:
	if not node.is_visible_in_tree():
		return false
	var screen_position := node.get_global_transform_with_canvas().origin
	return get_viewport().get_visible_rect().has_point(screen_position)


func _blocking_overlay_visible() -> bool:
	if (
		InputSystem.game_not_in_focus
		or InputSystem.processors_changing
		or Level.stage.showingChoicePopup
	):
		return true
	if GameWorld.paused and _input_leaf_name() != "StationInputProcessor":
		return true
	for overlay in get_tree().get_nodes_in_group("yolo_pause_menu"):
		if overlay is CanvasItem and overlay.is_visible_in_tree():
			return true
	return false


func _input_leaf_name() -> String:
	var leaf = InputSystem.getLastChild(keeper.deviceId)
	return str(leaf.name) if is_instance_valid(leaf) else ""


func _key_binding(action: StringName) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func _set_actions(actions: Array[StringName]) -> void:
	for action in held.keys():
		if not actions.has(action):
			_emit_key(action, false)
			held.erase(action)
	for action in actions:
		if held.has(action):
			continue
		_emit_key(action, true)
		held[action] = true


func _tap(action: StringName) -> void:
	_emit_key(action, true)
	_emit_key(action, false)


func _emit_key(action: StringName, pressed: bool) -> void:
	var event := bindings[action].duplicate() as InputEventKey
	event.device = 0
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)


func _release_all() -> void:
	for action in held.keys():
		_emit_key(action, false)
	held.clear()


func _change_state(next_state: State, delay := 0.25) -> void:
	var previous_state := state
	ModLoaderLog.debug(
		"State " + str(State.keys()[previous_state])
		+ " -> " + str(State.keys()[next_state])
		+ " held=" + str(held.keys())
		+ " position=" + str(keeper.global_position)
		+ " target=" + str(mine_target)
		+ " side=" + ("right" if mine_side > 0.0 else "left")
		+ " input_leaf=" + _input_leaf_name(),
		LOG_NAME,
	)
	_release_all()
	state = next_state
	action_delay = delay
	_reset_progress()
	waypoints.clear()
	waypoint_index = 0
	station_wait_time = 0.0
	if state == State.RETURN:
		var path_error := _plan_path(
			_shaft_entrance(),
			"Teacher could not find an open return path",
		)
		if not path_error.is_empty():
			_fail(path_error)
		return
	if state == State.RESUME_MINE:
		var resume_path_error := _plan_path(
			mine_resume_position,
			"Teacher could not find an open path back to the mining frontier",
		)
		if not resume_path_error.is_empty():
			_fail(resume_path_error)
		return
	if state == State.MINE and is_instance_valid(keeper):
		mine_target = (
			keeper.global_position
			+ Vector2.RIGHT * mine_side * TILE_STEP * HORIZONTAL_MINE_TILES
		)


func _track_progress(delta: float) -> void:
	if held.is_empty():
		last_position = keeper.global_position
		stalled_time = 0.0
		return
	if keeper.global_position.distance_to(last_position) >= 2.0:
		_reset_progress()
		return
	stalled_time += delta
	if stalled_time < STALL_SECONDS:
		return
	if state == State.MINE and (held.has(&"ui_left") or held.has(&"ui_right")):
		_start_down_recovery()
		return
	if state == State.ALIGN_SHAFT or state == State.RETURN or state == State.RESUME_MINE:
		_start_path_recovery()
		return
	_fail("Teacher stopped after four seconds without position or drilling progress")


func _start_down_recovery() -> void:
	recovery_elapsed = 0.0
	recovery_origin = keeper.global_position
	_change_state(State.RECOVER_DOWN, 0.0)


func _start_horizontal_recovery() -> void:
	recovery_horizontal = &"ui_left" if mine_side > 0.0 else &"ui_right"
	recovery_elapsed = 0.0
	recovery_origin = keeper.global_position
	_change_state(State.RECOVER_HORIZONTAL, 0.0)


func _start_path_recovery() -> void:
	path_recovery_return_state = state
	path_recovery_index = 0
	for index: int in PATH_RECOVERY_ACTIONS.size():
		if not held.has(PATH_RECOVERY_ACTIONS[index]):
			continue
		path_recovery_index = (index + 1) % PATH_RECOVERY_ACTIONS.size()
		break
	path_recovery_attempts = 0
	recovery_elapsed = 0.0
	recovery_origin = keeper.global_position
	_change_state(State.RECOVER_PATH, 0.0)


func _on_mined(_amount = 0.0) -> void:
	if (
		state == State.RECOVER_DOWN
		or state == State.RECOVER_HORIZONTAL
		or state == State.RECOVER_PATH
	):
		recovery_elapsed = 0.0
		return
	_reset_progress()


func _reset_progress() -> void:
	stalled_time = 0.0
	if is_instance_valid(keeper):
		last_position = keeper.global_position


func _path_recovery_distance(action: StringName) -> float:
	var delta := keeper.global_position - recovery_origin
	match action:
		&"ui_right":
			return delta.x
		&"ui_down":
			return delta.y
		&"ui_left":
			return -delta.x
		&"ui_up":
			return -delta.y
	return 0.0


func _fail(reason: String) -> void:
	var state_name := str(State.keys()[state])
	var position := keeper.global_position if is_instance_valid(keeper) else Vector2.ZERO
	var input_leaf := _input_leaf_name() if is_instance_valid(keeper) else "invalid"
	var waypoint := (
		waypoints[waypoint_index]
		if waypoint_index >= 0 and waypoint_index < waypoints.size()
		else Vector2.ZERO
	)
	ModLoaderLog.error(
		reason
		+ " state=" + state_name
		+ " held=" + str(held.keys())
		+ " input_leaf=" + input_leaf
		+ " position=" + str(position)
		+ " last_position=" + str(last_position)
		+ " mine_target=" + str(mine_target)
		+ " recovery_origin=" + str(recovery_origin)
		+ " waypoint=" + str(waypoint)
		+ " waypoint_index=" + str(waypoint_index) + "/" + str(waypoints.size())
		+ " stalled_time=" + str(stalled_time)
		+ " recovery_elapsed=" + str(recovery_elapsed)
		+ " action_delay=" + str(action_delay),
		LOG_NAME,
	)
	stop()
	failed.emit(reason)
