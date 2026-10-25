class_name LooseItemView
extends Node2D
## Ein loses Item am Boden: Icon mit leichtem Auf-und-ab.

var item_id_num: int = -1
var _sprite := Sprite2D.new()
var _phase := 0.0


func setup(item: LooseItem) -> void:
	item_id_num = item.id
	_sprite.texture = DataRegistry.item_icon(item.item_id)
	_sprite.scale = Vector2.ONE * 1.1
	add_child(_sprite)
	position = Vector2(item.pos)
	_phase = float(item.id % 7)
	z_index = 1


func _process(delta: float) -> void:
	_phase += delta * 4.0
	_sprite.position.y = -4.0 + sin(_phase) * 3.0
