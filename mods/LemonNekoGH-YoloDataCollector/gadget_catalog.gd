extends RefCounted

# Target-version gadget policy for Dome Keeper 5.0.5.19.
#
# The keys are canonical base upgrade IDs from upgrades.yaml. Runtime offers can
# prefix them with a team or player ID, so callers must query through base_id().
# This catalog deliberately stores only facts the teacher needs for selection;
# the game's Data.gadgets remains authoritative for costs, slots, and upgrades.

enum Benefit {
	NONE = 0,
	COMBAT = 1 << 0,
	SURVIVAL_REPAIR = 1 << 1,
	MOVEMENT = 1 << 2,
	DRILLING = 1 << 3,
	CARRYING_LOGISTICS = 1 << 4,
}

enum Support {
	SUPPORTED,
	CHANGES_PLANNING,
	REQUIRES_INTERACTION,
	REQUIRES_NEW_ACTION,
	UNKNOWN,
}

const SHRED_ID := &"shredgadgettocobalt"

const _UNKNOWN_ENTRY := [Benefit.NONE, Support.UNKNOWN]
const _ENTRIES := {
	# The Furnace passively delays every wave cycle after installation. Supported:
	# that base effect needs no action; the teacher simply does not use its fuel popup.
	&"furnace": [Benefit.COMBAT, Support.SUPPORTED],

	# The Resource Extractor creates a carried worm that must be placed on an ore
	# deposit. Unsupported: it adds a carried type and an extraction lifecycle.
	&"extractor": [Benefit.CARRYING_LOGISTICS, Support.REQUIRES_INTERACTION],

	# The Stun Laser automatically tracks and stuns monsters while the keeper is
	# in the station. Supported: it needs no action beyond normal defense entry.
	&"stunlaser": [Benefit.COMBAT, Support.SUPPORTED],

	# The Autocannon automatically tracks and shoots monsters while the keeper is
	# in the station. Supported: it needs no additional teacher action.
	&"autocannon": [Benefit.COMBAT, Support.SUPPORTED],

	# The Spire automatically destroys hostile projectiles during a wave while
	# the keeper is in the station. Supported: it needs no additional operation.
	&"spire": [Benefit.COMBAT, Support.SUPPORTED],

	# Blast Mining produces carried explosive charges for breaking rock.
	# Unsupported: the teacher cannot collect, place, or reason about charges.
	&"blastMining": [Benefit.DRILLING, Support.REQUIRES_INTERACTION],

	# The Probe spends keeper-gadget charges to reveal nearby resources.
	# Unsupported: it requires a new action and changes revealed-map knowledge.
	&"probe": [Benefit.DRILLING, Support.REQUIRES_NEW_ACTION],

	# The Teleporter is carried into the mine and then used at either endpoint.
	# Unsupported: placement and teleport state require new navigation planning.
	&"teleporter": [
		Benefit.MOVEMENT | Benefit.CARRYING_LOGISTICS,
		Support.REQUIRES_INTERACTION,
	],

	# The Lift's autonomous orbs move loose resources along the main shaft.
	# Unsupported: moved drops invalidate cache ownership, position, and ETA.
	&"lift": [
		Benefit.MOVEMENT | Benefit.CARRYING_LOGISTICS,
		Support.CHANGES_PLANNING,
	],

	# The Condenser generates water that is collected from a cellar usable.
	# Unsupported: it adds a resource source and a new collection interaction.
	&"condenser": [Benefit.CARRYING_LOGISTICS, Support.REQUIRES_INTERACTION],

	# The Prospection Meter automatically scans for nearby resource directions.
	# Unsupported: its information is absent from the current observation model.
	&"prospectionmeter": [Benefit.DRILLING, Support.CHANGES_PLANNING],

	# The Suit Blaster spends a keeper-gadget charge to destroy surrounding rock.
	# Unsupported: it adds an action and non-drill terrain destruction.
	&"suitblaster": [Benefit.DRILLING, Support.REQUIRES_NEW_ACTION],

	# The Mine Drill extends down the shaft and can drill sideways or pull drops.
	# Unsupported: autonomous terrain changes invalidate the teacher's map plan.
	&"drill": [Benefit.DRILLING, Support.CHANGES_PLANNING],

	# The Chainsaw automatically attacks monsters at the dome while the keeper is
	# in the station. Supported: it needs no action beyond normal defense entry.
	&"chainsaw": [Benefit.COMBAT, Support.SUPPORTED],

	# Dome Armor immediately increases maximum dome health; later upgrades can
	# add an automatic stun pulse. Supported: both effects require no new action.
	&"domearmor": [
		Benefit.COMBAT | Benefit.SURVIVAL_REPAIR,
		Support.SUPPORTED,
	],

	# Drillbert is collected from a cellar station and directed in the mine.
	# Unsupported: it adds interactions and independently changes mine topology.
	&"drillbot": [Benefit.DRILLING, Support.REQUIRES_INTERACTION],

	# The Resource Converter opens a cellar popup and transforms stored minerals.
	# Unsupported: conversions change resource reservation and require popup use.
	&"converter": [Benefit.CARRYING_LOGISTICS, Support.REQUIRES_INTERACTION],

	# The Station Extension adds a remote dome-control station in the mine shaft.
	# Unsupported: it introduces a new input leaf and return/defense alternatives.
	&"stationextension": [Benefit.NONE, Support.REQUIRES_INTERACTION],

	# The Mushroom Farm produces carried mushrooms with temporary speed or drill
	# buffs. Unsupported: pickup, placement, and transient stats need new planning.
	&"mushroomfarm": [
		Benefit.MOVEMENT | Benefit.DRILLING,
		Support.REQUIRES_INTERACTION,
	],

	# The Resource Packer spends keeper-gadget charges to bundle nearby minerals.
	# Unsupported: it adds an action and a new packed-resource carryable type.
	&"resourcepacker": [
		Benefit.CARRYING_LOGISTICS,
		Support.REQUIRES_NEW_ACTION,
	],

	# The Shockwave Hammer is an active dome battle ability that damages and stuns
	# monsters. Unsupported: the teacher does not emit the second ability action.
	&"shockwave": [Benefit.COMBAT, Support.REQUIRES_NEW_ACTION],

	# The Rocket Launcher is an active dome battle ability that fires rockets.
	# Unsupported: the teacher does not emit the second ability action.
	&"rocketlauncher": [Benefit.COMBAT, Support.REQUIRES_NEW_ACTION],
}


static func base_id(runtime_id: StringName) -> StringName:
	var text := String(runtime_id)
	var separator := text.find(".")
	if separator < 0:
		return runtime_id
	return StringName(text.substr(separator + 1))


static func benefit_mask(runtime_id: StringName) -> int:
	var entry: Array = _ENTRIES.get(base_id(runtime_id), _UNKNOWN_ENTRY)
	return int(entry[0])


static func support(runtime_id: StringName) -> Support:
	var entry: Array = _ENTRIES.get(base_id(runtime_id), _UNKNOWN_ENTRY)
	return entry[1] as Support


static func has_benefit(runtime_id: StringName, benefit: Benefit) -> bool:
	return benefit_mask(runtime_id) & benefit != 0


static func is_supported(runtime_id: StringName) -> bool:
	return support(runtime_id) == Support.SUPPORTED


static func is_shred(runtime_id: StringName) -> bool:
	return base_id(runtime_id) == SHRED_ID
