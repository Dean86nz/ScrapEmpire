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
	if args.size() >= 5 and args[4] != "-":
		_cheat = args[4]
	var scene := "res://src/world/main.tscn"
	if args.size() >= 6:
		scene = args[5]  # z. B. res://src/ui/title/title.tscn
	change_scene_to_file(scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# Sprüche mitschreiben (Debug-Hilfe); Autoloads existieren erst jetzt.
		var bus: Node = root.get_node("/root/EventBus")
		bus.quip.connect(func(key: String) -> void: print("quip@%d: %s" % [_frames, key]))
	if _frames == 2:
		for a in _hold_actions:
			_send_action(a, true)
	if _frames == 3 and _cheat != "":
		# Autoloads sind beim Kompilieren eines -s-Skripts nicht bekannt, daher dynamisch.
		var clock: Node = root.get_node("/root/SimClock")
		for pair in _cheat.split(","):
			var kv := pair.split("=")
			match kv[0]:
				"pos":  # pos=x;y teleportiert Rusty (Weltpixel)
					var xy := kv[1].split(";")
					var player: Node2D = get_nodes_in_group("player")[0]
					player.global_position = Vector2(float(xy[0]), float(xy[1]))
					player.get_node("Camera2D").reset_smoothing()
				"xp":
					clock.world.progression.add_xp(int(kv[1]))
				"tier":
					clock.world.player.suction_tier = int(kv[1])
					clock.world.player.hammer_tier = int(kv[1])
				"scenario":  # scenario=chain | perf | auto | helpers (siehe Main.debug_scenario)
					current_scene.debug_scenario(kv[1])
				"feature":
					clock.world.unlocked_features[kv[1]] = true
				"counter":  # counter=wrecks;5 setzt einen Zähler (Meilensteine, Aufgaben)
					var cv := kv[1].split(";")
					clock.world.quests.counters[cv[0]] = int(cv[1])
				"launch":  # launch=1: letzte Reparatur samt Feier und Abflug-Szene
					var ls: Ship = clock.world.ship()
					ls.stage = ShipSystem.max_stage(clock.world)
					ShipSystem.apply_stage(clock.world, ls)
					clock.world.building_changed.emit(ls)
					current_scene._on_ship_upgraded(ls)
				"ship":  # ship=3 setzt die Schiffsstufe direkt (ohne Feier)
					var sh: Ship = clock.world.ship()
					sh.stage = int(kv[1])
					ShipSystem.apply_stage(clock.world, sh)
					sh.clean_radius = ShipSystem.clean_target(clock.world, sh) - 3
					clock.world.building_changed.emit(sh)
				"clean":  # clean=z01;0.95 entfernt Müll-Objekte der Zone bis zum Reinigungsgrad
					var zc := kv[1].split(";")
					var goal := float(zc[1])
					var zone_id := zc[0]
					var ids: Array = clock.world.nodes.keys()
					for nid in ids:
						if clock.world.zones.cleanliness(zone_id, clock.world.nodes) >= goal:
							break
						var n: ResourceNode = clock.world.nodes[nid]
						if n.is_wreck() and not n.is_resource() and clock.world.zones.zone_id_at(n.tile) == zone_id:
							clock.world._remove_node(n)
					clock.world.zones.refresh(clock.world.nodes)
				"rain":
					current_scene.get_node("Sky").start_rain_now()
				"goto_collectible":  # goto_collectible=gnome stellt Rusty neben das Fundstück
					for c in clock.world.collectibles.values():
						if c.def_id == kv[1]:
							var player: Node2D = get_nodes_in_group("player")[0]
							player.global_position = Vector2(c.center_px()) + Vector2(-90, 0)
							player.get_node("Camera2D").reset_smoothing()
							break
				"unlock":  # unlock=z11 schaltet eine Zone frei (Tor öffnet sich)
					clock.world.zones.unlocked[kv[1]] = true
					clock.world.zone_unlocked.emit(kv[1])
				"tech":  # tech=furnace erforscht sofort
					clock.world.tech.unlocked[kv[1]] = true
					clock.world._apply_tech_effects(kv[1])
				"goto":  # goto=furnace stellt Rusty links neben das erste Gebäude dieser Art
					for b in clock.world.buildings.values():
						if b.def.id == kv[1]:
							var player: Node2D = get_nodes_in_group("player")[0]
							var r: Rect2i = b.rect_px()
							player.global_position = Vector2(r.get_center().x, r.end.y + 44)
							player.get_node("Camera2D").reset_smoothing()
							break
				_:
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
