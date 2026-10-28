extends CanvasLayer
## Baumenü (Y): Liste aller baubaren Gebäude mit Kosten plus „Abreißen“. Fokusnavigation.

signal build_selected(def_id: String)
signal demolish_selected
signal closed

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _list: VBoxContainer = $Center/Panel/VBox/List
var _inventory_hint := Label.new()

var _buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	_title.text = tr("MENU_BUILD_TITLE")
	_inventory_hint.text = tr("BUILD_INVENTORY_ONLY")
	_inventory_hint.add_theme_font_size_override("font_size", 22)
	_inventory_hint.add_theme_color_override("font_color", Color(0.6, 0.25, 0.2))
	_inventory_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_hint.visible = false
	_title.get_parent().add_child(_inventory_hint)
	_title.get_parent().move_child(_inventory_hint, _title.get_index() + 1)


## Gibt es überhaupt etwas zu bauen? (zu Spielbeginn nicht: Deko kommt mit Schiffsstufe 3)
func has_entries() -> bool:
	var w := SimClock.world
	for def_id in DataRegistry.building_defs:
		var def: BuildingDef = DataRegistry.building_defs[def_id]
		if def.buildable and w.is_building_unlocked(def_id):
			return true
	return false


func open() -> void:
	_rebuild()
	visible = true
	InputRouter.context = InputRouter.Context.MENU
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func close() -> void:
	visible = false
	InputRouter.context = InputRouter.Context.GAME
	closed.emit()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_buttons.clear()
	var w := SimClock.world
	var any_missing := false
	_title.text = tr("MENU_BUILD_TITLE")
	for def_id in DataRegistry.building_defs:
		if not w.is_building_unlocked(def_id):
			continue
		var def: BuildingDef = DataRegistry.building_defs[def_id]
		if not def.buildable:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(520, 76)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = load(def.sprite)
		btn.expand_icon = true
		btn.text = "%s   –   %s" % [tr(def.name_key), _cost_text(w.next_cost(def))]
		if not w.can_afford(w.next_cost(def)):
			any_missing = true
			btn.text += "   (%s)" % (tr("BUILD_MISSING") % _missing_text(w.missing_for(w.next_cost(def))))
			btn.add_theme_color_override("font_color", Color(0.6, 0.25, 0.2))
			btn.self_modulate = Color(0.82, 0.82, 0.82)
		btn.pressed.connect(func() -> void: _choose(def_id))
		_list.add_child(btn)
		_buttons.append(btn)
	_inventory_hint.visible = any_missing
	var demolish := Button.new()
	demolish.custom_minimum_size = Vector2(520, 76)
	demolish.alignment = HORIZONTAL_ALIGNMENT_LEFT
	demolish.text = "✖   " + tr("MENU_DEMOLISH")
	demolish.pressed.connect(_choose_demolish)
	_list.add_child(demolish)
	_buttons.append(demolish)
	# Fokus-Kette: oben/unten zyklisch.
	for i in _buttons.size():
		var prev := _buttons[(i - 1 + _buttons.size()) % _buttons.size()]
		var next := _buttons[(i + 1) % _buttons.size()]
		_buttons[i].focus_neighbor_top = _buttons[i].get_path_to(prev)
		_buttons[i].focus_neighbor_bottom = _buttons[i].get_path_to(next)


## „fehlt: 12 Eisenbarren, 3 Kupfer“ – Inventar und Schiffslager zählen, Kisten nicht.
func _missing_text(missing: Dictionary) -> String:
	var parts: Array[String] = []
	for item in missing:
		parts.append("%d %s" % [int(missing[item]), DataRegistry.item_name(str(item))])
	return ", ".join(parts)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item in cost:
		parts.append("%s %s" % [Fmt.int_str(int(cost[item])), tr("HUD_BOLTS") if str(item) == "bolts" else DataRegistry.item_name(item)])
	return ", ".join(parts)


func _choose(def_id: String) -> void:
	visible = false
	build_selected.emit(def_id)


func _choose_demolish() -> void:
	visible = false
	demolish_selected.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if MenuInput.back_pressed(event) or event.is_action_pressed("build_menu"):
		close()
		get_viewport().set_input_as_handled()
	elif MenuInput.accept_pressed(event):
		MenuInput.press_focused(get_viewport())

