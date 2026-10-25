extends SceneTree
## Entwicklerwerkzeug: startet die Hauptszene, simuliert Eingaben und speichert einen Screenshot.
## Nicht headless (Fenster öffnet kurz).
##   Godot_v4.7.2-stable_win64_console.exe --path . -s tests/screenshot.gd -- <ausgabe.png> [frames] [halten] [sequenz] [cheat]
##   halten:  Aktionen, die ab Frame 2 bis zum Ende gehalten werden, z. B. "move_left,tool_primary"
##   sequenz: "frame:aktion" getrennt durch Komma; Taste wird bei frame gedrückt und 2 Frames später gelöst
##   cheat:   "scrap=60" gibt Rusty bei Frame 3 Material

var _frames := 0
var _target_frames := 45
var _out_path := "user://screenshot.png"
var _hold_actions: PackedStringArray = []
var _sequence: Array = []  # [{frame, action, pressed}]
var _cheat := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_out_path = args[0]
	if args.size() >= 2:
		_target_frames = int(args[1])
	if args.size() >= 3 and args[2] != "-":
		_hold_actions = args[2].split(",")
	if args.size() >= 4 and args[3] != "-":
		# "frame:aktion[:dauer]" – Taste wird bei frame gedrückt und nach dauer Frames (Standard 2) gelöst.
		for entry in args[3].split(","):
			var parts := entry.split(":")
			var f := int(parts[0])
			var hold := int(parts[2]) if parts.size() >= 3 else 2
			_sequence.append({"frame": f, "action": parts[1], "pressed": true})
			_sequence.append({"frame": f + hold, "action": parts[1], "pressed": false})
	if args.size() >= 5:
		_cheat = args[4]
	change_scene_to_file("res://src/world/main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		for a in _hold_actions:
			_send_action(a, true)
	if _frames == 3 and _cheat != "":
		# Autoloads sind beim Kompilieren eines -s-Skripts nicht bekannt, daher dynamisch.
		var clock: Node = root.get_node("/root/SimClock")
		for pair in _cheat.split(","):
			var kv := pair.split("=")
			clock.world.player.inventory.add(kv[0], int(kv[1]))
	for step in _sequence:
		if step["frame"] == _frames:
			_send_action(step["action"], step["pressed"])
	if _frames == _target_frames:
		for a in _hold_actions:
			_send_action(a, false)
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(_out_path)
		print("screenshot %s -> %s (%d)" % [_out_path, "ok" if err == OK else "FEHLER", err])
		quit(0 if err == OK else 1)
	return false


## Schickt ein echtes InputEventAction durch die Eingabekette, damit auch
## _unhandled_input-Handler (z. B. Menüs) reagieren, nicht nur Input.is_action_pressed.
func _send_action(action: String, pressed: bool) -> void:
	# Sonderfall Maus: "lmb"/"rmb" klicken in der Bildschirmmitte rechts neben Rusty.
	if action == "lmb" or action == "rmb":
		var pos := Vector2(1150, 560)
		if pressed:
			Input.warp_mouse(pos)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT if action == "lmb" else MOUSE_BUTTON_RIGHT
		mb.pressed = pressed
		mb.position = pos
		mb.global_position = pos
		Input.parse_input_event(mb)
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
