class_name PlayerState
extends RefCounted
## Sim-Sicht auf Rusty: Position und Eingaben (vom Player-Node pro Frame geschrieben),
## Inventar, Werkzeugwerte (aus Modifiers) und Cooldowns (von der Sim im Tick verwaltet).

const BASE_SUCK_RANGE_PX := 160      # 2,5 Kacheln
const SUCK_HALF_ANGLE_RAD := PI / 4  # Kegel 90°
const BASE_SUCK_INTERVAL := 5        # 1 Item / 0,25 s
const BASE_HAMMER_RANGE_PX := 64     # 1 Kachel
const HAMMER_REACH_PX := 48          # Zielpunkt vor Rusty
const BASE_HAMMER_INTERVAL := 10     # 1 Schlag / 0,5 s
const INVENTORY_SLOTS := 6
const STACK_SIZE := 20
const TILE := 64

# Eingaben (werden vom Player-Node gesetzt)
var pos := Vector2i.ZERO
var aim := Vector2.RIGHT
var suck_held := false
var hammer_pressed := false

# Zustand (von der Sim verwaltet)
var inventory := Inventory.new(INVENTORY_SLOTS, STACK_SIZE)
var suck_cooldown := 0
var hammer_cooldown := 0

# Aus Modifiers abgeleitete Werkzeugwerte
var suction_tier := 1
var hammer_tier := 1
var suck_range_px := BASE_SUCK_RANGE_PX
var hammer_range_px := BASE_HAMMER_RANGE_PX
var suck_interval := BASE_SUCK_INTERVAL
var hammer_interval := BASE_HAMMER_INTERVAL
var hammer_items := 1
var magnet_radius_px := 0


## Übernimmt die Boni. Liefert true, wenn sich das Inventar vergrößert hat.
func apply_modifiers(m: Dictionary) -> bool:
	suction_tier = int(m["suction_tier"])
	hammer_tier = int(m["hammer_tier"])
	var range_add: int = int(round(float(m["range_add"]) * TILE))
	suck_range_px = BASE_SUCK_RANGE_PX + range_add
	hammer_range_px = BASE_HAMMER_RANGE_PX + range_add
	var mine_mult: float = float(m["mine_speed_mult"])
	suck_interval = maxi(int(round(BASE_SUCK_INTERVAL * float(m["suck_interval_mult"]) / mine_mult)), 1)
	hammer_interval = maxi(int(round(BASE_HAMMER_INTERVAL / mine_mult)), 2)
	hammer_items = int(m["hammer_items"])
	magnet_radius_px = int(m["magnet_radius"]) * TILE
	var slots: int = INVENTORY_SLOTS + int(m["slots_add"])
	var stack: int = STACK_SIZE + int(m["stack_add"])
	if slots != inventory.slot_count or stack != inventory.stack_size:
		inventory.resize(slots, stack)
		return true
	return false
