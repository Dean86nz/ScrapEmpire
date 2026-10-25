class_name LooseItem
extends RefCounted
## Ein einzelnes Item, das auf dem Boden liegt (z. B. aus einem Wrack geschlagen).

var id: int
var item_id: String
var pos: Vector2i


func _init(p_id: int, p_item_id: String, p_pos: Vector2i) -> void:
	id = p_id
	item_id = p_item_id
	pos = p_pos
