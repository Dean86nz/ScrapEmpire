extends CanvasLayer
## Entwickler-Overlay (F3): FPS, Tick-Zeit, Tick-Zähler, Item-Anzahl, Eingabegerät.

@onready var _label: Label = $Label

var item_count := 0


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var w := SimClock.world
	var belt_items := 0
	_label.text = "FPS %d\nTick %.2f ms\nTicks %d\nItems %d (Band %d)\n%s\nSauger T%d  Hammer T%d\nXP %d\nHelfer %d" % [
		Engine.get_frames_per_second(),
		SimClock.last_tick_ms,
		w.tick_count,
		w.loose.size() + belt_items + item_count,
		belt_items,
		"Gamepad" if InputRouter.is_gamepad else "Tastatur/Maus",
		w.player.suction_tier, w.player.hammer_tier,
		w.progression.total_xp,
		w.helpers.size(),
	]
