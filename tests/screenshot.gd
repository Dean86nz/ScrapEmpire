extends SceneTree
## Entwicklerwerkzeug: startet die Hauptszene, hält optional eine Aktion gedrückt,
## wartet einige Frames und speichert einen Screenshot. Nicht headless (Fenster öffnet kurz).
##   Godot_v4.7.2-stable_win64_console.exe --path . -s tests/screenshot.gd -- <ausgabe.png> [frames] [aktion]

var _frames := 0
var _target_frames := 45
var _out_path := "user://screenshot.png"
var _hold_action := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_out_path = args[0]
	if args.size() >= 2:
		_target_frames = int(args[1])
	if args.size() >= 3:
		_hold_action = args[2]
	change_scene_to_file("res://src/world/main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _hold_action != "" and _frames == 2:
		for a in _hold_action.split(","):
			Input.action_press(a)
	if _frames == _target_frames:
		if _hold_action != "":
			for a in _hold_action.split(","):
				Input.action_release(a)
		var img := root.get_viewport().get_texture().get_image()
		var err := img.save_png(_out_path)
		print("screenshot %s -> %s (%d)" % [_out_path, "ok" if err == OK else "FEHLER", err])
		quit(0 if err == OK else 1)
	return false
