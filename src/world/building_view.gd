class_name BuildingView
extends Node2D
## Darstellung eines Gebäudes: Sprite (gedreht), Kollision für Rusty, Füllstandslabel,
## bei Maschinen Fortschrittsbalken, Puffer-Icons (links Eingang, rechts Ausgang) und
## Status-Blase („!“ = Ausgang voll, „?“ = nichts zu tun). Schwebender Verkaufs-Text.

const ICON_SIZE := 24.0
const BAR_W := 96.0
const BAR_H := 12.0

var building_id: int = -1
var _building: Building
var _sprite := Sprite2D.new()
var _label := Label.new()
var _body := StaticBody2D.new()
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _status: Label
var _buffer_root := Node2D.new()
var _half_h := 64.0


const TURN_TEXTURE := "res://assets/sprites/buildings/conveyor_turn.svg"


func setup(b: Building) -> void:
	building_id = b.id
	_building = b
	position = Vector2(b.center_px())
	_sprite.texture = load((b as Ship).sprite_path if b is Ship and (b as Ship).sprite_path != "" else b.def.sprite)
	_sprite.rotation = b.rot * PI / 2.0
	add_child(_sprite)

	if b is Conveyor:
		# Bänder liegen unter allem anderen und blockieren Rusty nicht.
		z_index = -2
		_refresh_conveyor(b as Conveyor)
		return

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(b.size() * Building.TILE) - Vector2(8, 8)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)

	_half_h = b.size().y * Building.TILE / 2.0
	_style_label(_label, 22)
	_label.position = Vector2(-80, _half_h - 12)
	_label.size = Vector2(160, 30)
	add_child(_label)

	if b is Machine:
		_setup_machine_ui()
	refresh(b)


func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _setup_machine_ui() -> void:
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.165, 0.165, 0.2, 0.9)
	_bar_bg.position = Vector2(-BAR_W / 2.0, _half_h - 20)
	_bar_bg.size = Vector2(BAR_W, BAR_H)
	add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(1.0, 0.72, 0.2)
	_bar_fill.position = _bar_bg.position + Vector2(2, 2)
	_bar_fill.size = Vector2(0, BAR_H - 4)
	add_child(_bar_fill)
	_label.visible = false

	_status = Label.new()
	_style_label(_status, 40)
	_status.position = Vector2(-20, -_half_h - 52)
	_status.size = Vector2(40, 48)
	_status.visible = false
	add_child(_status)
	add_child(_buffer_root)


func _process(_delta: float) -> void:
	if _building is Machine and _bar_fill != null:
		var m := _building as Machine
		_bar_fill.size.x = (BAR_W - 4) * m.progress_fraction()


func _refresh_conveyor(c: Conveyor) -> void:
	_sprite.rotation = c.rot * PI / 2.0
	if c.shape == Conveyor.Shape.STRAIGHT:
		_sprite.texture = load(c.def.sprite)
		_sprite.flip_v = false
	else:
		_sprite.texture = load(TURN_TEXTURE)
		_sprite.flip_v = c.shape == Conveyor.Shape.TURN_FROM_RIGHT


func refresh(b: Building) -> void:
	_building = b
	if b is Conveyor:
		_refresh_conveyor(b as Conveyor)
		return
	_sprite.rotation = b.rot * PI / 2.0
	var s := b.summary()
	if b is Machine:
		_refresh_machine(s)
		return
	if b is Ship:
		var sh := b as Ship
		if sh.sprite_path != "" and (_sprite.texture == null or _sprite.texture.resource_path != sh.sprite_path):
			_sprite.texture = load(sh.sprite_path)
		_label.text = "%d / %d" % [s["storage"], s["storage_max"]]
		_label.visible = int(s["storage"]) > 0
		return
	if s.has("buffer"):
		_label.text = "%d / %d" % [s["buffer"], s["buffer_max"]]
		_label.visible = s["buffer"] > 0
	elif s.has("total"):
		_label.text = "%d / %d" % [s["total"], s["capacity"]]
		_label.visible = s["total"] > 0
	else:
		_label.visible = false


func _refresh_machine(s: Dictionary) -> void:
	if s["blocked"]:
		_status.text = "!"
		_status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		_status.visible = true
	elif s["idle"] and s["input"].is_empty() and s["output"].is_empty():
		_status.text = "?"
		_status.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
		_status.visible = true
	else:
		_status.visible = false
	for c in _buffer_root.get_children():
		c.queue_free()
	_draw_buffer(s["input"], -_half_h + 16, 1)
	_draw_buffer(s["output"], _half_h - 16, -1)


## Icons mit Zahl als Reihe über dem Gebäude: Eingang ab links nach rechts, Ausgang ab rechts nach links.
func _draw_buffer(buf: Dictionary, x_start: float, direction: int) -> void:
	var i := 0
	for item in buf:
		var icon := Sprite2D.new()
		icon.texture = DataRegistry.item_icon(item)
		icon.position = Vector2(x_start + direction * i * 36, -_half_h - 20)
		icon.scale = Vector2.ONE * 0.85
		_buffer_root.add_child(icon)
		var n := Label.new()
		_style_label(n, 20)
		n.text = str(buf[item])
		n.position = icon.position + Vector2(-2, -2)
		n.size = Vector2(30, 24)
		_buffer_root.add_child(n)
		i += 1


func show_sale(value: int) -> void:
	var fly := Label.new()
	fly.text = "+%d" % value
	_style_label(fly, 28)
	fly.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	fly.add_theme_constant_override("outline_size", 8)
	fly.position = Vector2(-30, -70)
	fly.z_index = 25
	add_child(fly)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly, "position:y", -120.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(fly.queue_free)
