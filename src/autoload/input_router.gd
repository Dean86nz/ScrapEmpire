extends Node
## Erkennt das zuletzt benutzte Eingabegerät (Gamepad vs. Tastatur/Maus) für
## Button-Icons und Zielmodus, und hält den Eingabekontext (Spiel/Bau/Menü).

enum Context { GAME, BUILD, MENU }

var context: Context = Context.GAME
var is_gamepad := true


func _input(event: InputEvent) -> void:
	var from_gamepad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var from_desktop := event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion
	if from_gamepad and not is_gamepad:
		_set_gamepad(true)
	elif from_desktop and is_gamepad:
		# Winzige Mausbewegungen (Tisch wackelt) sollen den Modus nicht umschalten.
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() < 2.0:
			return
		_set_gamepad(false)
	if event.is_action_pressed("toggle_fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _set_gamepad(value: bool) -> void:
	is_gamepad = value
	EventBus.device_changed.emit(value)
