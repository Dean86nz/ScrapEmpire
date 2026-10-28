extends Node
## Treibt die Simulation mit festen 20 Ticks/s, entkoppelt vom Rendering.
## Die Darstellung liest `alpha` für Interpolation zwischen zwei Ticks.

var world: SimWorld = SimWorld.new()
var paused := false
var speed := 1.0   # Cheat „Zeit ×10“ (nur Debug-Build)
var last_tick_ms := 0.0
var alpha := 0.0
var _acc := TickAccumulator.new()


## Ersetzt die Welt (beim Laden einer Karte oder eines Spielstands).
func reset_world(new_world: SimWorld) -> void:
	world = new_world
	_acc = TickAccumulator.new()
	last_tick_ms = 0.0
	alpha = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	var ticks := _acc.advance(delta * speed)
	for i in ticks:
		var t0 := Time.get_ticks_usec()
		world.tick()
		last_tick_ms = (Time.get_ticks_usec() - t0) / 1000.0
		EventBus.tick_done.emit(world.tick_count)
	alpha = _acc.alpha
