class_name ResourceNode
extends RefCounted
## Rohstoffquelle auf einer Kachel: Haufen (saugbar, wächst nach) oder Wrack (hämmerbar, endlich).

const TILE := 64
const PILE_MAX := 10
const PILE_REGEN_TICKS := 600  # 30 s
const KIND_WRECK := "wreck"

## kind → item_id für Haufen
const PILE_ITEMS := {
	"scrap_pile": "scrap",
	"copper_tangle": "copper",
	"plastic_crumbs": "plastic",
}

var id: int
var kind: String
var tile: Vector2i
var amount: int
var max_amount: int
var regen_ticks: int
var loot: Dictionary = {}  # nur Wrack: item_id → Restmenge
var _regen_counter: int = 0


static func is_pile_kind(p_kind: String) -> bool:
	return PILE_ITEMS.has(p_kind)


static func make_pile(p_id: int, p_kind: String, p_tile: Vector2i, p_amount: int) -> ResourceNode:
	assert(PILE_ITEMS.has(p_kind), "unbekannter Haufen: " + p_kind)
	var n := ResourceNode.new()
	n.id = p_id
	n.kind = p_kind
	n.tile = p_tile
	n.max_amount = PILE_MAX
	n.amount = clampi(p_amount, 0, PILE_MAX)
	n.regen_ticks = PILE_REGEN_TICKS
	return n


static func make_wreck(p_id: int, p_tile: Vector2i, p_loot: Dictionary) -> ResourceNode:
	var n := ResourceNode.new()
	n.id = p_id
	n.kind = KIND_WRECK
	n.tile = p_tile
	n.loot = p_loot.duplicate()
	n.amount = 0
	for k in n.loot:
		n.amount += int(n.loot[k])
	n.max_amount = n.amount
	n.regen_ticks = 0
	return n


func is_wreck() -> bool:
	return kind == KIND_WRECK


func item_id() -> String:
	return PILE_ITEMS.get(kind, "")


func center_px() -> Vector2i:
	return tile * TILE + Vector2i(TILE / 2, TILE / 2)


func is_depleted() -> bool:
	return amount <= 0


## Liefert true, wenn sich amount geändert hat.
func tick() -> bool:
	if regen_ticks <= 0 or amount >= max_amount:
		_regen_counter = 0
		return false
	_regen_counter += 1
	if _regen_counter >= regen_ticks:
		_regen_counter = 0
		amount += 1
		return true
	return false


## Entnimmt ein Item. Haufen: immer dasselbe Item. Wrack: Item mit größter Restmenge
## (bei Gleichstand alphabetisch), damit die Ausbeute gemischt und deterministisch ist.
func take_one() -> String:
	if amount <= 0:
		return ""
	if not is_wreck():
		amount -= 1
		return item_id()
	var keys := loot.keys()
	keys.sort()
	var best := ""
	var best_n := 0
	for k: String in keys:
		if int(loot[k]) > best_n:
			best = k
			best_n = int(loot[k])
	if best == "":
		return ""
	loot[best] = best_n - 1
	amount -= 1
	return best
