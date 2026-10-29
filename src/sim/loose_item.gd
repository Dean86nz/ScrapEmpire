class_name LooseItem
extends RefCounted
## Ein einzelnes Item, das auf dem Boden liegt (z. B. aus einem Wrack geschlagen).
## `tier` ist die Stufe des Objekts, aus dem es stammt (für XP).

var id: int
var item_id: String
var pos: Vector2i
var tier: int = 1
var count: int = 1   # Bündel (MS64): ein Haufen „×12“ statt vieler Einzelteile


func _init(p_id: int, p_item_id: String, p_pos: Vector2i, p_tier: int = 1, p_count: int = 1) -> void:
	id = p_id
	item_id = p_item_id
	pos = p_pos
	tier = p_tier
	count = maxi(1, p_count)
