extends Node2D
## Hauptszene: lädt die Karte in die Simulation, baut Boden und Wände,
## verbindet Darstellung, HUD, Baumenü und Bau-Cursor mit der SimWorld.

const MAP_PATH := "res://data/maps/main.json"
const MAP_NAME := "main"
const AUTOSAVE_SECONDS := 60.0
const LONG_PRESS_SECONDS := 0.45

@onready var _player: Player = $Player
@onready var _world_view: WorldView = $WorldView
@onready var _hud: CanvasLayer = $Hud
@onready var _build_menu: CanvasLayer = $BuildMenu
@onready var _progress_menu: CanvasLayer = $ProgressMenu
@onready var _cursor: BuildCursor = $BuildCursor
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _task_editor: CanvasLayer = $TaskEditor
@onready var _tutorial: TutorialController = $Tutorial
@onready var _end_screen: CanvasLayer = $EndScreen

var _world: SimWorld
var _map_data: Dictionary = {}
var _zone_gates: Dictionary = {}  # "a|b" → Array[Node]
var _nature: NatureView
var _sky: DayLight
var _rain: RainLayer
var _chapter_timer := 0.0
var _build_press_time := -1.0
var _tech_press_time := -1.0
var _pending_task_type := -1
var _helper_flow := 0  # 0 aus, 1 Zone wählen, 2 Lager wählen
var _helper_zone := Vector2i.ZERO
var _first_collected: Dictionary = {}
var _autosave_timer := AUTOSAVE_SECONDS
var _loaded_from_save := false


func _ready() -> void:
	_world = SimWorld.new()
	_world.defs = DataRegistry.building_defs
	_world.item_values = DataRegistry.item_values()
	_world.recipes = DataRegistry.recipes
	_world.progression = DataRegistry.new_progression()
	_world.rare_items = DataRegistry.rare_items()
	_world.helper_cfg = DataRegistry.helper_config()
	_world.setup_progression_data(DataRegistry.tech_defs(), DataRegistry.skill_data())
	var start_px: Vector2
	var save_data := SaveManager.read()
	_map_data = MapLoader.read(MAP_PATH)
	if not save_data.is_empty():
		MapLoader.apply(_world, _map_data, false)
		start_px = SaveCodec.decode(save_data, _world)
		MapLoader.fill_missing_zones(_world, _map_data)
		_loaded_from_save = true
	else:
		start_px = Vector2(MapLoader.apply(_world, _map_data))
	SimClock.reset_world(_world)
	var start := Vector2i(start_px)

	var size := _world.size_px()
	_build_ground(size.x, size.y)
	_build_walls(size.x, size.y)
	_build_zone_fences()

	_player.position = Vector2(start)
	var cam: Camera2D = _player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = size.x
	cam.limit_bottom = size.y
	cam.zoom = Vector2.ONE * GameConfig.CAMERA_ZOOM
	cam.reset_smoothing()

	_world_view.bind(_world, _player)
	_hud.bind(_world)
	_progress_menu.bind(_world)
	_player.hotbar_selected.connect(_hud.set_selected_slot)
	if _loaded_from_save:
		_player.selected_slot = int(save_data.get("player", {}).get("selected_slot", 0))
		_hud.set_selected_slot(_player.selected_slot)
		_first_collected = {"scrap": true, "copper": true, "plastic": true, "chrome": true}
	_progress_menu.helper_purchase_requested.connect(_start_helper_flow)
	_world.helper_failed.connect(func(reason: String) -> void: Quips.say("helper_fail_" + reason, true))
	_world.helper_added.connect(func(_h: Helper) -> void: _player.celebrate())
	_task_editor.bind(_world)
	_task_editor.target_requested.connect(_on_task_target_requested)
	_cursor.target_chosen.connect(_on_target_chosen)
	_world.tasks.waiting.connect(func(reason: String) -> void: Quips.say("task_wait_" + reason, true))
	_world.tasks.changed.connect(func() -> void: _hud.refresh_tasks(_world.tasks))
	_world.tasks.state_changed.connect(func(_a: bool) -> void: _hud.refresh_tasks(_world.tasks))
	_world.tasks.step_started.connect(func(_i: int) -> void: _hud.refresh_tasks(_world.tasks))
	_hud.refresh_tasks(_world.tasks)
	_hud.bind_minimap(_player)
	_progress_menu.bind_player(_player)
	_world.zones.stage_changed.connect(_on_zone_stage_changed)
	_world.zones.refresh(_world.nodes)
	_tutorial.bind(_world, _player)
	_tutorial.step_changed.connect(func(_i: int, text: String) -> void: _hud.set_tutorial(text))
	_tutorial.finished.connect(_refresh_chapter_hud)
	_world.zone_unlocked.connect(_on_zone_unlocked)
	_setup_nature()
	_refresh_chapter_hud()
	_open_unlocked_gates()
	_pause_menu.opened.connect(save_game)
	_pause_menu.save_quit_requested.connect(_on_save_quit)
	_pause_menu.new_game_requested.connect(_on_new_game)
	_pause_menu.language_changed.connect(_on_language_changed)
	get_tree().auto_accept_quit = false
	_world.tech_unlocked.connect(func(_id: String) -> void: Quips.say("tech_done", true))
	_world.tech_unlocked.connect(_check_mvp_done)
	_world.research_failed.connect(func(reason: String) -> void: Quips.say("research_fail_" + reason, true))
	_world.skill_bought.connect(func(_id: String, _lvl: int) -> void: Quips.say("skill_bought"))

	_build_menu.build_selected.connect(_on_build_selected)
	_build_menu.demolish_selected.connect(_cursor.start_demolish)
	_cursor.menu_requested.connect(_build_menu.open)

	_world.inventory_full.connect(func() -> void: Quips.say("inventory_full"))
	_world.wreck_destroyed.connect(func(_id: int) -> void: Quips.say("wreck_destroyed"))
	_world.item_collected.connect(_on_item_collected)
	_world.place_failed.connect(func(reason: String) -> void: Quips.say("fail_" + reason, true))
	_world.deposit_rejected.connect(func(_b: Building, _item: String) -> void: Quips.say("deposit_rejected", true))
	_world.building_placed.connect(_on_building_placed)
	_world.too_hard.connect(func(_n: ResourceNode, tool: String) -> void: Quips.say("too_hard_" + tool, true))
	_world.progression.level_up.connect(_on_level_up)
	if not _loaded_from_save:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: Quips.say("start"))
	else:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: Quips.say("loaded", true))


