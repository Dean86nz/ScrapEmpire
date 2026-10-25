class_name CollectibleView
extends Node2D
## Fundstück: Sprite mit Funkeln und leichtem Schweben, damit es im Müll auffällt.

var collectible_id: int = -1
var _sprite := Sprite2D.new()
var _t := 0.0
var _sparkles: Array[Polygon2D] = []


func setup(c: Collectible, sprite_path: String) -> void:
	collectible_id = c.id
	position = Vector2(c.center_px())
	z_index = 1
	_sprite.texture = load(sprite_path) if ResourceLoader.exists(sprite_path) else null
	add_child(_sprite)
	for i in 3:
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(0, -6), Vector2(2, -2), Vector2(6, 0), Vector2(2, 2), Vector2(0, 6), Vector2(-2, 2), Vector2(-6, 0), Vector2(-2, -2)])
		p.color = Color(1.0, 0.95, 0.6, 0.9)
		add_child(p)
		_sparkles.append(p)


func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = sin(_t * 2.2) * 3.0
	for i in _sparkles.size():
		var a := _t * 1.3 + i * TAU / 3.0
		var s := _sparkles[i]
		s.position = Vector2(cos(a) * 30.0, sin(a * 1.4) * 18.0 - 10.0)
		s.scale = Vector2.ONE * (0.6 + 0.4 * absf(sin(_t * 3.0 + i)))
		s.modulate.a = 0.5 + 0.5 * absf(sin(_t * 2.0 + i * 1.1))
