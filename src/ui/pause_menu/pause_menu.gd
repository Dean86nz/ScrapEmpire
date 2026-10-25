extends CanvasLayer
## Pause-Menü (Start / Esc): hält Spiel und Simulation an. Vollständig per Gamepad bedienbar:
## D-Pad/linker Stick wählt, A bestätigt, B oder Start schließt.
## Einträge: Fortsetzen, Sprache, Neues Spiel (mit Bestätigung), Speichern und Beenden.

signal opened
signal language_changed(locale: String)
signal new_game_requested
signal save_quit_requested

@onready var _title: Label = $Dim/Center/Panel/VBox/Title
@onready var _resume_btn: Button = $Dim/Center/Panel/VBox/ResumeButton
@onready var _language_btn: Button = $Dim/Center/Panel/VBox/LanguageButton
@onready var _new_game_btn: Button = $Dim/Center/Panel/VBox/NewGameButton
@onready var _quit_btn: Button = $Dim/Center/Panel/VBox/QuitButton

var _confirm_new_game := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title.text = tr("MENU_PAUSE_TITLE")
	_resume_btn.text = tr("MENU_RESUME")
	_new_game_btn.text = tr("MENU_NEW_GAME")
	_quit_btn.text = tr("MENU_SAVE_QUIT")
	_refresh_language_label()
	_resume_btn.pressed.connect(close)
	_language_btn.pressed.connect(_toggle_language)
	_new_game_btn.pressed.connect(_on_new_game)
	_quit_btn.pressed.connect(func() -> void: save_quit_requested.emit())


func _refresh_language_label() -> void:
	var loc := TranslationServer.get_locale().substr(0, 2)
	_language_btn.text = tr("MENU_LANGUAGE") % ("Deutsch" if loc == "de" else "English")


func _unhandled_input(event: InputEvent) -> void:
	# Esc ist auch „cancel“: im Baumodus/Baumenü schließt Esc zuerst diese, nicht das Spiel pausieren.
	if event is InputEventKey and not visible and InputRouter.context != InputRouter.Context.GAME:
		return
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and MenuInput.back_pressed(event):
		close()
		get_viewport().set_input_as_handled()
	elif visible and MenuInput.accept_pressed(event):
		if MenuInput.press_focused(get_viewport()):
			get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_confirm_new_game = false
	_new_game_btn.text = tr("MENU_NEW_GAME")
	get_tree().paused = true
	SimClock.paused = true
	InputRouter.context = InputRouter.Context.MENU
	_resume_btn.grab_focus()
	opened.emit()


func close() -> void:
	visible = false
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME


func _toggle_language() -> void:
	var loc := TranslationServer.get_locale().substr(0, 2)
	var next := "en" if loc == "de" else "de"
	language_changed.emit(next)


func _on_new_game() -> void:
	if not _confirm_new_game:
		_confirm_new_game = true
		_new_game_btn.text = tr("MENU_NEW_GAME_CONFIRM")
		return
	new_game_requested.emit()
