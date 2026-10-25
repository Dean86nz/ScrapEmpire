class_name TutorialController
extends Node
## Fünf Tutorial-Schritte aus data/tutorial.json. Beobachtet die Welt, zeigt den aktuellen
## Schritt im HUD, belohnt mit Konfetti/Spruch/Bolts und öffnet am Ende das Tor nach Osten.

signal step_changed(index: int, text: String)
signal finished

var steps: Array = []
var index := 0
var done := false
var _progress := 0
var _world: SimWorld
var _player: Player
var _last_pos := Vector2.ZERO
var _moved := 0.0


static func load_steps(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("tutorial.json nicht lesbar: " + path)
		return []
	return parsed.get("steps", [])


func bind(world: SimWorld, player: Player) -> void:
	_world = world
	_player = player
	steps = load_steps("res://data/tutorial.json")
	index = int(world.flags.get("tutorial_step", 0))
	done = bool(world.flags.get("tutorial_done", false)) or index >= steps.size()
	_last_pos = player.global_position
	world.item_collected.connect(_on_item_collected)
	world.item_sold.connect(_on_item_sold)
	world.wreck_destroyed.connect(_on_wreck_destroyed)
	world.tech.research_started.connect(_on_research_started)
	_emit_current()


func _process(delta: float) -> void:
	if done or _player == null:
		return
	if _current().get("trigger", "") == "moved":
		_moved += (_player.global_position - _last_pos).length()
		_progress = int(_moved)
		if _progress >= int(_current().get("amount", 1)):
			_complete()
		elif int(_moved) % 40 == 0:
			_emit_current()
	_last_pos = _player.global_position


func _current() -> Dictionary:
	return steps[index] if index < steps.size() else {}


func progress_text() -> String:
	if done:
		return ""
	var s := _current()
	var amount := int(s.get("amount", 1))
	var text := tr(str(s.get("text_key", "")))
	if amount > 1 and str(s.get("trigger", "")) != "moved":
		text += " (%d/%d)" % [mini(_progress, amount), amount]
	return "%d/%d  %s" % [index + 1, steps.size(), text]


func _emit_current() -> void:
	step_changed.emit(index, progress_text())


func _bump(trigger: String, n: int = 1, match_key: String = "", match_value: String = "") -> void:
	if done:
		return
	var s := _current()
	if str(s.get("trigger", "")) != trigger:
		return
	if match_key != "" and str(s.get(match_key, "")) != match_value:
		return
	_progress += n
	if _progress >= int(s.get("amount", 1)):
		_complete()
	else:
		_emit_current()


func _complete() -> void:
	var s := _current()
	var bonus := int(s.get("reward_bolts", 0))
	if bonus > 0:
		_world.bolts += bonus
		_world.bolts_changed.emit(_world.bolts)
	_player.celebrate()
	EventBus.quip.emit(str(s.get("done_key", "")))
	index += 1
	_progress = 0
	_world.flags["tutorial_step"] = index
	if index >= steps.size():
		done = true
		_world.flags["tutorial_done"] = true
		_world.flags["gate_open"] = true
		finished.emit()
		step_changed.emit(index, "")
	else:
		_emit_current()


func _on_item_collected(item_id: String, _from: Vector2i) -> void:
	_bump("collect", 1, "item", item_id)


func _on_item_sold(_item: String, _value: int, _pos: Vector2i) -> void:
	_bump("sold")


func _on_wreck_destroyed(_id: int) -> void:
	_bump("wreck_destroyed")


func _on_research_started(id: String, _ticks: int) -> void:
	_bump("research_started", 1, "tech", id)
