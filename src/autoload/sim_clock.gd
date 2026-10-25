extends Node
## Treibt die Simulation mit festen 20 Ticks/s, entkoppelt vom Rendering.
## Die Darstellung liest `alpha` für Interpolation zwischen zwei Ticks.

var world: SimWorld = SimWorld.new()
var paused := false
var last_tick_ms := 0.0
var alpha := 0.0
var _acc := TickAccumulator.new()


func _process(delta: float) -> void:
	if paused:
		return
	var ticks := _acc.advance(delta)
	for i in ticks:
		var t0 := Time.get_ticks_usec()
		world.tick()
		last_tick_ms = (Time.get_ticks_usec() - t0) / 1000.0
		EventBus.tick_done.emit(world.tick_count)
	alpha = _acc.alpha
