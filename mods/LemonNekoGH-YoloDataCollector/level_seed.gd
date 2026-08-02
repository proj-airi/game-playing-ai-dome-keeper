extends Node

@export var level_seed: int


func _enter_tree() -> void:
	Level.setSeed(level_seed)
