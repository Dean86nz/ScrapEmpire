class_name CourierView
extends Node2D
## Darstellung eines Kuriers (MS34): kleine orange Lastdrohne mit Kiste, schwebt und folgt der Sim.

var courier_id := -1
var _courier: Courier
var _sprite := Sprite2D.new()
var _shadow := Polygon2D.new()
var _t := 0.0


func setup(c: Courier) -> void:
	courier_id = c.id
	_courier = c
	position = Vector2(c.pos)
	z_index = 9
	_shadow.polygon = DroneView._ellipse(16, 6)
	_shadow.color = Color(0, 0, 0, 0.18)
	_shadow.position = Vector2(0, 26)
	add_child(_shadow)
	_sprite.texture = load("res://assets/sprites/robot/courier.svg")
	_sprite.position = Vector2(0, -16)
	add_child(_sprite)
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _courier == null:
		return
	_t += delta
	position = position.lerp(Vector2(_courier.pos), minf(1.0, delta * 14.0))
	var bob := sin(_t * 8.0) * 3.0
	_sprite.position.y = -16.0 + bob
	_sprite.rotation = clampf((Vector2(_courier.pos) - position).x * 0.004, -0.3, 0.3)


func leave() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tw.tween_callback(queue_free)
