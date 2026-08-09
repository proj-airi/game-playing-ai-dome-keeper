extends Node

signal completed(value: int)

var value := 0

func increment(amount: int) -> int:
	value += amount
	return value

func set_later(next_value: int) -> void:
	get_tree().create_timer(0.05).timeout.connect(func():
		value = next_value
		completed.emit(value)
	)
