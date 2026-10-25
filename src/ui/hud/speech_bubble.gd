extends Node2D
## Sprechblase über Rusty. Zeigt einen Text 3 Sekunden, dreht sich nicht mit.

const SHOW_SECONDS := 3.0

## true: zeigt Rustys globale Sprüche (EventBus.quip); false: nur eigene say()-Aufrufe (Helfer).
var listen_global := true

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label
var _timer := 0.0


func _ready() -> void:
	_panel.visible = false
	if listen_global:
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
	# Panel zentriert über dem Sprecher; am oberen Bildrand stattdessen darunter.
	await get_tree().process_frame
	_panel.position = Vector2(-_panel.size.x / 2.0, -_panel.size.y)
	var screen_pos := get_viewport().get_canvas_transform() * (global_position + _panel.position)
	if screen_pos.y < 140.0:
		_panel.position.y = 110.0
	var vp_w := get_viewport().get_visible_rect().size.x
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var left := (get_viewport().get_canvas_transform() * (global_position + _panel.position)).x
	var right := left + _panel.size.x * zoom
	if left < 16.0:
		_panel.position.x += (16.0 - left) / zoom
	elif right > vp_w - 16.0:
		_panel.position.x -= (right - (vp_w - 16.0)) / zoom


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_panel.visible = false
