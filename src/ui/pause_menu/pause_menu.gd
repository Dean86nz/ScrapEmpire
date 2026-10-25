extends CanvasLayer
## Pause-Menü (Start / Esc): hält Spiel und Simulation an. Vollständig per Gamepad bedienbar:
## D-Pad/linker Stick wählt, A bestätigt, B oder Start schließt.

@onready var _title: Label = $Dim/Center/Panel/VBox/Title
@onready var _resume_btn: Button = $Dim/Center/Panel/VBox/ResumeButton
@onready var _quit_btn: Button = $Dim/Center/Panel/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title.text = tr("MENU_PAUSE_TITLE")
	_resume_btn.text = tr("MENU_RESUME")
	_quit_btn.text = tr("MENU_QUIT")
	_resume_btn.pressed.connect(close)
	_quit_btn.pressed.connect(_quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	SimClock.paused = true
	InputRouter.context = InputRouter.Context.MENU
	_resume_btn.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME


func _quit() -> void:
	# Autosave kommt in MS6; bis dahin einfach beenden.
	get_tree().quit()
