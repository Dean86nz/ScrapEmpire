class_name WorkerBody
extends RefCounted
## Gemeinsame Sim-Sicht auf einen arbeitenden Roboter (Helfer; Rusty teilt die Werkzeugwerte):
## Position und Eingaben, die eine WorkerBrain setzt, plus Werkzeugwerte.

const TILE := 64

var pos := Vector2i.ZERO
var aim := Vector2.RIGHT
var suck_held := false
var hammer_pressed := false

## Vom Gehirn gesetzt, vom Node ausgeführt: Zielposition in Pixeln (oder NONE_TARGET).
const NONE_TARGET := Vector2i(-999999, -999999)
var move_target := NONE_TARGET

var inventory := Inventory.new(6, 20)
var suction_tier := 1
var hammer_tier := 1
var suck_range_px := 160
var hammer_range_px := 64


func has_move_target() -> bool:
	return move_target != NONE_TARGET