func _process(delta: float) -> void:
	_hud.set_hint(_current_hint())
	_chapter_timer -= delta
	if _chapter_timer <= 0.0:
		_chapter_timer = 1.0
		_refresh_chapter_hud()
	# Kurz/Lang-Erkennung per Zustandsabfrage (funktioniert auch mit simulierten Eingaben).
	if _build_press_time >= 0.0:
		_build_press_time += delta
		if not Input.is_action_pressed("build_menu"):
			var held := _build_press_time
			_build_press_time = -1.0
			if InputRouter.context == InputRouter.Context.GAME and held < LONG_PRESS_SECONDS:
				_build_menu.open()
		elif _build_press_time >= LONG_PRESS_SECONDS and InputRouter.context == InputRouter.Context.GAME:
			_build_press_time = -1.0
			_open_task_editor()
	if _tech_press_time >= 0.0:
		_tech_press_time += delta
		if not Input.is_action_pressed("tech_tree"):
			var held_t := _tech_press_time
			_tech_press_time = -1.0
			if InputRouter.context == InputRouter.Context.GAME and held_t < LONG_PRESS_SECONDS:
				_progress_menu.open()
		elif _tech_press_time >= LONG_PRESS_SECONDS:
			_tech_press_time = -1.0
			_hud.toggle_minimap()
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


## Speichert den kompletten Stand (Autosave, Pause, Beenden, F5).
func save_game() -> bool:
	var data := SaveCodec.encode(_world, MAP_NAME, _player.global_position, _player.selected_slot)
	var ok := SaveManager.write(data)
	if ok:
		EventBus.quip.emit("HUD_SAVED")
	return ok


func _on_save_quit() -> void:
	save_game()
	get_tree().quit()


func _on_new_game() -> void:
	SaveManager.delete_all()
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME
	get_tree().reload_current_scene()


