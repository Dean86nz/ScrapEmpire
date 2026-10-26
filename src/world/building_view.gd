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
var ship_fx: ShipFx   # nur beim Schiff




func setup(b: Building) -> void:
	building_id = b.id
	_building = b
	position = Vector2(b.center_px())
	_sprite.texture = load((b as Ship).sprite_path if b is Ship and (b as Ship).sprite_path != "" else b.def.sprite)
	_sprite.rotation = b.rot * PI / 2.0
	add_child(_sprite)

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

	if b is Ship:
		ship_fx = ShipFx.new()
		add_child(ship_fx)
		ship_fx.setup(_sprite, (b as Ship).stage)
	refresh(b)


func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func refresh(b: Building) -> void:
	_building = b
	_sprite.rotation = b.rot * PI / 2.0
	var s := b.summary()
	if b is Ship:
		var sh := b as Ship
		if sh.sprite_path != "" and (_sprite.texture == null or _sprite.texture.resource_path != sh.sprite_path):
			_sprite.texture = load(sh.sprite_path)
		if ship_fx != null and ship_fx.stage != sh.stage:
			ship_fx.set_stage(sh.stage)
		_label.visible = false
		return
	if s.has("buffer"):
		_label.text = "%d / %d" % [s["buffer"], s["buffer_max"]]
		_label.visible = s["buffer"] > 0
	elif s.has("total"):
		_label.text = "%d / %d" % [s["total"], s["capacity"]]
		_label.visible = s["total"] > 0
	else:
		_label.visible = false


## Fliegender Betrag über dem Gebäude. `big`: Rustys Abgabe (groß, springt auf, bleibt länger).
func show_sale(value: int, big: bool = false) -> void:
	var fly := Label.new()
	fly.text = "+%d" % value
	_style_label(fly, 46 if big else 26)
	fly.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	fly.add_theme_constant_override("outline_size", 12 if big else 8)
	fly.size = Vector2(240, 60)
	fly.position = Vector2(-120, -_half_h + (10.0 if big else -30.0))
	fly.pivot_offset = Vector2(120, 30)
	fly.z_index = 25
	add_child(fly)
	var rise := 70.0 if big else 50.0
	var life := 1.3 if big else 0.7
	var tween := create_tween()
	tween.set_parallel(true)
	if big:
		fly.scale = Vector2(0.4, 0.4)
		tween.tween_property(fly, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tween.tween_property(fly, "position:y", fly.position.y - rise, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "modulate:a", 0.0, 0.4).set_delay(life - 0.4)
	tween.chain().tween_callback(fly.queue_free)
