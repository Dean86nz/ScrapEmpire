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
var _warning := Label.new()
var _rescue := false

var _confirm_new := false
var _t := 0.0


func _ready() -> void:
	KenneySkin.apply($Center)  # einheitlicher Menü-Stil (MS54)
	InputRouter.context = InputRouter.Context.MENU
	_title.text = "Scrap Empire"
	_tagline.text = tr("TITLE_TAGLINE")
	# Versionsnummer unten rechts, damit beim Testen klar ist, welche EXE läuft
	var ver := Label.new()
	ver.text = "v" + str(ProjectSettings.get_setting("application/config/version", "?")) + (" · DEBUG" if OS.is_debug_build() else "")
	ver.add_theme_font_size_override("font_size", 22)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	ver.anchor_left = 1.0
	ver.anchor_top = 1.0
	ver.anchor_right = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -360
	ver.offset_top = -52
	ver.offset_right = -24
	ver.offset_bottom = -16
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	_continue_btn.text = tr("TITLE_CONTINUE")
	_new_btn.text = tr("TITLE_NEW")
	_quit_btn.text = tr("TITLE_QUIT")
	_refresh_lang()
	_continue_btn.visible = SaveManager.has_save()
	_warning.name = "Warning"
	_warning.add_theme_font_size_override("font_size", 26)
	_warning.add_theme_color_override("font_color", Color(0.6, 0.2, 0.15))
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size = Vector2(520, 0)
	_warning.visible = false
	$Center/VBox.add_child(_warning)
	$Center/VBox.move_child(_warning, _tagline.get_index() + 1)
	if SaveManager.has_only_old_saves():
		# Kurswechsel MS20: alte Fabrik-Spielstände passen nicht mehr; sichern statt löschen.
		SaveManager.archive_all()
		SaveManager.log_step("Titel: alter Spielstand gesichert (Version zu alt)")
		_warning.text = tr("TITLE_OLD_SAVE")
		_warning.visible = true
		_continue_btn.visible = false
	elif not SaveManager.failed_load().is_empty():
		_setup_rescue()
	_continue_btn.pressed.connect(_on_continue)
	_new_btn.pressed.connect(_new_game)
	_lang_btn.pressed.connect(_toggle_lang)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	(_continue_btn if _continue_btn.visible else _new_btn).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if MenuInput.accept_pressed(event):
		MenuInput.press_focused(get_viewport())


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
	var st := SaveManager.load_settings()
	st["locale"] = next
	SaveManager.save_settings(st)
	TranslationServer.set_locale(next)
	get_tree().reload_current_scene()


## Das letzte Laden ist abgestürzt: Backup anbieten (falls vorhanden) oder sicher neu beginnen.
func _setup_rescue() -> void:
	_rescue = true
	SaveManager.log_step("Titel: letztes Laden nicht beendet, Rettung angeboten (%s)" % str(SaveManager.failed_load()))
	_warning.text = tr("TITLE_LOAD_FAILED")
	_warning.visible = true
	_continue_btn.visible = SaveManager.backup_file() != ""
	_continue_btn.text = tr("TITLE_LOAD_BACKUP")
	_new_btn.text = tr("TITLE_FRESH_SAFE")


func _on_continue() -> void:
	if _rescue:
		SaveManager.use_backup()
	_start()


func _new_game() -> void:
	if _rescue:
		SaveManager.archive_all()
		_start()
		return
	if SaveManager.has_save() and not _confirm_new:
		_confirm_new = true
		_new_btn.text = tr("MENU_NEW_GAME_CONFIRM")
		return
	SaveManager.delete_all()
	_start()


func _start() -> void:
	InputRouter.context = InputRouter.Context.GAME
	get_tree().change_scene_to_file(MAIN_SCENE)