func _on_language_changed(locale: String) -> void:
	save_game()
	SaveManager.save_settings({"locale": locale})
	TranslationServer.set_locale(locale)
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if InputRouter.context == InputRouter.Context.GAME and event.is_action_pressed("build_menu"):
		# Y kurz: Baumenü (beim Loslassen, per Abfrage in _process); Y lang: Aufgaben-Editor.
		_build_press_time = 0.0
		get_viewport().set_input_as_handled()
	elif InputRouter.context == InputRouter.Context.GAME and event.is_action_pressed("task_menu"):
		_open_task_editor()
		get_viewport().set_input_as_handled()
	elif InputRouter.context == InputRouter.Context.GAME and event.is_action_pressed("tech_tree"):
		# Select kurz: Fortschritt; Select lang: Minimap ein/aus.
		_tech_press_time = 0.0
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("minimap_toggle"):
		_hud.toggle_minimap()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_perf"):
		debug_scenario("perf")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_chain"):
		debug_scenario("chain")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_cheat"):
		# Dev-Cheat: Bolts, Material, XP und Chrom zum Testen der Menüs.
		_world.bolts += 500
		_world.bolts_changed.emit(_world.bolts)
		_world.player.inventory.add("scrap", 20)
		_world.player.inventory.add("copper", 10)
		_world.player.inventory.add("chrome", 5)
		_world.progression.add_xp(100)
		EventBus.quip.emit("DEBUG_CHEAT")
		get_viewport().set_input_as_handled()


## Dev-Szenarien (kostenlos platziert): "chain" = Haufen → Saugstation → Band → Ofen → Band → Terminal
## unterhalb des Starts; "perf" = ~480 Bänder in Schleifen mit ~1.900 Items für den FPS-Test.
func debug_scenario(name: String) -> void:
	match name:
		"chain":
			# Kette 2 Kacheln unter Rusty: Haufen, Saugstation, 2 Bänder, Ofen, 2 Bänder, Terminal (10 Kacheln breit).
			var o := Vector2i.ZERO
			var free := false
			for dy in [3, 4, 5, 2, 6, 7]:
				o = _world.player_tile() + Vector2i(-4, dy)
				o.x = clampi(o.x, 0, _world.width_tiles - 11)
				o.y = clampi(o.y, 0, _world.height_tiles - 2)
				var needed: Array = [[o, Vector2i(1, 1)], [o + Vector2i(1, 0), Vector2i(3, 1)], [o + Vector2i(4, 0), Vector2i(2, 2)], [o + Vector2i(6, 0), Vector2i(2, 1)], [o + Vector2i(8, 0), Vector2i(2, 2)]]
				free = true
				for entry in needed:
					if not _world.grid.can_place(entry[0], entry[1], _world._tile_blocked):
						free = false
				if free:
					break
			if not free:
				EventBus.quip.emit("DEBUG_CHAIN_FAIL")
				return
			_world.add_object("scrap_pile", o, 10)
			_world.place_free("extractor", o + Vector2i(1, 0), 0)
			_world.place_free("conveyor", o + Vector2i(2, 0), 0)
			_world.place_free("conveyor", o + Vector2i(3, 0), 0)
			_world.place_free("furnace", o + Vector2i(4, 0), 0)
			_world.place_free("conveyor", o + Vector2i(6, 0), 0)
			_world.place_free("conveyor", o + Vector2i(7, 0), 0)
			_world.place_free("sell_terminal", o + Vector2i(8, 0), 0)
			EventBus.quip.emit("DEBUG_CHAIN")
		"endgame":
			_world.bolts += 100000
			_world.bolts_changed.emit(_world.bolts)
			_world.player.inventory.add("chrome", 50)
			for d: Dictionary in _world.tech.defs:
				_world.tech.unlocked[str(d["id"])] = true
				_world._apply_tech_effects(str(d["id"]))
			_world.recompute_modifiers()
			_check_mvp_done("")
		"helpers":
			_world.unlocked_features["helpers"] = true
			_world.unlocked_features["helper_tools"] = true
			_world.bolts += 3000
			_world.player.inventory.add("chrome", 20)
			var depot := _world.player_tile() + Vector2i(2, 2)
			_world.place_free("chest", depot, 0)
			_world.queue_command({"type": "buy_helper", "zone": _world.player_tile() + Vector2i(-4, -3), "depot": depot})
			_world.queue_command({"type": "buy_helper", "zone": _world.player_tile() + Vector2i(5, 3), "depot": depot})
		"auto":
			# Autopilot-Demo: Autopilot freischalten, Haufen bei (16,42) sammeln, zur Kiste bringen.
			_world.unlocked_features["autopilot"] = true
			var chest_tile := _world.player_tile() + Vector2i(2, 2)
			_world.place_free("chest", chest_tile, 0)
			_world.tasks.clear()
			_world.tasks.add_step(TaskList.Type.COLLECT, Vector2i(16, 42))
			_world.tasks.add_step(TaskList.Type.DEPOSIT, chest_tile)
			_world.tasks.start(_world.player)
			EventBus.quip.emit("QUIP_AUTOPILOT_START_1")
		"perf":
			var kinds := ["scrap", "copper", "plastic"]
			var n := 0
			for k in 6:
				var x0 := 2 + 2 * k
				var y0 := 2 + 2 * k
				var x1 := 37 - 2 * k
				var y1 := 27 - 2 * k
				var ring: Array = []
				for x in range(x0, x1):
					ring.append([Vector2i(x, y0), 0])
				for y in range(y0, y1):
					ring.append([Vector2i(x1, y), 1])
				for x in range(x1, x0, -1):
					ring.append([Vector2i(x, y1), 2])
				for y in range(y1, y0, -1):
					ring.append([Vector2i(x0, y), 3])
				for entry in ring:
					var c := _world.place_free("conveyor", entry[0], entry[1])
					if c == null:
						continue
					for i in 4:
						(c as Conveyor).try_insert(kinds[(n + i) % 3], i * Conveyor.SPACING)
						n += 1
			EventBus.quip.emit("DEBUG_PERF")


