class_name HelperView
extends Node2D
## Darstellung eines Helfer-Roboters: Rusty-Sprite in eigener Farbe, Namensschild, Sprechblase.
## Folgt der Sim-Position weich.

const SPEECH := preload("res://src/ui/hud/speech_bubble.tscn")

var helper_id: int = -1
var _helper: Helper
var _sprite := Sprite2D.new()
var _name := Label.new()
var _bubble: Node2D
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
	_bubble = SPEECH.instantiate()
	_bubble.listen_global = false
	_bubble.position = Vector2(0, -50)
	add_child(_bubble)


func say(text: String) -> void:
	if _bubble:
		_bubble.say(text)


func _process(delta: float) -> void:
	if _helper == null:
		return
	position = position.lerp(Vector2(_helper.pos), minf(1.0, delta * 12.0))
	if _helper.aim.length_squared() > 0.0:
		_sprite.rotation = rotate_toward(_sprite.rotation, _helper.aim.angle(), 10.0 * delta)
