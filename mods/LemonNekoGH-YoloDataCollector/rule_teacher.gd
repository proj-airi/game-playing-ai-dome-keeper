extends Node

signal failed(reason: String)

enum State { NAVIGATE, MINE, CARRY, RETURN, UPGRADE, DEFEND, RECOVER }
enum NavMode { ALIGN, DESCEND, BRANCH, BYPASS }

const LOG_NAME := "YoloDataCollector:Teacher"
const TICK := 0.1
const WAVE_LEAD := 12.0
const CARRY_LEAD := 24.0
const MIN_SPEED_RATIO := 0.55
const STALL_SECONDS := 4.0
const REVEAL_TILES := 1
const BRANCH_ROW_STEP := 1 + REVEAL_TILES * 2
const NO_COORD := Vector2i(1 << 30, 1 << 30)
const ORE_TYPES: Array[String] = [CONST.IRON, CONST.SAND, CONST.WATER]
const UPGRADES: Array[StringName] = [&"drill1", &"drill2", &"drill3"]
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_right", &"ui_down", &"ui_left"]
const ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_select", &"ui_cancel",
	&"keeper1_pickup", &"dome_battle", &"dome_upgrades",
]

var running := false
var state := State.NAVIGATE
var nav_mode := NavMode.ALIGN
var keeper: Keeper
var dome: Dome
var bindings := {}
var held := {}
var pending: Array[StringName] = []
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

func start() -> bool:
	var error := _preflight()
	if error.is_empty():
		error = _load_bindings()
	if not error.is_empty():
		ModLoaderLog.error(error, LOG_NAME)
		return false

	pending.assign(UPGRADES)
	while not pending.is_empty() and GameWorld.boughtUpgrades.has(_upgrade_id(pending.front())):
		pending.pop_front()
	running = true; state = State.NAVIGATE; nav_mode = NavMode.ALIGN
	branch_row = -1000000; branch_side = 1
	align_x = dome.global_position.x; branch_entry_x = align_x
	caches.clear()
	_reset_progress()
	keeper.mined.connect(_on_mined)
	GameWorld.upgradeBought.connect(_on_upgrade_bought)
	ModLoaderLog.info("Started rule teacher", LOG_NAME)
	return true

func stop() -> void:
	_release_all()
	if is_instance_valid(keeper) and keeper.mined.is_connected(_on_mined):
		keeper.mined.disconnect(_on_mined)
	if GameWorld.upgradeBought.is_connected(_on_upgrade_bought):
		GameWorld.upgradeBought.disconnect(_on_upgrade_bought)
	running = false; keeper = null; carry = null

func _process(delta: float) -> void:
	if not running:
		return
	if not StageManager.isInLevel() or not Level.initialized or not is_instance_valid(keeper):
		_fail("Teacher lost its supported game state")
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
			_change(State.CARRY)
		elif wave_time <= WAVE_LEAD or not keeper.isInsideDome:
			_change(State.RETURN)
		else:
			_release_all()
		return
	ore = _nearest_ore()
	if ore != NO_COORD:
		vein = [ore]; _change(State.MINE)
		return

	var cell: Vector2i = Level.map.getTileCoord(keeper.global_position)
	if nav_mode == NavMode.ALIGN:
		if absf(keeper.global_position.x - align_x) > 6.0:
			_hold([&"ui_right" if keeper.global_position.x < align_x else &"ui_left"])
			return
		if branch_row < -1000:
			branch_row = maxi(cell.y + BRANCH_ROW_STEP, 1)
		nav_mode = NavMode.DESCEND
	if nav_mode == NavMode.DESCEND:
		if cell.y < branch_row:
			var below = Level.map.getTile(cell + Vector2i.DOWN)
			if below is Tile and below.type == CONST.BORDER:
				_release_all()
				nav_mode = NavMode.BYPASS
				bypass_side = 1
				bypass_reversed = false
				_reset_progress()
				delay = 0.2
				return
			_hold([&"ui_down"])
			return
		branch_entry_x = Level.map.getTilePos(cell).x
		nav_mode = NavMode.BRANCH
	if nav_mode == NavMode.BYPASS:
		var bypass_below = Level.map.getTile(cell + Vector2i.DOWN)
		if not (bypass_below is Tile and bypass_below.type == CONST.BORDER):
			_release_all()
			align_x = Level.map.getTilePos(cell).x
			nav_mode = NavMode.ALIGN
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
		nav_mode = NavMode.ALIGN
		if branch_side > 0:
			branch_row += BRANCH_ROW_STEP
		_reset_progress()
		delay = 0.2
		return
	_hold([&"ui_right" if branch_side > 0 else &"ui_left"])

func _mine() -> void:
	if _wave_time() <= CARRY_LEAD:
		_record_cache(); _change(State.CARRY if _choose_carry(false) else State.RETURN)
		return
	if ore != NO_COORD and Level.map.getTile(ore) is Tile:
		_hold(_axis(Level.map.getTilePos(ore)))
		return
	ore = _adjacent_ore()
	if ore != NO_COORD:
		vein.append(ore)
		_hold(_axis(Level.map.getTilePos(ore)))
		return
	_record_cache(); _change(State.NAVIGATE)

