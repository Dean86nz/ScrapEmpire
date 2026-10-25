class_name TickAccumulator
extends RefCounted
## Fixed-Step-Akkumulator: wandelt variable Frame-Zeiten in eine Anzahl
## fälliger Simulations-Ticks (20/s). alpha ist der Interpolationsfaktor
## zwischen letztem und nächstem Tick für die Darstellung.

const TICK_DT := 0.05
const MAX_FRAME_DT := 0.25  # Spiralschutz: nach einem Ruckler max. 5 Ticks nachholen
const EPSILON := 0.000001

var alpha := 0.0
var _accumulator := 0.0


func advance(delta: float) -> int:
	_accumulator += minf(delta, MAX_FRAME_DT)
	var ticks := 0
	while _accumulator >= TICK_DT - EPSILON:
		_accumulator -= TICK_DT
		ticks += 1
	if _accumulator < 0.0:
		_accumulator = 0.0
	alpha = _accumulator / TICK_DT
	return ticks
