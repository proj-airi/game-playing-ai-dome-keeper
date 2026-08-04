extends "res://game/GameWorld.gd"


func prepareLevelStart(levelStartData: LevelStartData) -> void:
	super(levelStartData)
	if Level.levelSeed >= 0:
		seed(Level.levelSeed)


func getNextRandomWorldId() -> String:
	var worlds := ["world1", "world2", "world3", "world4", "world5", "world7"]
	var pick: int = abs(Level.levelSeed) if Level.levelSeed >= 0 else 0
	var worldId: String = "world1" if worlds.is_empty() else worlds[pick % worlds.size()]
	GameWorld.lastWorldIds.append(worldId)
	return worldId