## Alle Techknoten erforscht → MVP-Ende-Bildschirm (einmalig).
func _check_mvp_done(_id: String) -> void:
	if bool(_world.flags.get("mvp_done", false)):
		return
	if _world.tech.available().is_empty() and _world.tech.unlocked.size() >= _world.tech.defs.size():
		_world.flags["mvp_done"] = true
		save_game()
		_end_screen.show_stats(_world)


func _on_zone_stage_changed(zone_id: String, stage: int) -> void:
	if stage >= 2:
		_player.celebrate()
	var z := _world.zones.zone_by_id(zone_id)
	EventBus.quip.emit(["ZONE_Q_0", "ZONE_Q_1", "ZONE_Q_2", "ZONE_Q_3"][stage])
	_hud.set_tutorial(_hud.get_node("Tutorial/Label").text)  # unverändert lassen
	print("Zone %s → Stufe %d" % [str(z.get("name", zone_id)), stage])


func _open_task_editor() -> void:
	if not _world.unlocked_features.has("autopilot"):
		Quips.say("autopilot_locked", true)
		return
	_task_editor.open()


func _on_task_target_requested(type: int) -> void:
	_pending_task_type = type
	_cursor.start_target()


func _start_helper_flow() -> void:
	_helper_flow = 1
	EventBus.quip.emit("HELPER_PICK_ZONE")
	_cursor.start_target()


func _on_target_chosen(tile: Vector2i, ok: bool) -> void:
	if _helper_flow > 0:
		if not ok:
			_helper_flow = 0
			return
		if _helper_flow == 1:
			_helper_zone = tile
			_helper_flow = 2
			EventBus.quip.emit("HELPER_PICK_DEPOT")
			_cursor.call_deferred("start_target")
			return
		_helper_flow = 0
		_world.queue_command({"type": "buy_helper", "zone": _helper_zone, "depot": tile})
		return
	if _pending_task_type < 0:
		return
	var t := _pending_task_type
	_pending_task_type = -1
	_task_editor.on_target_result(t, tile, ok)


## Zonen-Heilung (Phase 2): Dekor und Tiere je Stufe, Tageslicht, Regen.
func _setup_nature() -> void:
	var cfg := NaturePlanner.load_config()
	_nature = NatureView.new()
	_nature.name = "Nature"
	add_child(_nature)
	_nature.bind(_world, _player, cfg)
	_nature.critters_appeared.connect(func(_id: String) -> void: Quips.say("critter", true))
	_sky = DayLight.new()
	_sky.name = "Sky"
	_sky.setup(cfg)
	add_child(_sky)
	_rain = RainLayer.new()
	_rain.name = "Rain"
	add_child(_rain)
	_sky.rain_started.connect(func() -> void:
		_rain.set_raining(true)
		Quips.say("rain", true))
	_sky.rain_stopped.connect(func() -> void: _rain.set_raining(false))


