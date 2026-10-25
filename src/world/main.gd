extends Node2D
## Hauptszene: lädt die Karte in die Simulation, baut Boden und Wände,
## verbindet Darstellung und HUD mit der SimWorld.

const MAP_PATH := "res://data/maps/tutorial.json"

@onready var _player: Player = $Player
@onready var _world_view: WorldView = $WorldView
@onready var _hud: CanvasLayer = $Hud

var _first_collected: Dictionary = {}


func _ready() -> void:
	var world := SimWorld.new()
	var start := MapLoader.load_into(world, MAP_PATH)
	SimClock.reset_world(world)

	var size := world.size_px()
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

	_world_view.bind(world, _player)
	_hud.bind(world)

	world.inventory_full.connect(func() -> void: Quips.say("inventory_full"))
	world.wreck_destroyed.connect(func(_id: int) -> void: Quips.say("wreck_destroyed"))
	world.item_collected.connect(_on_item_collected)
	get_tree().create_timer(1.0).timeout.connect(func() -> void: Quips.say("start"))


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
