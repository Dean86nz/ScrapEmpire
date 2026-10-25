extends CanvasLayer
## Aufgaben-Editor (Y lang / L): Liste der Autopilot-Schritte. D-Pad wählt, A öffnet
## „Schritt hinzufügen“ (Typ wählen, dann Ziel per Cursor), X löscht, LB/RB verschiebt,
## Start/Stopp-Knopf, B schließt.

signal target_requested(type: int)
signal closed

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _list: VBoxContainer = $Center/Panel/VBox/List
@onready var _add_btn: Button = $Center/Panel/VBox/Buttons/AddButton
@onready var _start_btn: Button = $Center/Panel/VBox/Buttons/StartButton
@onready var _clear_btn: Button = $Center/Panel/VBox/Buttons/ClearButton
@onready var _type_box: VBoxContainer = $Center/Panel/VBox/TypeBox
@onready var _footer: Label = $Center/Panel/VBox/Footer

var _tasks: TaskList
var _world: SimWorld
var _step_buttons: Array[Button] = []
var _choosing_type := false


func _ready() -> void:
	visible = false
	_title.text = tr("TASK_TITLE")
	_add_btn.text = tr("TASK_ADD")
	_clear_btn.text = tr("TASK_CLEAR")
	_footer.text = tr("TASK_FOOTER")
	_add_btn.pressed.connect(_show_types)
	_start_btn.pressed.connect(_toggle_start)
	_clear_btn.pressed.connect(func() -> void: _tasks.clear(); _rebuild())
	for t in TaskList.Type.values():
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 64)
		b.text = "%s  %s" % [TaskList.type_icon(t), tr(TaskList.type_name(t))]
		b.pressed.connect(func() -> void: _pick_type(t))
		_type_box.add_child(b)
	_type_box.visible = false


func bind(world: SimWorld) -> void:
	_world = world
	_tasks = world.tasks
	_tasks.changed.connect(_rebuild)
	_tasks.state_changed.connect(func(_a: bool) -> void: _refresh_start())


func open() -> void:
	visible = true
	_choosing_type = false
	_type_box.visible = false
	InputRouter.context = InputRouter.Context.MENU
	_rebuild()
	_focus_first()


func close() -> void:
	visible = false
	InputRouter.context = InputRouter.Context.GAME
	closed.emit()


func _focus_first() -> void:
	if not _step_buttons.is_empty():
		_step_buttons[0].grab_focus()
	else:
		_add_btn.grab_focus()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_step_buttons.clear()
	for i in _tasks.steps.size():
		var s: Dictionary = _tasks.steps[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(640, 60)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var marker := "▶ " if (_tasks.active and i == _tasks.index) else "   "
		b.text = "%s%d. %s %s  (%d, %d)" % [marker, i + 1, TaskList.type_icon(int(s["type"])), tr(TaskList.type_name(int(s["type"]))), s["tile"].x, s["tile"].y]
		_list.add_child(b)
		_step_buttons.append(b)
	if _tasks.steps.is_empty():
		var hint := Label.new()
		hint.text = tr("TASK_EMPTY")
		hint.add_theme_font_size_override("font_size", 24)
		hint.add_theme_color_override("font_color", Color(0.3, 0.3, 0.36))
		_list.add_child(hint)
	_refresh_start()


func _refresh_start() -> void:
	_start_btn.text = tr("TASK_STOP") if _tasks.active else tr("TASK_START")
	_start_btn.disabled = _tasks.steps.is_empty()


func _show_types() -> void:
	_choosing_type = true
	_type_box.visible = true
	(_type_box.get_child(0) as Button).grab_focus()


func _pick_type(t: int) -> void:
	_choosing_type = false
	_type_box.visible = false
	visible = false
	target_requested.emit(t)


## Vom Cursor: Ziel gewählt (oder abgebrochen) → Editor wieder zeigen.
func on_target_result(type: int, tile: Vector2i, ok: bool) -> void:
	if ok:
		_tasks.add_step(type as TaskList.Type, tile)
	open()
	if ok and not _step_buttons.is_empty():
		_step_buttons.back().grab_focus()


func _toggle_start() -> void:
	if _tasks.active:
		_tasks.interrupt(_world.player)
	else:
		if _tasks.start(_world.player):
			Quips.say("autopilot_start", true)
			close()
	_rebuild()


func _focused_index() -> int:
	var f := get_viewport().gui_get_focus_owner()
	return _step_buttons.find(f) if f is Button else -1


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if MenuInput.accept_pressed(event):
		if MenuInput.press_focused(get_viewport()):
			get_viewport().set_input_as_handled()
		return
	if MenuInput.back_pressed(event) or event.is_action_pressed("build_menu") or event.is_action_pressed("task_menu"):
		if _choosing_type:
			_choosing_type = false
			_type_box.visible = false
			_add_btn.grab_focus()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	var i := _focused_index()
	if i < 0:
		return
	if event.is_action_pressed("tool_swap"):
		_tasks.remove_step(i)
		_rebuild()
		if not _step_buttons.is_empty():
			_step_buttons[mini(i, _step_buttons.size() - 1)].grab_focus()
		else:
			_add_btn.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_prev"):
		_tasks.move_step(i, -1)
		_rebuild()
		_step_buttons[maxi(i - 1, 0)].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_next"):
		_tasks.move_step(i, 1)
		_rebuild()
		_step_buttons[mini(i + 1, _step_buttons.size() - 1)].grab_focus()
		get_viewport().set_input_as_handled()
