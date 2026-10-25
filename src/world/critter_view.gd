class_name CritterView
extends Node2D
## Kosmetisches Tier: streunt in seiner Zone, folgt Rusty neugierig mit Abstand, hüpft beim Laufen.

var kind := "bug"
var zone_rect_px := Rect2()
var speed := 60.0
var _player: Node2D
var _target := Vector2.ZERO
var _wait := 0.0
var _t := 0.0
var _sprite := Sprite2D.new()
var _rng := RandomNumberGenerator.new()

const FOLLOW_RADIUS := 380.0
const KEEP_DISTANCE := 120.0


func setup(p_kind: String, rect_px: Rect2, p_speed: float, player: Node2D, seed_value: int) -> void:
	kind = p_kind
	zone_rect_px = rect_px.grow(-48)
	speed = p_speed
	_player = player
	_rng.seed = seed_value
	_sprite.texture = load("res://assets/sprites/nature/critter_%s.svg" % kind)
	add_child(_sprite)
	z_index = 3
	position = Vector2(_rng.randf_range(zone_rect_px.position.x, zone_rect_px.end.x), _rng.randf_range(zone_rect_px.position.y, zone_rect_px.end.y))
	_target = position
	_wait = _rng.randf_range(0.5, 2.0)
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	var to_player := _player.global_position - global_position if _player != null else Vector2(9999, 9999)
	var near := to_player.length() < FOLLOW_RADIUS and zone_rect_px.has_point(_player.global_position)
	if near:
		# Neugierig: Abstand halten, leicht versetzt
		var desired := _player.global_position - to_player.normalized() * KEEP_DISTANCE
		_target = Vector2(clampf(desired.x, zone_rect_px.position.x, zone_rect_px.end.x), clampf(desired.y, zone_rect_px.position.y, zone_rect_px.end.y))
	elif position.distance_to(_target) < 6.0:
		_wait -= delta
		if _wait <= 0.0:
			_wait = _rng.randf_range(1.0, 4.0)
			_target = Vector2(_rng.randf_range(zone_rect_px.position.x, zone_rect_px.end.x), _rng.randf_range(zone_rect_px.position.y, zone_rect_px.end.y))
	var d := _target - position
	var moving := d.length() > 6.0
	if moving:
		position += d.normalized() * minf(speed * delta, d.length())
		_sprite.flip_h = d.x < 0.0
	var bob := (absf(sin(_t * (14.0 if kind == "bird" else 9.0))) * (10.0 if kind == "bird" else 4.0)) if moving else (sin(_t * 2.0) * 1.5)
	_sprite.position.y = -bob
