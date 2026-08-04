extends Node

@export var level_seed: int


func _enter_tree() -> void:
	call_deferred(&"_apply_global_seed")
	Level.setSeed(level_seed)


func _apply_global_seed() -> void:
	seed(level_seed)
