class_name DroneView
extends Node2D
## Darstellung einer Logistik-Drohne: Quadcopter mit Schatten, Schwebe-Bob, getragenes Item als kleines Symbol.

var drone_id: int = -1
var _drone: Drone
var _sprite := Sprite2D.new()
var _shadow := Polygon2D.new()
var _item := Sprite2D.new()
var _t := 0.0
var _rotor_angle := 0.0


func setup(d: Drone) -> void:
	drone_id = d.id
	_drone = d
	position = Vector2(d.pos)
	z_index = 8
	_shadow.polygon = _ellipse(22, 9)
	_shadow.color = Color(0, 0, 0, 0.18)
	_shadow.position = Vector2(0, 30)
	add_child(_shadow)
	_sprite.texture = load("res://assets/sprites/robot/drone.svg")
	_sprite.position = Vector2(0, -18)
	add_child(_sprite)
	_item.scale = Vector2(0.6, 0.6)
	_item.position = Vector2(0, 4)
	_item.visible = false
	add_child(_item)
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _process(delta: float) -> void:
	if _drone == null:
		return
	_t += delta
	position = position.lerp(Vector2(_drone.pos), minf(1.0, delta * 12.0))
	var bob := sin(_t * 6.0) * 3.0
	_sprite.position.y = -18.0 + bob
	_sprite.rotation = sin(_t * 1.7) * 0.06
	_shadow.scale = Vector2.ONE * (1.0 - bob * 0.02)
	if _drone.is_carrying():
		var path := "res://assets/sprites/items/%s.svg" % str(_drone.carry.keys()[0])
		if not _item.visible or _item.texture == null or _item.texture.resource_path != path:
			_item.texture = load(path) if ResourceLoader.exists(path) else null
		_item.visible = _item.texture != null
		_item.position.y = 4.0 + bob
	else:
		_item.visible = false
	_sprite.modulate = Color(1, 1, 1, 0.7) if _drone.state == Drone.State.IDLE else Color.WHITE
