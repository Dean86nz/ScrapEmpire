class_name OfflineSummary
extends CanvasLayer
## „Willkommen zurück“ (MS81): zeigt nach dem Laden, was die Bot-Armee in der Abwesenheit
## geschafft hat. A oder B schließt. Rein Darstellung.

signal closed

const INK := Color(0.165, 0.165, 0.2)

var _panel := PanelContainer.new()


func show_summary(r: Dictionary) -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# Heller Kartenstil wie die Hinweis-Karten (Theme greift auf einer eigenen Ebene nicht)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.97, 0.88)
	sb.border_color = INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 28
	sb.content_margin_bottom = 24
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	var title := Label.new()
	title.text = tr("OFFLINE_TITLE")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var secs := int(r.get("seconds", 0))
	var lines: Array[String] = []
	lines.append(tr("OFFLINE_TIME") % [secs / 3600, (secs / 60) % 60])
	lines.append(tr("OFFLINE_TRASH") % Fmt.int_str(int(r.get("trash", 0))))
	lines.append(tr("OFFLINE_BOLTS") % Fmt.int_str(int(r.get("bolts", 0))))
	for z: Array in r.get("zones", []):
		lines.append(tr("OFFLINE_ZONE") % [str(z[0]), int(float(z[2]) * 100.0)])
	if secs >= OfflineSystem.MAX_S:
		lines.append(tr("OFFLINE_CAP"))
	for t in lines:
		var l := Label.new()
		l.text = t
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var hint := Label.new()
	hint.text = tr("OFFLINE_CLOSE")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	InputRouter.context = InputRouter.Context.MENU
	Sfx.play("milestone", 0.0, -4.0)
	_panel.scale = Vector2(0.9, 0.9)
	_panel.pivot_offset = Vector2(300, 150)
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if MenuInput.accept_pressed(event) or MenuInput.back_pressed(event):
		get_viewport().set_input_as_handled()
		InputRouter.context = InputRouter.Context.GAME
		closed.emit()
		queue_free()
