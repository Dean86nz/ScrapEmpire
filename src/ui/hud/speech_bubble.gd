extends Node2D
## Sprechblase über Rusty. Zeigt einen Text 3 Sekunden, dreht sich nicht mit.

const SHOW_SECONDS := 3.0

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label
var _timer := 0.0


func _ready() -> void:
	_panel.visible = false
	EventBus.quip.connect(_on_quip)
	# Immer über allem in der Welt, nie mitrotieren (Elternteil ist der Player, nicht das Sprite).
	z_index = 50
	z_as_relative = false


func _on_quip(key: String) -> void:
	say(tr(key))


func say(text: String) -> void:
	_label.text = text
	_panel.visible = true
	_timer = SHOW_SECONDS
	# Panel zentriert über Rusty
	await get_tree().process_frame
	_panel.position = Vector2(-_panel.size.x / 2.0, -_panel.size.y)


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_panel.visible = false
