extends Node2D
## Rustys Sprechblase (MS51, nach Vorgabe): eine Zeile, höchstens 25 % der Bildschirmbreite,
## 22 px auf dem Bildschirm (unabhängig vom Kamera-Zoom), leicht transparent, kleiner Zipfel,
## weich ein- und ausblenden, nach etwa 2 s weg. Zeigt nur, was Quips über EventBus.speak freigibt.

const MAX_SCREEN_FRAC := 0.25
const PAD_X := 12.0

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label
var _tail := Polygon2D.new()
var _timer := 0.0
var _tween: Tween


func _ready() -> void:
	_panel.visible = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tail.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 9)])
	_tail.color = Color(1.0, 0.99, 0.95, 0.88)
	_tail.visible = false
	add_child(_tail)
	EventBus.speak.connect(_on_speak)
	# Immer über allem in der Welt, nie mitrotieren (Elternteil ist der Player, nicht das Sprite).
	z_index = 50
	z_as_relative = false


func _on_speak(key: String, seconds: float) -> void:
	say(tr(key), seconds)


## Gegen den Kamera-Zoom skalieren: so ist die Blase auf dem Bildschirm immer gleich groß.
func _screen_scale() -> float:
	var z := get_viewport().get_canvas_transform().get_scale().x
	return 1.0 / maxf(z, 0.01)


func say(text: String, seconds: float = 2.0) -> void:
	var max_w := get_viewport().get_visible_rect().size.x * MAX_SCREEN_FRAC - 2.0 * PAD_X
	var font := _label.get_theme_font("font")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x
	_label.text = text
	_label.custom_minimum_size.x = minf(w + 2.0, max_w)
	_label.size.x = _label.custom_minimum_size.x
	_panel.size = Vector2.ZERO
	_panel.visible = true
	_tail.visible = true
	_timer = minf(seconds, 2.2)
	var base := _screen_scale()
	modulate.a = 0.0
	scale = Vector2.ONE * base * 0.9
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_property(self, "scale", Vector2.ONE * base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	_panel.position = Vector2(-_panel.size.x / 2.0, -_panel.size.y - 8.0)
	_tail.position = Vector2(0, _panel.position.y + _panel.size.y - 1.0)
	_tail.rotation = 0.0


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
