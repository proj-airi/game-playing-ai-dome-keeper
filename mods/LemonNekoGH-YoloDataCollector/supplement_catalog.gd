extends RefCounted

# Target-version Supplement policy for Dome Keeper 5.0.5.19.
#
# Only passive supplements compatible with the current controller are listed.

enum Benefit {
	NONE = 0,
	COMBAT = 1 << 0,
	SURVIVAL_REPAIR = 1 << 1,
	MOVEMENT = 1 << 2,
	DRILLING = 1 << 3,
	CARRYING_LOGISTICS = 1 << 4,
}

const SHRED_ID := &"shredgadgettocobalt"

const _ENTRIES := {
	&"domesupplementmeleedamagereduction1": Benefit.COMBAT | Benefit.SURVIVAL_REPAIR,
	&"domesupplementelectrifiedsurface1": Benefit.COMBAT,
	&"domesupplementcombatrepair1": Benefit.SURVIVAL_REPAIR,
	&"domesupplementprojectiledamagereduction1": Benefit.COMBAT | Benefit.SURVIVAL_REPAIR,
	&"domesupplementresurrection1": Benefit.SURVIVAL_REPAIR,
	&"domesupplementscraprepair1": Benefit.SURVIVAL_REPAIR,
	&"furnaceslowdown": Benefit.COMBAT,
	&"stunlaserarea": Benefit.COMBAT,
	&"autocannondoublefirerate": Benefit.COMBAT,
	&"spireprojectileslowdown": Benefit.COMBAT,
	&"chainsawdouble": Benefit.COMBAT,
	&"domearmorpulse": Benefit.COMBAT | Benefit.SURVIVAL_REPAIR,
}


static func base_id(runtime_id: StringName) -> StringName:
	var text := String(runtime_id)
	var separator := text.find(".")
	if separator < 0:
		return runtime_id
	return StringName(text.substr(separator + 1))


static func benefit_mask(runtime_id: StringName) -> int:
	return int(_ENTRIES.get(base_id(runtime_id), Benefit.NONE))


static func is_supported(runtime_id: StringName) -> bool:
	return _ENTRIES.has(base_id(runtime_id))


static func is_shred(runtime_id: StringName) -> bool:
	return base_id(runtime_id) == SHRED_ID