## Kapitel-Anzeige oben: Tutorial-Schritt oder Zonenziel.
func _refresh_chapter_hud() -> void:
	if not _tutorial.done:
		_hud.set_tutorial(_tutorial.progress_text())
		return
	var cur := _world.zones.current_chapter_zone()
	if cur == "":
		_hud.set_tutorial("")
		return
	var z := _world.zones.zone_by_id(cur)
	var pct := int(round(_world.zones.cleanliness(cur, _world.nodes) * 100.0))
	var idx := _world.zones.chapter_index(cur) + 1
	var next := _world.zones.next_chapter_zone()
	var text := tr("CH_HUD") % [idx, str(z.get("name", cur)), pct]
	if next != "":
		text += "  ·  " + tr("CH_HUD_GATE") % int(round(_world.zones.unlock_cleanliness * 100.0))
	else:
		text += "  ·  " + tr("CH_HUD_LAST")
	_hud.set_tutorial(text)


func _on_zone_unlocked(zone_id: String) -> void:
	_open_unlocked_gates()
	_player.celebrate()
	var z := _world.zones.zone_by_id(zone_id)
	EventBus.quip.emit("ZONE_UNLOCKED")
	_hud.set_tutorial(tr("CH_UNLOCKED") % str(z.get("name", zone_id)))
	_chapter_timer = 4.0


## Zäune aus Schrottbergen an allen Zonengrenzen; Tore zwischen Nachbarzonen öffnen sich mit dem Kapitel.
func _build_zone_fences() -> void:
	var fence_tex := load("res://assets/sprites/tiles/fence.svg")
	var gate_tex := load("res://assets/sprites/tiles/gate.svg")
	var zones := _world.zones.zones
	var fence_tiles: Dictionary = {}
	var gate_tiles: Dictionary = {}  # tile → pair key
	for z in zones:
		var r: Rect2i = z["rect"]
		if r.end.x < _world.width_tiles:
			for y in range(r.position.y, r.end.y):
				fence_tiles[Vector2i(r.end.x, y)] = true
		if r.end.y < _world.height_tiles:
			for x in range(r.position.x, r.end.x + 1):
				fence_tiles[Vector2i(x, r.end.y)] = true
	# Tore: Mitte jeder gemeinsamen Kante zweier Nachbarzonen, 6 Kacheln breit
	for i in zones.size():
		for j in zones.size():
			if j <= i:
				continue
			var a: Rect2i = zones[i]["rect"]
			var b: Rect2i = zones[j]["rect"]
			var key := "%s|%s" % [zones[i]["id"], zones[j]["id"]]
			if a.end.x == b.position.x and a.position.y == b.position.y:      # b rechts von a
				var cy := a.position.y + a.size.y / 2
				for y in range(cy - 3, cy + 3):
					gate_tiles[Vector2i(a.end.x, y)] = key
			elif b.end.x == a.position.x and a.position.y == b.position.y:   # b links von a
				var cy := a.position.y + a.size.y / 2
				for y in range(cy - 3, cy + 3):
					gate_tiles[Vector2i(b.end.x, y)] = key
			elif a.end.y == b.position.y and a.position.x == b.position.x:   # b unter a
				var cx := a.position.x + a.size.x / 2
				for x in range(cx - 3, cx + 3):
					gate_tiles[Vector2i(x, a.end.y)] = key
			elif b.end.y == a.position.y and a.position.x == b.position.x:   # b über a
				var cx := a.position.x + a.size.x / 2
				for x in range(cx - 3, cx + 3):
					gate_tiles[Vector2i(x, b.end.y)] = key
	for t in fence_tiles.keys():
		if t.x >= _world.width_tiles or t.y >= _world.height_tiles:
			continue
		var is_gate := gate_tiles.has(t)
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 64)
		shape.shape = rect
		body.add_child(shape)
		body.position = Vector2(t * 64) + Vector2(32, 32)
		var sprite := Sprite2D.new()
		sprite.texture = gate_tex if is_gate else fence_tex
		sprite.z_index = 3
		body.add_child(sprite)
		add_child(body)
		_world.blocked_tiles[t] = true
		if is_gate:
			var key: String = gate_tiles[t]
			if not _zone_gates.has(key):
				_zone_gates[key] = []
			_zone_gates[key].append(body)


