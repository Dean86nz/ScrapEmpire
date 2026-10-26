class_name ShipFx
extends Node2D
## Effekte am Schiff (nur Darstellung): Rauch beim Wrack, Blinklichter ab Stufe 3, glühende Düsen
## auf Stufe 5. Dazu die Feier nach einer Reparatur und die Abflug-Szene. Hängt an der BuildingView
## des Schiffs und bewegt sich mit ihr.

signal launch_finished

const LIGHTS := [Vector2(-44, 22), Vector2(0, 32), Vector2(44, 22)]
const NOZZLES := [Vector2(-21, 70), Vector2(21, 70)]
const LIGHT_COLORS := [Color(1.0, 0.35, 0.3), Color(1.0, 0.85, 0.3), Color(0.45, 0.95, 0.45)]

var stage := 1
var _sprite: Sprite2D
var _smoke := CPUParticles2D.new()
var _confetti := CPUParticles2D.new()
var _flames := CPUParticles2D.new()
var _dust := CPUParticles2D.new()
var _t := 0.0
var _ring_r := 0.0
var _ring_a := 0.0
var _launching := false


func setup(sprite: Sprite2D, p_stage: int) -> void:
	_sprite = sprite
	z_index = 2
	_setup_smoke()
	_setup_confetti()
	_setup_flames()
	set_stage(p_stage)


func set_stage(p_stage: int) -> void:
	stage = p_stage
	_smoke.emitting = stage <= 2 and not _launching
	_smoke.amount = 12 if stage == 1 else 5
	queue_redraw()


## Weicher runder Punkt für Rauch, Flammen und Staub (Partikel sind sonst eckig).
static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.85))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _setup_smoke() -> void:
	_smoke.texture = _soft_dot()
	_smoke.position = Vector2(36, -50)
	_smoke.amount = 12
	_smoke.lifetime = 2.6
	_smoke.direction = Vector2(0.3, -1)
	_smoke.spread = 18.0
	_smoke.gravity = Vector2(10, -20)
	_smoke.initial_velocity_min = 30.0
	_smoke.initial_velocity_max = 50.0
	_smoke.scale_amount_min = 0.9
	_smoke.scale_amount_max = 1.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.4))
	_smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.8, 0.82, 0.55))
	grad.set_color(1, Color(0.78, 0.8, 0.82, 0.0))
	_smoke.color_ramp = grad
	add_child(_smoke)


func _setup_confetti() -> void:
	_confetti.one_shot = true
	_confetti.emitting = false
	_confetti.explosiveness = 0.95
	_confetti.amount = 140
	_confetti.lifetime = 1.8
	_confetti.direction = Vector2(0, -1)
	_confetti.spread = 100.0
	_confetti.initial_velocity_min = 300.0
	_confetti.initial_velocity_max = 620.0
	_confetti.gravity = Vector2(0, 600)
	_confetti.scale_amount_min = 6.0
	_confetti.scale_amount_max = 11.0
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.4, 0.4))
	grad.set_color(1, Color(0.4, 0.8, 1.0))
	grad.add_point(0.33, Color(1.0, 0.9, 0.3))
	grad.add_point(0.66, Color(0.5, 0.95, 0.5))
	_confetti.color_initial_ramp = grad
	_confetti.z_index = 40
	add_child(_confetti)


func _setup_flames() -> void:
	_flames.texture = _soft_dot()
	_flames.position = Vector2(0, 76)
	_flames.emitting = false
	_flames.amount = 90
	_flames.lifetime = 0.7
	_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flames.emission_rect_extents = Vector2(30, 4)
	_flames.direction = Vector2(0, 1)
	_flames.spread = 14.0
	_flames.initial_velocity_min = 260.0
	_flames.initial_velocity_max = 420.0
	_flames.scale_amount_min = 0.6
	_flames.scale_amount_max = 1.1
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.set_color(1, Color(0.9, 0.3, 0.1, 0.0))
	grad.add_point(0.4, Color(1.0, 0.6, 0.2, 0.9))
	_flames.color_ramp = grad
	_flames.z_index = -1
	add_child(_flames)
	_dust.texture = _flames.texture
	_dust.position = Vector2(0, 80)
	_dust.emitting = false
	_dust.amount = 40
	_dust.lifetime = 1.4
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(60, 6)
	_dust.direction = Vector2(1, 0)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 120.0
	_dust.initial_velocity_max = 240.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 1.8
	var dg := Gradient.new()
	dg.set_color(0, Color(0.85, 0.82, 0.75, 0.7))
	dg.set_color(1, Color(0.85, 0.82, 0.75, 0.0))
	_dust.color_ramp = dg
	add_child(_dust)


