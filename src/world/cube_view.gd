class_name CubeView
extends Node2D
## Fliegender Müllwürfel (MS77): hoher Bogen vom Streuner zum Fangtrichter, dreht sich, Schatten
## am Boden. Rein kosmetisch; Start, Ziel und Flugzeit kommen aus der Sim (TrashCube).

const TEX := preload("res://assets/sprites/robot/cube.svg")

var cube_id := -1
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _dur := 1.0
var _t := 0.0
var _height := 160.0
var _sprite := Sprite2D.new()
var _shadow := Polygon2D.new()


func setup(c: TrashCube) -> void:
	cube_id = c.id
	_from = Vector2(c.from)
	_to = Vector2(c.to)
	_dur = maxf(c.dur / 20.0, 0.1)
	_t = c.t / 20.0
	_height = clampf(_from.distance_to(_to) * 0.35, 90.0, 260.0)
	z_index = 30
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(Vector2(cos(i * TAU / 12.0) * 16.0, sin(i * TAU / 12.0) * 6.0))
	_shadow.polygon = pts
	_shadow.color = Color(0.165, 0.165, 0.2, 0.3)
	add_child(_shadow)
	_sprite.texture = TEX
	_sprite.scale = Vector2(0.9, 0.9)
	add_child(_sprite)
	_place()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		queue_free()
		return
	_place()


func _place() -> void:
	var k := clampf(_t / _dur, 0.0, 1.0)
	position = _from.lerp(_to, k)
	_shadow.position = Vector2.ZERO
	_sprite.position = Vector2(0, -4.0 * _height * k * (1.0 - k))
	_sprite.rotation = k * TAU * 1.5
	var s := 0.9 + 0.25 * sin(k * PI)
	_sprite.scale = Vector2(s, s)
