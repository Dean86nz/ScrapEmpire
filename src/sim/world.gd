class_name SimWorld
extends RefCounted
## Wurzel der Simulation. Kennt keine Nodes, keine Sekunden, keine Floats.
## Befehle (Dictionaries) werden gesammelt und zu Beginn des nächsten Ticks angewandt.

var tick_count: int = 0
var _commands: Array[Dictionary] = []


func queue_command(cmd: Dictionary) -> void:
	_commands.append(cmd)


func pending_commands() -> int:
	return _commands.size()


func tick() -> void:
	for cmd in _commands:
		_apply(cmd)
	_commands.clear()
	tick_count += 1


func _apply(_cmd: Dictionary) -> void:
	pass  # Befehlstypen kommen ab MS1 (sammeln, bauen, einlegen)
