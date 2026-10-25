class_name PlayerState
extends RefCounted
## Sim-Sicht auf Rusty: Position und Eingaben (vom Player-Node pro Frame geschrieben),
## Inventar und Werkzeug-Cooldowns (von der Sim im Tick verwaltet).

const SUCK_RANGE_PX := 160          # 2,5 Kacheln
const SUCK_HALF_ANGLE_RAD := PI / 4 # Kegel 90°
const SUCK_INTERVAL := 5            # 1 Item / 0,25 s
const HAMMER_RANGE_PX := 64         # 1 Kachel
const HAMMER_REACH_PX := 48         # Zielpunkt vor Rusty
const HAMMER_INTERVAL := 10         # 1 Schlag / 0,5 s
const INVENTORY_SLOTS := 6
const STACK_SIZE := 20

# Eingaben (werden vom Player-Node gesetzt)
var pos := Vector2i.ZERO
var aim := Vector2.RIGHT
var suck_held := false
var hammer_pressed := false

# Zustand (von der Sim verwaltet)
var inventory := Inventory.new(INVENTORY_SLOTS, STACK_SIZE)
var suck_cooldown := 0
var hammer_cooldown := 0