## Entfernt alle Tore zwischen zwei freigeschalteten Zonen.
func _open_unlocked_gates() -> void:
	for key in _zone_gates.keys():
		var parts: PackedStringArray = key.split("|")
		if _world.zones.is_unlocked(parts[0]) and _world.zones.is_unlocked(parts[1]):
			for n in _zone_gates[key]:
				if is_instance_valid(n):
					var t := Vector2i((n.position - Vector2(32, 32)) / 64.0)
					_world.blocked_tiles.erase(t)
					n.queue_free()
			_zone_gates.erase(key)


func _on_level_up(_level: int, _points: int) -> void:
	_player.celebrate()
	Quips.say("level_up", true)


func _on_build_selected(def_id: String) -> void:
	_cursor.start_place(DataRegistry.building_defs[def_id])


## Hinweiszeile je nach Kontext und Eingabegerät (Gamepad-Tasten oder Tastatur/Maus).
func _current_hint() -> String:
	var kb := "" if InputRouter.is_gamepad else "_KB"
	match InputRouter.context:
		InputRouter.Context.BUILD:
			if _cursor.mode == BuildCursor.Mode.TARGET:
				return tr("HINT_TARGET" + kb)
			return tr(("HINT_DEMOLISH" if _cursor.mode == BuildCursor.Mode.DEMOLISH else "HINT_PLACE") + kb)
		InputRouter.Context.MENU:
			return tr("HINT_MENU" + kb)
	var b := _player.nearby_building()
	if b != null and b is Machine:
		# Rezepte direkt an der Maschine zeigen
		var parts: Array[String] = []
		for r in (b as Machine).recipes:
			var ins: Array[String] = []
			for item in r.inputs:
				ins.append("%d %s" % [int(r.inputs[item]), DataRegistry.item_name(str(item))])
			parts.append("%s → %s" % [" + ".join(ins), DataRegistry.item_name(r.output_item)])
		var slot_m: Dictionary = _world.player.inventory.slots[_player.selected_slot]
		var action := (tr("HINT_DEPOSIT_SHORT" + kb) % [slot_m["count"], DataRegistry.item_name(slot_m["item"])]) if slot_m["item"] != "" else tr("HINT_WITHDRAW_SHORT" + kb)
		return "%s: %s   ·   %s" % [tr(b.def.name_key), "  |  ".join(parts), action]
	if b != null:
		var slot: Dictionary = _world.player.inventory.slots[_player.selected_slot]
		if slot["item"] != "":
			return tr("HINT_DEPOSIT" + kb) % [slot["count"], DataRegistry.item_name(slot["item"]), tr(b.def.name_key)]
		if not b.contents().is_empty():
			return tr("HINT_WITHDRAW" + kb) % tr(b.def.name_key)
	return tr("HUD_HINT_GAME" + kb)


var _first_machine := false


func _on_building_placed(b: Building) -> void:
	if b is Machine and not _first_machine:
		_first_machine = true
		Quips.say("first_machine", true)


func _on_item_collected(item_id: String, _from: Vector2i) -> void:
	if not _first_collected.has(item_id):
		_first_collected[item_id] = true
		Quips.say("first_" + item_id)


func _build_ground(px: int, py: int) -> void:
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = load("res://assets/sprites/tiles/ground.svg")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, px, py)
	ground.centered = false
	ground.z_index = -10
	add_child(ground)
	move_child(ground, 0)


func _build_walls(px: int, py: int) -> void:
	var t := GameConfig.TILE_SIZE
	var walls := [
		Rect2(-t, -t, px + 2 * t, t),   # oben
		Rect2(-t, py, px + 2 * t, t),   # unten
		Rect2(-t, 0, t, py),            # links
		Rect2(px, 0, t, py),            # rechts
	]
	for wall: Rect2 in walls:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall.size
		shape.shape = rect
		shape.position = wall.position + wall.size / 2.0
		body.add_child(shape)
		add_child(body)
