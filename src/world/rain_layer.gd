class_name RainLayer
extends CanvasLayer
## Leichter Regen über dem Bild (unter dem HUD). Partikel fallen schräg, ohne Sound.

var _particles := CPUParticles2D.new()
var _overlay := ColorRect.new()


func _ready() -> void:
	layer = 5
	_overlay.color = Color(0.5, 0.65, 1.0, 0.0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_particles.emitting = false
	_particles.amount = 260
	_particles.lifetime = 1.3
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(1100, 8)
	_particles.position = Vector2(960, -20)
	_particles.direction = Vector2(-0.25, 1)
	_particles.spread = 4.0
	_particles.gravity = Vector2(0, 900)
	_particles.initial_velocity_min = 700.0
	_particles.initial_velocity_max = 900.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 3.0
	_particles.color = Color(0.55, 0.72, 1.0, 0.55)
	add_child(_particles)


func set_raining(on: bool) -> void:
	_particles.emitting = on
	create_tween().tween_property(_overlay, "color:a", 0.08 if on else 0.0, 1.5)
