class_name Grid
extends RefCounted
## Kachelbelegung: Vector2i → Building. Ein 2×2-Gebäude belegt vier Einträge auf dasselbe Objekt.

var width: int
var height: int
var _cells: Dictionary = {}


func _init(p_width: int = 120, p_height: int = 90) -> void:
	width = p_width
	height = p_height


func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


func is_free(tile: Vector2i) -> bool:
	return in_bounds(tile) and not _cells.has(tile)


func at(tile: Vector2i) -> Building:
	return _cells.get(tile, null)


static func footprint(tile: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(tile + Vector2i(x, y))
	return cells


## True, wenn alle Kacheln frei sind und `blocked(tile)` (optional) für keine true liefert.
func can_place(tile: Vector2i, size: Vector2i, blocked: Callable = Callable()) -> bool:
	for c in footprint(tile, size):
		if not is_free(c):
			return false
		if blocked.is_valid() and blocked.call(c):
			return false
	return true


func place(building: Building) -> void:
	for c in building.cells():
		_cells[c] = building


func remove(building: Building) -> void:
	for c in building.cells():
		if _cells.get(c) == building:
			_cells.erase(c)


func occupied_count() -> int:
	return _cells.size()
