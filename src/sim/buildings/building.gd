class_name Building
extends RefCounted
## Basisklasse aller Gebäude in der Simulation. Position ist die linke obere Kachel.

const TILE := 64
const SIDE_DIRS := {"right": Vector2i(1, 0), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "up": Vector2i(0, -1), "top": Vector2i(0, -1), "bottom": Vector2i(0, 1)}
const SIDE_ORDER := ["right", "down", "left", "up"]

var id: int
var def: BuildingDef
var tile: Vector2i
var rot: int = 0
var paid_cost: Dictionary = {}


static func create(p_id: int, p_def: BuildingDef, p_tile: Vector2i, p_rot: int) -> Building:
	var b: Building = Ship.new() if p_def.id == "ship" else Building.new()
	b.id = p_id
	b.def = p_def
	b.tile = p_tile
	b.rot = posmod(p_rot, 4)
	return b


func size() -> Vector2i:
	return def.rotated_size(rot)


func cells() -> Array[Vector2i]:
	return Grid.footprint(tile, size())


func rect_px() -> Rect2i:
	return Rect2i(tile * TILE, size() * TILE)


func center_px() -> Vector2i:
	return tile * TILE + size() * (TILE / 2)


## Liefert true, wenn sich der sichtbare Zustand geändert hat.
func tick() -> bool:
	return false


## Nimmt bis zu `count` Stück an und liefert die angenommene Menge.
func accept_stack(_item_id: String, _count: int) -> int:
	return 0


## Gibt einen Stapel heraus: {"item": String, "count": int}; leer = {}.
func withdraw_stack() -> Dictionary:
	return {}


## Alle enthaltenen Items (für Abriss): item_id → Menge.
func contents() -> Dictionary:
	return {}


## Kompakter Zustand für die Darstellung.
func summary() -> Dictionary:
	return {}
