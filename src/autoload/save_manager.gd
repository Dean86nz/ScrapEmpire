extends Node
## Spielstände: zwei rotierende JSON-Dateien plus Meta-Datei, damit ein Absturz beim
## Schreiben nie den letzten gültigen Stand zerstört. Migrationen heben alte Versionen an.
## Außerdem Einstellungen (Sprache) in user://settings.json.

const SAVE_DIR := "user://saves/"
const META_FILE := "user://saves/save_meta.json"
const SLOTS := ["save_a.json", "save_b.json"]
const SETTINGS_FILE := "user://settings.json"

## version → Callable(data) -> data (hebt genau um eine Version)
var migrations: Dictionary = {}

var _last_written := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# Sprache: gespeicherte Einstellung, sonst Deutsch bei deutschem System, sonst Englisch.
	var locale := str(load_settings().get("locale", ""))
	if locale == "":
		locale = "de" if OS.get_locale_language() == "de" else "en"
	TranslationServer.set_locale(locale)


# --- Spielstand -------------------------------------------------------------

func has_save() -> bool:
	return _latest_file() != ""


func write(data: Dictionary) -> bool:
	var latest := _latest_file()
	var target: String = SLOTS[1] if latest == SLOTS[0] else SLOTS[0]
	var path := SAVE_DIR + target
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Spielstand konnte nicht geschrieben werden: " + path)
		return false
	f.store_string(JSON.stringify(data, "", false))
	f.close()
	# Erst wenn die Datei vollständig steht, zeigt die Meta-Datei auf sie.
	var meta := FileAccess.open(META_FILE, FileAccess.WRITE)
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
		var data := _read_file(SAVE_DIR + file)
		if not data.is_empty():
			return migrate(data)
	return {}


func delete_all() -> void:
	for s in SLOTS:
		if FileAccess.file_exists(SAVE_DIR + s):
			DirAccess.remove_absolute(SAVE_DIR + s)
	if FileAccess.file_exists(META_FILE):
		DirAccess.remove_absolute(META_FILE)


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
	var meta := _read_file(META_FILE)
	var latest := str(meta.get("latest", ""))
	if latest != "" and FileAccess.file_exists(SAVE_DIR + latest):
		return latest
	for s in SLOTS:
		if FileAccess.file_exists(SAVE_DIR + s):
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

func load_settings() -> Dictionary:
	return _read_file(SETTINGS_FILE)


func save_settings(settings: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
		f.close()
