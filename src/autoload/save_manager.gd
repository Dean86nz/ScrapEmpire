extends Node
## Spielstände: zwei rotierende JSON-Dateien plus Meta-Datei, damit ein Absturz beim
## Schreiben nie den letzten gültigen Stand zerstört. Migrationen heben alte Versionen an.
## Außerdem Einstellungen (Sprache) in user://settings.json.

const DEFAULT_SAVE_DIR := "user://saves/"
const SLOTS := ["save_a.json", "save_b.json"]
const SETTINGS_FILE := "user://settings.json"
## Steht während des Ladens; wird erst nach erfolgreichem Start gelöscht. Existiert sie beim
## nächsten Start noch, ist das letzte Laden abgestürzt und der Titel bietet die Rettung an.
const GUARD_FILE := "load_guard.json"

## Tests setzen einen eigenen Ordner, damit sie nie den echten Spielstand berühren.
var _shake_cache := -1   # -1 = noch nicht gelesen
var save_dir := DEFAULT_SAVE_DIR
var meta_file := DEFAULT_SAVE_DIR + "save_meta.json"

## version → Callable(data) -> data (hebt genau um eine Version)
var migrations: Dictionary = SaveMigrations.all()

var _last_written := ""
var last_read_file := ""   # Datei, aus der read() zuletzt geladen hat
var skip_file := ""        # Rettung „Backup laden“: diese Datei beim Lesen überspringen


func use_directory(dir: String) -> void:
	save_dir = dir
	meta_file = dir + "save_meta.json"
	DirAccess.make_dir_recursive_absolute(save_dir)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	# Sprache: gespeicherte Einstellung, sonst Deutsch bei deutschem System, sonst Englisch.
	var locale := str(load_settings().get("locale", ""))
	if locale == "":
		locale = "de" if OS.get_locale_language() == "de" else "en"
	TranslationServer.set_locale(locale)


# --- Spielstand -------------------------------------------------------------

func has_save() -> bool:
	return _latest_file() != ""


func latest_file_name() -> String:
	return _latest_file()


## Protokollzeile fürs Log (wird dank flush_stdout_on_print sofort geschrieben).
static func log_step(msg: String) -> void:
	print("[Laden %6d ms] %s" % [Time.get_ticks_msec(), msg])


func begin_load(file: String) -> void:
	var g := failed_load()
	var f := FileAccess.open(save_dir + GUARD_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"file": file, "attempts": int(g.get("attempts", 0)) + 1}))
		f.close()


func end_load() -> void:
	if FileAccess.file_exists(save_dir + GUARD_FILE):
		DirAccess.remove_absolute(save_dir + GUARD_FILE)


## Nicht leer, wenn das letzte Laden nie fertig wurde: {file, attempts}.
func failed_load() -> Dictionary:
	return _read_file(save_dir + GUARD_FILE)


## Der andere, ältere Spielstand, falls vorhanden und lesbar ("" sonst).
func backup_file() -> String:
	var bad := str(failed_load().get("file", ""))
	for s in SLOTS:
		if s != bad and FileAccess.file_exists(save_dir + s) and not _read_file(save_dir + s).is_empty():
			return s
	return ""


## Rettung „Backup laden“: das abgestürzte Spielstand-File beim nächsten Lesen überspringen.
func use_backup() -> void:
	var bad := str(failed_load().get("file", ""))
	end_load()
	skip_file = bad


## Rettung „Neu beginnen“: alte Stände werden umbenannt (nicht gelöscht), Schutzdatei entfernt.
func archive_all() -> String:
	var stamp := str(int(Time.get_unix_time_from_system()))
	for s in SLOTS:
		if FileAccess.file_exists(save_dir + s):
			DirAccess.rename_absolute(save_dir + s, save_dir + s + ".bak_" + stamp)
	if FileAccess.file_exists(meta_file):
		DirAccess.remove_absolute(meta_file)
	end_load()
	skip_file = ""
	return stamp


func write(data: Dictionary) -> bool:
	var latest := _latest_file()
	var target: String = SLOTS[1] if latest == SLOTS[0] else SLOTS[0]
	var path := save_dir + target
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Spielstand konnte nicht geschrieben werden: " + path)
		return false
	f.store_string(JSON.stringify(data, "", false))
	f.close()
	# Erst wenn die Datei vollständig steht, zeigt die Meta-Datei auf sie.
	var meta := FileAccess.open(meta_file, FileAccess.WRITE)
	if meta == null:
		return false
	meta.store_string(JSON.stringify({"latest": target, "saved_at_unix": int(Time.get_unix_time_from_system())}))
	meta.close()
	_last_written = target
	return true


## Liefert den migrierten Spielstand oder {} wenn keiner lesbar ist.
func read() -> Dictionary:
	var latest := _latest_file()
	var candidates: Array[String] = []
	if latest != "":
		candidates.append(latest)
	for s in SLOTS:
		if s != latest:
			candidates.append(s)
	for file in candidates:
		if file == skip_file:
			continue
		var data := _read_file(save_dir + file)
		if not data.is_empty():
			if int(data.get("version", 0)) < SaveCodec.MIN_VERSION:
				log_step("Spielstand %s ist Version %d, zu alt (mindestens %d)" % [file, int(data.get("version", 0)), SaveCodec.MIN_VERSION])
				continue
			last_read_file = file
			return migrate(data)
	return {}


## true, wenn es Spielstände gibt, aber keiner zur aktuellen Version passt (Kurswechsel MS20).
func has_only_old_saves() -> bool:
	var any := false
	for s in SLOTS:
		var data := _read_file(save_dir + s)
		if data.is_empty():
			continue
		any = true
		if int(data.get("version", 0)) >= SaveCodec.MIN_VERSION:
			return false
	return any


func delete_all() -> void:
	for s in SLOTS:
		if FileAccess.file_exists(save_dir + s):
			DirAccess.remove_absolute(save_dir + s)
	if FileAccess.file_exists(meta_file):
		DirAccess.remove_absolute(meta_file)
	end_load()
	skip_file = ""


func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	while version < SaveCodec.VERSION:
		if migrations.has(version):
			data = migrations[version].call(data)
		else:
			data["version"] = version + 1
		version = int(data.get("version", version + 1))
	return data


func _latest_file() -> String:
	var meta := _read_file(meta_file)
	var latest := str(meta.get("latest", ""))
	if latest != "" and FileAccess.file_exists(save_dir + latest):
		return latest
	for s in SLOTS:
		if FileAccess.file_exists(save_dir + s):
			return s
	return ""


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_warning("Spielstand unlesbar: " + path)
		return {}
	return parsed


# --- Einstellungen ----------------------------------------------------------

## Bildschirmwackeln an/aus (Pausenmenü, MS50), gespeichert in den Einstellungen.
func screen_shake() -> bool:
	if _shake_cache < 0:
		_shake_cache = 1 if bool(load_settings().get("screen_shake", true)) else 0
	return _shake_cache == 1


func set_screen_shake(on: bool) -> void:
	_shake_cache = 1 if on else 0
	var s := load_settings()
	s["screen_shake"] = on
	save_settings(s)


func load_settings() -> Dictionary:
	return _read_file(SETTINGS_FILE)


func save_settings(settings: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
		f.close()
