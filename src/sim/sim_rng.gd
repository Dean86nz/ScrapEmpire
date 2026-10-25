class_name SimRng
extends RefCounted
## Seeded Zufall für die Simulation. Zustand ist speicherbar.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func get_state() -> int:
	return _rng.state


func set_state(value: int) -> void:
	_rng.state = value
