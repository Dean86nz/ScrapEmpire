class_name ResourceNode
extends RefCounted
## Schrott-Objekt auf einer Kachel. Datengetrieben über data/scrap_objects.json:
## "pile" wächst nach und wird gesaugt; "loot" ist endlich, wird gehämmert oder gesaugt
## und respawnt nach einer Zeit. Jedes Objekt hat eine Härte-Stufe (tier) und ein Werkzeug.

const TILE := 64
const TICKS_PER_SECOND := 20
const PILE_MAX := 10
const PILE_REGEN_TICKS := 600  # 30 s
const KIND_WRECK := "wreck"

## Eingebaute Mindest-Definitionen (Tests und Fallback); scrap_objects.json überschreibt/ergänzt.
const BUILTIN_DEFS := {
	"scrap_pile": {"tier": 1, "tool": "suction", "type": "pile", "item": "scrap", "max": 10, "regen_s": 30},
	"copper_tangle": {"tier": 1, "tool": "suction", "type": "pile", "item": "copper", "max": 10, "regen_s": 30},
	"plastic_crumbs": {"tier": 1, "tool": "suction", "type": "pile", "item": "plastic", "max": 10, "regen_s": 30},
	"wreck": {"tier": 1, "tool": "hammer", "type": "loot", "yield": {}, "respawn_s": 0},
}

static var defs: Dictionary = BUILTIN_DEFS.duplicate(true)

var id: int
var kind: String
var tile: Vector2i
var amount: int
var max_amount: int
var regen_ticks: int
var loot: Dictionary = {}  # nur loot: item_id → Restmenge
var tier: int = 1
var tool: String = "suction"
var respawn_ticks: int = 0
var resource: bool = false  # unendliche Rohstoffquelle, zählt nicht als Müll
var bonus: bool = false     # aus einem Ereignis (Touristen, Meteoriten), liegt auf sauberem Boden
var boss := false           # Müllberg-Boss der Zone (MS36): nächste Werkzeugstufe oder Bot-Team
var bots_needed := 0        # so viele Bots der Zone knacken ihn auch ohne passende Stufe
var final := false          # Endboss: nötig für den Abflug
var _pile_item: String = ""
var regen_counter: int = 0


## Lädt data/scrap_objects.json über die eingebauten Definitionen.
static func load_defs(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("scrap_objects.json nicht lesbar: " + path)
		return
	defs = BUILTIN_DEFS.duplicate(true)
	for entry: Dictionary in parsed.get("objects", []):
		defs[str(entry["id"])] = entry


static func has_kind(p_kind: String) -> bool:
	return defs.has(p_kind)


static func is_pile_kind(p_kind: String) -> bool:
	return defs.has(p_kind) and str(defs[p_kind].get("type", "")) == "pile"


## Erzeugt ein Objekt aus seiner Definition. amount_override gilt nur für Haufen.
static func from_kind(p_id: int, p_kind: String, p_tile: Vector2i, amount_override: int = -1) -> ResourceNode:
	assert(defs.has(p_kind), "unbekanntes Schrott-Objekt: " + p_kind)
	var d: Dictionary = defs[p_kind]
	var n := ResourceNode.new()
	n.id = p_id
	n.kind = p_kind
	n.tile = p_tile
	n.tier = int(d.get("tier", 1))
	n.tool = str(d.get("tool", "suction"))
	n.resource = bool(d.get("resource", false))
	n.boss = bool(d.get("boss", false))
	n.bots_needed = int(d.get("bots_needed", 0))
	n.final = bool(d.get("final", false))
	if str(d.get("type", "pile")) == "pile":
		n._pile_item = str(d.get("item", "scrap"))
		n.max_amount = int(d.get("max", PILE_MAX))
		n.amount = n.max_amount if amount_override < 0 else clampi(amount_override, 0, n.max_amount)
		n.regen_ticks = int(float(d.get("regen_s", 30)) * TICKS_PER_SECOND)
	else:
		for k in d.get("yield", {}):
			n.loot[str(k)] = int(d["yield"][k])
		n.amount = 0
		for k in n.loot:
			n.amount += int(n.loot[k])
		n.max_amount = n.amount
		n.regen_ticks = 0
		n.respawn_ticks = int(float(d.get("respawn_s", 0)) * TICKS_PER_SECOND)
	return n


static func make_pile(p_id: int, p_kind: String, p_tile: Vector2i, p_amount: int) -> ResourceNode:
	return from_kind(p_id, p_kind, p_tile, p_amount)


## Endliches Hammer-Objekt mit eigener Ausbeute (Tests, Karten mit explizitem "loot").
static func make_wreck(p_id: int, p_tile: Vector2i, p_loot: Dictionary, p_kind: String = KIND_WRECK) -> ResourceNode:
	var n := from_kind(p_id, p_kind, p_tile)
	n.loot = {}
	for k in p_loot:
		n.loot[str(k)] = int(p_loot[k])
	n.amount = 0
	for k in n.loot:
		n.amount += int(n.loot[k])
	n.max_amount = n.amount
	return n


func is_pile() -> bool:
	return _pile_item != ""


## Endliches Objekt (Wrack, Toaster, Satellit …), unabhängig vom Werkzeug.
func is_wreck() -> bool:
	return not is_pile()


func uses_hammer() -> bool:
	return tool == "hammer"


func is_resource() -> bool:
	return resource


func item_id() -> String:
	return _pile_item


func center_px() -> Vector2i:
	return tile * TILE + Vector2i(TILE / 2, TILE / 2)


func is_depleted() -> bool:
	return amount <= 0


## Leer und wächst nicht nach: verschwindet (seit MS30 gilt das auch für Haufen).
func is_used_up() -> bool:
	return amount <= 0 and regen_ticks <= 0


## Liefert true, wenn sich amount geändert hat.
func tick() -> bool:
	if regen_ticks <= 0 or amount >= max_amount:
		regen_counter = 0
		return false
	regen_counter += 1
	if regen_counter >= regen_ticks:
		regen_counter = 0
		amount += 1
		return true
	return false


## Entnimmt ein Item. Haufen: immer dasselbe Item. Loot: Item mit größter Restmenge
## (bei Gleichstand alphabetisch), damit die Ausbeute gemischt und deterministisch ist.
func take_one() -> String:
	if amount <= 0:
		return ""
	if is_pile():
		amount -= 1
		return _pile_item
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
