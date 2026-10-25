extends CanvasLayer
## Baumenü (Y): Liste aller baubaren Gebäude mit Kosten plus „Abreißen“. Fokusnavigation.

signal build_selected(def_id: String)
signal demolish_selected
signal closed

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _list: VBoxContainer = $Center/Panel/VBox/List
var _inventory_hint := Label.new()

var _buttons: Array[Button] = []
var _page := 0  # 0 Gebäude, 1 Deko


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


func _decor_available() -> bool:
	return SimClock.world.unlocked_features.has("decor")


func open() -> void:
	if not _decor_available():
		_page = 0
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
	var pages := _decor_available()
	var any_missing := false
	_title.text = tr("BUILD_PAGE_DECOR") if _page == 1 else tr("MENU_BUILD_TITLE")
	if pages:
		_title.text = "◀ LB   %s   RB ▶" % _title.text
	for def_id in DataRegistry.building_defs:
		if not w.is_building_unlocked(def_id):
			continue
		var def: BuildingDef = DataRegistry.building_defs[def_id]
		if (def.category == "decor") != (_page == 1):
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(520, 76)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = load(def.sprite)
		btn.expand_icon = true
		var makes := ""
		var outputs: Array[String] = []
		for r in w.available_recipes(def.id):
			outputs.append(DataRegistry.item_name(r.output_item))
		if not outputs.is_empty():
			makes = "   (%s %s)" % [tr("BUILD_MAKES"), ", ".join(outputs)]
		btn.text = "%s   –   %s%s" % [tr(def.name_key), _cost_text(w.next_cost(def)), makes]
		if not Economy.can_afford(w.player.inventory, w.next_cost(def)):
			any_missing = true
			btn.text += "   (%s)" % (tr("BUILD_MISSING") % _missing_text(w.next_cost(def), w.player.inventory))
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


## „fehlt: 12 Eisenbarren, 3 Kupfer“ – nur Rustys Inventar zählt.
func _missing_text(cost: Dictionary, inv: Inventory) -> String:
	var parts: Array[String] = []
	for item in cost:
		var missing := int(cost[item]) - inv.count_of(str(item))
		if missing > 0:
			parts.append("%d %s" % [missing, DataRegistry.item_name(str(item))])
	return ", ".join(parts)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item in cost:
		parts.append("%d %s" % [cost[item], DataRegistry.item_name(item)])
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
		if MenuInput.press_focused(get_viewport()):
			get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("hotbar_next") or event.is_action_pressed("hotbar_prev")) and _decor_available():
		_page = 1 - _page
		_rebuild()
		if not _buttons.is_empty():
			_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()