func _process(delta: float) -> void:
	_t += delta
	if stage >= 3 or _ring_a > 0.0:
		queue_redraw()


func _draw() -> void:
	if _ring_a > 0.0:
		draw_arc(Vector2.ZERO, _ring_r, 0.0, TAU, 96, Color(1.0, 1.0, 0.85, _ring_a), 10.0)
		draw_arc(Vector2.ZERO, _ring_r * 0.92, 0.0, TAU, 96, Color(0.5, 0.95, 0.5, _ring_a * 0.6), 6.0)
	if _sprite == null:
		return
	var off := _sprite.offset + _sprite.position
	if stage >= 3 and stage <= 4:
		for i in LIGHTS.size():
			var on := fmod(_t * 1.6 + i * 0.33, 1.0) < 0.5
			draw_circle(off + LIGHTS[i], 6.0 if on else 4.0, LIGHT_COLORS[i] if on else LIGHT_COLORS[i].darkened(0.5))
	if stage >= 5:
		var glow := 0.55 + 0.35 * sin(_t * 5.0)
		for p in NOZZLES:
			draw_circle(off + p + Vector2(0, 6), 14.0, Color(1.0, 0.6, 0.2, glow * 0.5))
			draw_circle(off + p + Vector2(0, 4), 8.0, Color(1.0, 0.9, 0.5, glow))


## Feier nach einer Reparatur: Konfetti, Hüpfer, Aufblitzen und ein Ring, der wie die Putzwelle wächst.
func celebrate(clean_radius_tiles: int) -> void:
	_confetti.restart()
	_confetti.emitting = true
	if _sprite != null:
		_sprite.scale = Vector2.ONE
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(1.3, 0.8), 0.12)
		tw.tween_property(_sprite, "scale", Vector2(0.9, 1.2), 0.14)
		tw.tween_property(_sprite, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_sprite.modulate = Color(2.2, 2.2, 2.2)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.6)
	_ring_r = 60.0
	_ring_a = 1.0
	var target := maxf(clean_radius_tiles * 64.0, 200.0)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(self, "_ring_r", target, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	rt.tween_property(self, "_ring_a", 0.0, 1.4).set_ease(Tween.EASE_IN)


## Abflug: Rütteln, Düsen zünden, Staub, dann steigt das Schiff aus dem Bild. Meldet `launch_finished`.
func launch() -> void:
	_launching = true
	_smoke.emitting = false
	var view := get_parent() as Node2D
	var base := view.position
	_dust.visible = true
	_flames.visible = true
	_dust.emitting = true
	_flames.emitting = true
	_flames.amount = 40
	var shake := create_tween()
	shake.tween_method(func(t: float) -> void:
		if _sprite != null:
			_sprite.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (2.0 + t * 7.0), 0.0, 1.0, 1.6)
	await shake.finished
	if _sprite != null:
		_sprite.position = Vector2.ZERO
	_flames.amount = 90
	var rise := create_tween()
	rise.tween_property(view, "position:y", base.y - 1700.0, 2.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await rise.finished
	_dust.emitting = false
	launch_finished.emit()


## Nach der End-Szene: Schiff steht wieder an seinem Platz (Rusty bleibt und räumt weiter auf).
func land(base: Vector2) -> void:
	_launching = false
	_flames.emitting = false
	_dust.emitting = false
	_flames.visible = false
	_dust.visible = false
	(get_parent() as Node2D).position = base
	set_stage(stage)
