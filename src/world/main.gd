extends Node2D
## Hauptszene: lädt die Karte in die Simulation, baut Boden und Wände,
## verbindet Darstellung, HUD, Baumenü und Bau-Cursor mit der SimWorld.

const MAP_PATH := "res://data/maps/tutorial.json"
const MAP_NAME := "tutorial"
const AUTOSAVE_SECONDS := 60.0

@onready var _player: Player = $Player
@onready var _world_view: WorldView = $WorldView
@onready var _hud: CanvasLayer = $Hud
@onready var _build_menu: CanvasLayer = $BuildMenu
@onready var _progress_menu: CanvasLayer = $ProgressMenu
@onready var _cursor: BuildCursor = $BuildCursor
@onready var _pause_menu: CanvasLayer = $PauseMenu

var _world: SimWorld
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
	_world.setup_progression_data(DataRegistry.tech_defs(), DataRegistry.skill_data())
	var start_px: Vector2
	var save_data := SaveManager.read()
	if not save_data.is_empty():
		MapLoader.apply(_world, MapLoader.read(MAP_PATH), false)
		start_px = SaveCodec.decode(save_data, _world)
		_loaded_from_save = true
	else:
		start_px = Vector2(MapLoader.load_into(_world, MAP_PATH))
	SimClock.reset_world(_world)
	var start := Vector2i(start_px)

	var size := _world.size_px()
	_build_ground(size.x, size.y)
	_build_walls(size.x, size.y)

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
	_pause_menu.opened.connect(save_game)
	_pause_menu.save_quit_requested.connect(_on_save_quit)
	_pause_menu.new_game_requested.connect(_on_new_game)
	_pause_menu.language_changed.connect(_on_language_changed)
	get_tree().auto_accept_quit = false
	_world.tech_unlocked.connect(func(_id: String) -> void: Quips.say("tech_done", true))
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
		_build_menu.open()
		get_viewport().set_input_as_handled()
	elif InputRouter.context == InputRouter.Context.GAME and event.is_action_pressed("tech_tree"):
		_progress_menu.open()
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
			_world.place_free("extractor", Vector2i(14, 18), 0)
			for x in [15, 16]:
				_world.place_free("conveyor", Vector2i(x, 18), 0)
			_world.place_free("furnace", Vector2i(17, 18), 0)
			for x in [19, 20]:
				_world.place_free("conveyor", Vector2i(x, 18), 0)
			_world.place_free("sell_terminal", Vector2i(21, 18), 0)
			EventBus.quip.emit("DEBUG_CHAIN")
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
			return tr(("HINT_DEMOLISH" if _cursor.mode == BuildCursor.Mode.DEMOLISH else "HINT_PLACE") + kb)
		InputRouter.Context.MENU:
			return tr("HINT_MENU" + kb)
	var b := _player.nearby_building()
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
