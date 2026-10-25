extends CanvasLayer
## MVP-Ende-Bildschirm: erscheint einmal, wenn alle Techknoten erforscht sind.
## Zeigt Kennzahlen, B oder A schließt. Das Spiel läuft danach normal weiter.

@onready var _title: Label = $Dim/Center/Panel/VBox/Title
@onready var _body: Label = $Dim/Center/Panel/VBox/Body
@onready var _close_btn: Button = $Dim/Center/Panel/VBox/CloseButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title.text = tr("END_TITLE")
	_close_btn.text = tr("END_CLOSE")
	_close_btn.pressed.connect(close)


func show_stats(world: SimWorld) -> void:
	var clean := 0
	for z in world.zones.summary(world.nodes):
		if int(z["stage"]) >= 3:
			clean += 1
	var minutes := world.tick_count / 20 / 60
	_body.text = tr("END_BODY") % [minutes, world.bolts, world.progression.level, world.helpers.size(), clean, world.zones.zones.size()]
	visible = true
	get_tree().paused = true
	SimClock.paused = true
	InputRouter.context = InputRouter.Context.MENU
	_close_btn.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		close()
		get_viewport().set_input_as_handled()
