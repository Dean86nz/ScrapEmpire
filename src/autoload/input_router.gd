extends Node
## Erkennt das zuletzt benutzte Eingabegerät (Gamepad vs. Tastatur/Maus) für
## Button-Icons und Zielmodus, und hält den Eingabekontext (Spiel/Bau/Menü).

enum Context { GAME, BUILD, MENU }

## Jeder Wechsel (Menü, Pause, Jubel, Karte, Intro, Abspann, Boss-Moment) setzt Saugen und
## Hammer zurück und liest sie neu vom Controller (MS48: zentral statt je Stelle).
var context: Context = Context.GAME:
	set(value):
		if value != context:
			context = value
			reset_tools()
var is_gamepad := true

const TOOL_AXES := {"tool_primary": JOY_AXIS_TRIGGER_RIGHT, "tool_secondary": JOY_AXIS_TRIGGER_LEFT}


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


## Saugen/Hammer neu einlesen (Pause, Fortsetzen, Fokuswechsel): Ein verpasstes Loslassen darf
## Rusty nicht dauerhaft saugen lassen. Gedrückt bleibt nur, was der Controller jetzt meldet.
func reset_tools() -> void:
	for action: String in TOOL_AXES:
		Input.action_release(action)
		for dev in Input.get_connected_joypads():
			var v := Input.get_joy_axis(dev, TOOL_AXES[action])
			if v >= InputMapSetup.TRIGGER_DEADZONE:
				Input.action_press(action, v)
	if SimClock.world != null:
		SimClock.world.player.suck_held = false
		SimClock.world.player.hammer_pressed = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		reset_tools()


func _set_gamepad(value: bool) -> void:
	is_gamepad = value
	EventBus.device_changed.emit(value)
