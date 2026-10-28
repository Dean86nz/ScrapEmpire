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
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(60, 56)
	l.position = Vector2(-30, -110)
	l.pivot_offset = Vector2(30, 50)
	l.scale = Vector2.ZERO
	add_child(l)
	# 32 px auf dem Bildschirm, unabhängig vom Kamera-Zoom (MS51)
	var s := 1.0 / maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * s, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if _helper == null:
		return
	position = position.lerp(Vector2(_helper.pos), minf(1.0, delta * 12.0))
	if _helper.aim.length_squared() > 0.0:
		_sprite.rotation = rotate_toward(_sprite.rotation, _helper.aim.angle(), 10.0 * delta)
	_update_work_look(delta)


# --- Sichtbar arbeiten (MS56): Saugkegel, Hammerschwung, Teile fliegen herein, Ladebalken,
# Leerlauf grau und langsam wippend ----------------------------------------------------------

var _cone: Polygon2D
var _load_bg: ColorRect
var _load_fill: ColorRect
var _hammer: Label
var _last_total := 0
var _last_cd := 0
var _t := 0.0


func _ensure_work_nodes() -> void:
	if _cone != null:
		return
	_cone = Polygon2D.new()
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		pts.append(Vector2.RIGHT.rotated(-0.45 + 0.9 * i / 8.0) * 120.0)
	_cone.polygon = pts
	_cone.color = Color(0.4, 0.8, 1.0, 0.28)
	_cone.z_index = -1
	_cone.visible = false
	add_child(_cone)
	_load_bg = ColorRect.new()
	_load_bg.color = Color(0.165, 0.165, 0.2, 0.75)
	_load_bg.size = Vector2(56, 9)
	_load_bg.position = Vector2(-28, -52)
	add_child(_load_bg)
	_load_fill = ColorRect.new()
	_load_fill.color = Color(0.45, 0.85, 0.4)
	_load_fill.size = Vector2(0, 5)
	_load_fill.position = Vector2(-26, -50)
	add_child(_load_fill)
	_hammer = Label.new()
	_hammer.text = "🔨"
	_hammer.add_theme_font_size_override("font_size", 30)
	_hammer.position = Vector2(14, -40)
	_hammer.pivot_offset = Vector2(4, 30)
	_hammer.visible = false
	add_child(_hammer)


func _update_work_look(delta: float) -> void:
	_ensure_work_nodes()
	_t += delta
	var cap := maxi(_helper.inventory.slot_count * _helper.inventory.stack_size, 1)
	var total := _helper.inventory.total()
	_load_fill.size.x = 52.0 * clampf(float(total) / cap, 0.0, 1.0)
	_load_fill.color = Color(0.45, 0.85, 0.4) if total < cap else Color(1.0, 0.7, 0.25)
	_load_bg.visible = total > 0
	_load_fill.visible = total > 0
	# Saugkegel in Blickrichtung, solange der Bot saugt
	_cone.visible = _helper.suck_held
	if _cone.visible:
		_cone.rotation = _helper.aim.angle()
		_cone.color.a = 0.2 + 0.1 * sin(_t * 16.0)
	# Teile fliegen sichtbar in den Bot
	if total > _last_total:
		_fly_in(mini(total - _last_total, 3))
	_last_total = total
	# Hammerschwung bei jedem Schlag
	if _helper.hammer_cooldown > _last_cd:
		_swing()
	_last_cd = _helper.hammer_cooldown
	# Leerlauf: grauer, langsam wippend; Arbeit: volle Farbe
	var idle := _helper.bored != "" and total == 0 and not _helper.has_move_target()
	var base := _base_modulate()
	_sprite.modulate = _sprite.modulate.lerp(base.lerp(Color(0.6, 0.6, 0.65), 0.6) if idle else base, minf(1.0, delta * 4.0))
	_sprite.position.y = sin(_t * 1.6) * 3.0 if idle else 0.0


func _base_modulate() -> Color:
	var col := Color.html(str(_colors[_helper.color_index % _colors.size()])) if not _colors.is_empty() else Color.WHITE
	return col.lerp(Color.WHITE, 0.25)


func _fly_in(n: int) -> void:
	for i in n:
		var bit := ColorRect.new()
		bit.color = Color(0.75, 0.75, 0.8)
		bit.size = Vector2(9, 9)
		var start := _helper.aim * (90.0 + 15.0 * i) + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		bit.position = start
		add_child(bit)
		var tw := create_tween()
		tw.tween_property(bit, "position", Vector2(-4, -4), 0.22).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(bit, "scale", Vector2(0.3, 0.3), 0.22)
		tw.tween_callback(bit.queue_free)


func _swing() -> void:
	_hammer.visible = true
	_hammer.rotation = -1.2
	var tw := create_tween()
	tw.tween_property(_hammer, "rotation", 0.6, 0.09)
	tw.tween_property(_hammer, "rotation", -0.2, 0.12)
	tw.tween_callback(func() -> void: _hammer.visible = false)
	var sq := create_tween()
	sq.tween_property(_sprite, "scale", Vector2(0.95, 0.75), 0.06)
	sq.tween_property(_sprite, "scale", Vector2(0.85, 0.85), 0.1)
