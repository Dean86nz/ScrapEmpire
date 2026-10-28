extends Node2D
## Rustys Sprechblase (MS44): klein, rund, mit Schatten und Zipfel, blendet weich ein und aus.
## Zeigt nur, was Quips über EventBus.speak freigibt; eine neue Blase ersetzt die alte.

const MAX_TEXT_W := 520.0

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label
var _tail := Polygon2D.new()
var _timer := 0.0
var _tween: Tween


func _ready() -> void:
	_panel.visible = false
	_tail.polygon = PackedVector2Array([Vector2(-10, -2), Vector2(10, -2), Vector2(0, 14)])
	_tail.color = Color(1.0, 0.99, 0.95)
	_tail.visible = false
	add_child(_tail)
	EventBus.speak.connect(_on_speak)
	# Immer über allem in der Welt, nie mitrotieren (Elternteil ist der Player, nicht das Sprite).
	z_index = 50
	z_as_relative = false


func _on_speak(key: String, seconds: float) -> void:
	say(tr(key), seconds)


func say(text: String, seconds: float = 3.2) -> void:
	_label.text = text
	var font := _label.get_theme_font("font")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x
	_label.custom_minimum_size.x = minf(w + 2.0, MAX_TEXT_W)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > MAX_TEXT_W else TextServer.AUTOWRAP_OFF
	_panel.size = Vector2.ZERO
	_panel.visible = true
	_tail.visible = true
	_timer = seconds
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Panel zentriert über dem Sprecher; am oberen Bildrand stattdessen darunter.
	await get_tree().process_frame
	_panel.position = Vector2(-_panel.size.x / 2.0, -_panel.size.y - 12.0)
	_tail.position = Vector2(0, -14)
	_tail.rotation = 0.0
	var screen_pos := get_viewport().get_canvas_transform() * (global_position + _panel.position)
	if screen_pos.y < 140.0:
		_panel.position.y = 110.0
		_tail.position = Vector2(0, 112)
		_tail.rotation = PI
	var vp_w := get_viewport().get_visible_rect().size.x
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var left := (get_viewport().get_canvas_transform() * (global_position + _panel.position)).x
	var right := left + _panel.size.x * zoom
	if left < 16.0:
		_panel.position.x += (16.0 - left) / zoom
	elif right > vp_w - 16.0:
		_panel.position.x -= (right - (vp_w - 16.0)) / zoom


func _process(delta: float) -> void:
	if not _panel.visible or _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, 0.3)
		_tween.tween_callback(func() -> void:
			_panel.visible = false
			_tail.visible = false)
