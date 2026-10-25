extends Node2D
## Hauptszene: lädt die Karte in die Simulation, baut Boden und Wände,
## verbindet Darstellung, HUD, Baumenü und Bau-Cursor mit der SimWorld.

const MAP_PATH := "res://data/maps/tutorial.json"

@onready var _player: Player = $Player
@onready var _world_view: WorldView = $WorldView
@onready var _hud: CanvasLayer = $Hud
@onready var _build_menu: CanvasLayer = $BuildMenu
@onready var _cursor: BuildCursor = $BuildCursor

var _world: SimWorld
var _first_collected: Dictionary = {}


func _ready() -> void:
	_world = SimWorld.new()
	_world.defs = DataRegistry.building_defs
	_world.item_values = DataRegistry.item_values()
	var start := MapLoader.load_into(_world, MAP_PATH)
	SimClock.reset_world(_world)

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
	_player.hotbar_selected.connect(_hud.set_selected_slot)

	_build_menu.build_selected.connect(_on_build_selected)
	_build_menu.demolish_selected.connect(_cursor.start_demolish)
	_cursor.menu_requested.connect(_build_menu.open)

	_world.inventory_full.connect(func() -> void: Quips.say("inventory_full"))
	_world.wreck_destroyed.connect(func(_id: int) -> void: Quips.say("wreck_destroyed"))
	_world.item_collected.connect(_on_item_collected)
	_world.place_failed.connect(func(reason: String) -> void: Quips.say("fail_" + reason, true))
	get_tree().create_timer(1.0).timeout.connect(func() -> void: Quips.say("start"))


func _process(_delta: float) -> void:
	_hud.set_hint(_current_hint())


func _unhandled_input(event: InputEvent) -> void:
	if InputRouter.context == InputRouter.Context.GAME and event.is_action_pressed("build_menu"):
		_build_menu.open()
		get_viewport().set_input_as_handled()


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
