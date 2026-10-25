extends Control
## Titelbildschirm: Weiterspielen (wenn Spielstand), Neues Spiel, Sprache, Beenden.

const MAIN_SCENE := "res://src/world/main.tscn"

@onready var _continue_btn: Button = $Center/VBox/ContinueButton
@onready var _new_btn: Button = $Center/VBox/NewButton
@onready var _lang_btn: Button = $Center/VBox/LangButton
@onready var _quit_btn: Button = $Center/VBox/QuitButton
@onready var _tagline: Label = $Center/VBox/Tagline
@onready var _title: Label = $Center/VBox/Title
@onready var _rusty: Sprite2D = $Rusty

var _confirm_new := false
var _t := 0.0


func _ready() -> void:
	InputRouter.context = InputRouter.Context.MENU
	_title.text = "Scrap Empire"
	_tagline.text = tr("TITLE_TAGLINE")
	_continue_btn.text = tr("TITLE_CONTINUE")
	_new_btn.text = tr("TITLE_NEW")
	_quit_btn.text = tr("TITLE_QUIT")
	_refresh_lang()
	_continue_btn.visible = SaveManager.has_save()
	_continue_btn.pressed.connect(_start)
	_new_btn.pressed.connect(_new_game)
	_lang_btn.pressed.connect(_toggle_lang)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	(_continue_btn if _continue_btn.visible else _new_btn).grab_focus()


func _process(delta: float) -> void:
	_t += delta
	_rusty.rotation = sin(_t * 1.5) * 0.08
	_rusty.position.y = 560 + sin(_t * 2.0) * 6.0


func _refresh_lang() -> void:
	var loc := TranslationServer.get_locale().substr(0, 2)
	_lang_btn.text = tr("MENU_LANGUAGE") % ("Deutsch" if loc == "de" else "English")


func _toggle_lang() -> void:
	var loc := TranslationServer.get_locale().substr(0, 2)
	var next := "en" if loc == "de" else "de"
	SaveManager.save_settings({"locale": next})
	TranslationServer.set_locale(next)
	get_tree().reload_current_scene()


func _new_game() -> void:
	if SaveManager.has_save() and not _confirm_new:
		_confirm_new = true
		_new_btn.text = tr("MENU_NEW_GAME_CONFIRM")
		return
	SaveManager.delete_all()
	_start()


func _start() -> void:
	InputRouter.context = InputRouter.Context.GAME
	get_tree().change_scene_to_file(MAIN_SCENE)
