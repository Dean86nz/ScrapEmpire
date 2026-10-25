class_name BuildingView
extends Node2D
## Darstellung eines Gebäudes: Sprite (gedreht), Kollision für Rusty, Füllstandslabel,
## schwebender Verkaufs-Text.

var building_id: int = -1
var _sprite := Sprite2D.new()
var _label := Label.new()
var _body := StaticBody2D.new()


func setup(b: Building) -> void:
	building_id = b.id
	position = Vector2(b.center_px())
	_sprite.texture = load(b.def.sprite)
	_sprite.rotation = b.rot * PI / 2.0
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(b.size() * Building.TILE) - Vector2(8, 8)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)

	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h := b.size().y * Building.TILE / 2.0
	_label.position = Vector2(-80, h - 12)
	_label.size = Vector2(160, 30)
	add_child(_label)
	refresh(b)


func refresh(b: Building) -> void:
	var s := b.summary()
	if s.has("buffer"):
		_label.text = "%d / %d" % [s["buffer"], s["buffer_max"]]
		_label.visible = s["buffer"] > 0
	elif s.has("total"):
		_label.text = "%d / %d" % [s["total"], s["capacity"]]
		_label.visible = s["total"] > 0
	else:
		_label.visible = false


func show_sale(value: int) -> void:
	var fly := Label.new()
	fly.text = "+%d" % value
	fly.add_theme_font_size_override("font_size", 28)
	fly.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	fly.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	fly.add_theme_constant_override("outline_size", 8)
	fly.position = Vector2(-30, -70)
	fly.z_index = 25
	add_child(fly)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly, "position:y", -120.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(fly.queue_free)
