class_name HelperView
extends Node2D
## Darstellung eines Helfer-Roboters: Rusty-Sprite in eigener Farbe, Namensschild, kleine Symbole (seit MS44 kein Text).
## Folgt der Sim-Position weich.

var helper_id: int = -1
var _helper: Helper
var _sprite := Sprite2D.new()
var _name := Label.new()
var _names: Array = []
var _colors: Array = []


func setup(h: Helper, names: Array, colors: Array) -> void:
	helper_id = h.id
	_helper = h
	_names = names
	_colors = colors
	position = Vector2(h.pos)
	z_index = 4
	_sprite.texture = load("res://assets/sprites/robot/rusty.svg")
	_sprite.scale = Vector2(0.85, 0.85)
	var col := Color.html(str(colors[h.color_index % colors.size()])) if not colors.is_empty() else Color.WHITE
	_sprite.modulate = col.lerp(Color.WHITE, 0.25)
	add_child(_sprite)
	_name.text = h.display_name(names)
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	_name.add_theme_constant_override("outline_size", 6)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.position = Vector2(-80, 28)
	_name.size = Vector2(160, 28)
	add_child(_name)


## Kleines Symbol über dem Bot (z. B. „!“ bei Verstärkung): hüpft auf, verblasst.
func emote(symbol: String, color: Color = Color(1.0, 0.55, 0.15)) -> void:
	var l := Label.new()
	l.text = symbol
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(60, 56)
	l.position = Vector2(-30, -110)
	l.pivot_offset = Vector2(30, 50)
	l.scale = Vector2.ZERO
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if _helper == null:
		return
	position = position.lerp(Vector2(_helper.pos), minf(1.0, delta * 12.0))
	if _helper.aim.length_squared() > 0.0:
		_sprite.rotation = rotate_toward(_sprite.rotation, _helper.aim.angle(), 10.0 * delta)
