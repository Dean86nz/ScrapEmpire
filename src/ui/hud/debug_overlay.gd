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
	_label.text = "FPS %d\nTick %.2f ms\nTicks %d\nItems %d\n%s" % [
		Engine.get_frames_per_second(),
		SimClock.last_tick_ms,
		SimClock.world.tick_count,
		item_count,
		"Gamepad" if InputRouter.is_gamepad else "Tastatur/Maus",
	]
