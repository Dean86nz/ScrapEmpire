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
	var b: Building
	match p_def.id:
		"sell_terminal":
			b = SellTerminal.new()
		"chest":
			b = Chest.new()
		"ship":
			b = Ship.new()
		"furnace", "press":
			b = Machine.new()
		"conveyor":
			b = Conveyor.new()
		"extractor":
			b = Extractor.new()
		_:
			b = Building.new()
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


## Ports in Weltkoordinaten: [{dir: "in"/"out", cell: Vector2i (Gebäudezelle), outside: Vector2i (Nachbarkachel), side: Vector2i}]
func ports_world() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var base := def.size
	for p: Dictionary in def.ports:
		var cell_arr: Array = p.get("cell", [0, 0])
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		var side_name := str(p.get("side", "right"))
		if side_name == "top":
			side_name = "up"
		if side_name == "bottom":
			side_name = "down"
		var side_dir: Vector2i = SIDE_DIRS[side_name]
		# Rotation um 90° im Uhrzeigersinn, rot-mal
		var w := base.x
		var h := base.y
		for i in posmod(rot, 4):
			cell = Vector2i(h - 1 - cell.y, cell.x)
			var tmp := w
			w = h
			h = tmp
			side_dir = Vector2i(-side_dir.y, side_dir.x)
		result.append({
			"dir": str(p.get("dir", "in")),
			"cell": tile + cell,
			"outside": tile + cell + side_dir,
			"side": side_dir,
		})
	return result


## Nimmt ein Gebäude Items von einem Band an, das auf `from_tile` steht und in `into_tile` zeigt?
func accepts_from_belt(from_tile: Vector2i, into_tile: Vector2i) -> bool:
	for p in ports_world():
		if p["dir"] == "in" and p["outside"] == from_tile and p["cell"] == into_tile:
			return true
	return false


## Liefert true, wenn sich der sichtbare Zustand geändert hat.
func tick() -> bool:
	return false


## Nimmt bis zu `count` Stück an und liefert die angenommene Menge.
func accept_stack(_item_id: String, _count: int) -> int:
	return 0


## Gibt einen Stapel heraus: {"item": String, "count": int}; leer = {}.
func withdraw_stack() -> Dictionary:
	return {}


## Ausgang für Bänder: ein Item entnehmen ("" wenn keins).
func pop_output_one() -> String:
	return ""


func has_output() -> bool:
	return false


## Alle enthaltenen Items (für Abriss): item_id → Menge.
func contents() -> Dictionary:
	return {}


## Kompakter Zustand für die Darstellung.
func summary() -> Dictionary:
	return {}