func _carry() -> void:
	if _wave("wavepresent") or _speed_ratio(1) < MIN_SPEED_RATIO:
		_change(State.RETURN)
		return
	if not is_instance_valid(carry) or carry.isCarried():
		carry = null
		if not _choose_carry():
			_change(State.RETURN)
			return
	if keeper.focussedCarryable == carry:
		_release_all(); _tap(&"keeper1_pickup"); delay = 0.35
		return
	if _move_open(carry.global_position):
		return
	pickup_failures += 1; carry = null
	if pickup_failures >= 3:
		_change(State.RETURN)

func _return() -> void:
	if keeper.isInsideStation:
		_release_all(); var leaf := _leaf()
		if _head_affordable() and leaf == "StationInputProcessor":
			_change(State.UPGRADE)
			return
		if _wave_needed():
			_change(State.DEFEND)
			return
		if leaf == "StationInputProcessor":
			_tap(&"ui_cancel")
			_change(State.NAVIGATE)
			delay = 0.5
		elif leaf == "Keeper1InputProcessor":
			_change(State.NAVIGATE)
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
			_change(State.DEFEND if _wave_needed() else State.RETURN)
			return
		_tap(&"dome_upgrades")
		delay = 0.6
		return
	if leaf != "UpgradesInputProcessor":
		return
	if closing_upgrade or pending.is_empty():
		_tap(&"ui_cancel"); delay = 0.5
		return

	var processor = InputSystem.getLastChild(keeper.deviceId)
	var tree = processor.popup.find_child("TechTree")
	var current = tree.focussedTechPanel
	var target = null
	for panel in get_tree().get_nodes_in_group(keeper.playerId + "-techpanel"):
		if panel.techId == _upgrade_id(pending.front()):
			target = panel
			break
	if not is_instance_valid(current) or not is_instance_valid(target):
		return
	if current == target:
		_tap(&"ui_select"); delay = 0.5
		return
	ui_steps += 1
	if ui_steps > 30:
		_fail("Could not focus queued upgrade through normal UI actions")
		return
	var delta: Vector2 = target.global_position - current.global_position
	if absf(delta.x) >= absf(delta.y):
		_tap(&"ui_right" if delta.x > 0.0 else &"ui_left")
	else:
		_tap(&"ui_down" if delta.y > 0.0 else &"ui_up")
	delay = 0.15

func _defend() -> void:
	var leaf := _leaf()
	if not keeper.isInsideStation:
		_change(State.RETURN)
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
		_change(State.NAVIGATE)
		delay = 0.5
	elif leaf == "Keeper1InputProcessor":
		_change(State.NAVIGATE)

func _recover() -> void:
	var action := DIRECTIONS[probe_index]
	if _directed_distance(action, probe_origin) >= GameWorld.TILE_SIZE:
		_change(interrupted)
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
	var deficit := _reserved_iron_deficit()
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
		if drop.type != CONST.IRON or deficit <= 0:
			score += 100000.0
		if score < best_score:
			best = drop
			best_score = score
	if not is_instance_valid(best):
		return false
	if commit:
		carry = best
	return true

func _reserved_iron_deficit() -> int:
	var available := int(Data.getInventory(CONST.IRON, keeper.teamId))
	for drop in keeper.carriedCarryables:
		if drop is Drop and drop.type == CONST.IRON:
			available += 1
	for raw_id in pending:
		var cost := int(GameWorld.upgrades.get(_upgrade_id(raw_id), {}).get("cost", {}).get(CONST.IRON, 0))
		if available < cost:
			return cost - available
		available -= cost
	return 0

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

func _head_affordable() -> bool:
	return not pending.is_empty() and GameWorld.canAfford(GameWorld.upgrades[_upgrade_id(pending.front())].get("cost", {}), keeper.teamId)

func _upgrade_id(raw_id: StringName) -> String:
	var candidate := keeper.playerId + "." + str(raw_id)
	return candidate if GameWorld.upgrades.has(candidate) else str(raw_id)

func _on_upgrade_bought(id: String, team_id: String, player_id: String) -> void:
	if not running or team_id != keeper.teamId or player_id != keeper.playerId or pending.is_empty():
		return
	if id != _upgrade_id(pending.front()):
		return
	pending.pop_front(); ui_steps = 0; closing_upgrade = not _head_affordable()

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

func _change(next: State) -> void:
	_release_all()
	state = next; delay = 0.2; pickup_failures = 0
	_reset_progress()
	if state == State.RETURN:
		nav_mode = NavMode.ALIGN
		align_x = dome.global_position.x
		bypass_side = 1; bypass_reversed = false
	elif state == State.UPGRADE:
		closing_upgrade = false; ui_steps = 0

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
	_change(State.RECOVER)

func _on_mined(_amount = 0.0) -> void:
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
	Input.parse_input_event(event)

func _release_all() -> void:
	for action in held.keys():
		_emit(action, false)
	held.clear()

func _fail(reason: String) -> void:
	ModLoaderLog.error(reason + " state=" + str(State.keys()[state]), LOG_NAME)
	stop()
	failed.emit(reason)
