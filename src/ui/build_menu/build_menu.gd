extends CanvasLayer
## Baumenü (Y): Liste aller baubaren Gebäude mit Kosten plus „Abreißen“. Fokusnavigation.

signal build_selected(def_id: String)
signal demolish_selected
signal closed

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _list: VBoxContainer = $Center/Panel/VBox/List

var _buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	_title.text = tr("MENU_BUILD_TITLE")


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
	for def_id in DataRegistry.building_defs:
		var def: BuildingDef = DataRegistry.building_defs[def_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(520, 76)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = load(def.sprite)
		btn.expand_icon = true
		btn.text = "%s   –   %s" % [tr(def.name_key), _cost_text(w.next_cost(def))]
		if not Economy.can_afford(w.player.inventory, w.next_cost(def)):
			btn.add_theme_color_override("font_color", Color(0.6, 0.25, 0.2))
		btn.pressed.connect(func() -> void: _choose(def_id))
		_list.add_child(btn)
		_buttons.append(btn)
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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("build_menu"):
		close()
		get_viewport().set_input_as_handled()
