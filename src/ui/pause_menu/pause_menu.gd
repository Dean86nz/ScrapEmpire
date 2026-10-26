extends CanvasLayer
## Pause-Menü (Start / Esc): hält Spiel und Simulation an. Vollständig per Gamepad bedienbar:
## D-Pad/linker Stick wählt, A bestätigt, B oder Start schließt.
## Einträge: Fortsetzen, Musik, Effekte, Sprache, Neues Spiel (mit Bestätigung), Speichern und Beenden.
## Musik und Effekte: D-Pad links/rechts (oder A) ändert die Lautstärke in 10-%-Schritten.

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
var _music_btn := Button.new()
var _sfx_btn := Button.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title.text = tr("MENU_PAUSE_TITLE")
	_resume_btn.text = tr("MENU_RESUME")
	_new_game_btn.text = tr("MENU_NEW_GAME")
	_quit_btn.text = tr("MENU_SAVE_QUIT")
	_refresh_language_label()
	var box := _resume_btn.get_parent()
	for b: Button in [_music_btn, _sfx_btn]:
		b.custom_minimum_size = _resume_btn.custom_minimum_size
		box.add_child(b)
		box.move_child(b, _language_btn.get_index())
	# Links/rechts direkt am Regler abfangen (sonst verbraucht die Fokus-Navigation die Taste)
	for pair in [[_music_btn, "music"], [_sfx_btn, "sfx"]]:
		var btn: Button = pair[0]
		var kind: String = pair[1]
		btn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
				_step_volume(kind, 0.1 if ev.is_action_pressed("ui_right") else -0.1, false)
				btn.accept_event())
	_music_btn.pressed.connect(func() -> void: _step_volume("music", 0.1, true))
	_sfx_btn.pressed.connect(func() -> void: _step_volume("sfx", 0.1, true))
	_refresh_volume_labels()
	# Reihenfolge für D-Pad hoch/runter (im Kreis), auch über die neuen Regler
	var order: Array[Button] = [_resume_btn, _music_btn, _sfx_btn, _language_btn, _new_game_btn, _quit_btn]
	for i in order.size():
		order[i].focus_neighbor_top = order[i].get_path_to(order[(i - 1 + order.size()) % order.size()])
		order[i].focus_neighbor_bottom = order[i].get_path_to(order[(i + 1) % order.size()])
		order[i].focus_neighbor_left = NodePath(".")
		order[i].focus_neighbor_right = NodePath(".")
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
		MenuInput.press_focused(get_viewport())


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


## A springt im Kreis (100 % → 0 %), links/rechts geht schrittweise.
func _step_volume(kind: String, delta: float, wrap: bool) -> void:
	var v := float(Sfx.volume[kind]) + delta
	if wrap and v > 1.001:
		v = 0.0
	Sfx.set_volume(kind, snappedf(clampf(v, 0.0, 1.0), 0.1))
	Sfx.save_volume()
	_refresh_volume_labels()
	if kind == "sfx":
		Sfx.play("plop", 0.0)


func _refresh_volume_labels() -> void:
	_music_btn.text = tr("MENU_VOL_MUSIC") % _bar(float(Sfx.volume["music"]))
	_sfx_btn.text = tr("MENU_VOL_SFX") % _bar(float(Sfx.volume["sfx"]))


func _bar(v: float) -> String:
	var n := int(round(v * 10.0))
	return "◀ " + "■".repeat(n) + "□".repeat(10 - n) + " ▶"


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
