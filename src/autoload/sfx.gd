extends Node
## Ton: Soundeffekte aus CC0-Dateien (Kenney, siehe docs/CREDITS.md) unter assets/audio/sfx/,
## je Effekt mehrere Varianten und leichte Tonhöhen-Variation. Spielaktionen klingen natürlich
## (Aufprall, Münzen, Pizzicato-Jingles), Klick-Töne gibt es nur leise in Menüs. Selbst erzeugt:
## das Saugrauschen, das Fahrsummen (Tonhöhe folgt dem Tempo) und das Grollen beim Abflug.
## Busse „Music“ und „SFX“ mit Lautstärke aus den Einstellungen (Pause-Menü). Rein kosmetisch.

const SFX_DIR := "res://assets/audio/sfx/"
const RATE := 22050
const VOICES := 8
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
## Grundlautstärke je Effekt (dB), damit alles leise unter der Musik liegt.
const LEVEL_DB := {"buy": -8.0, "bot": -14.0, "slurp": -12.0, "plop": -14.0, "deliver": -5.0, "quest": -6.0, "milestone": -5.0, "cheer": -6.0, "hammer": -7.0,
	"repair": -6.0, "honk": -6.0, "thud": -6.0, "courier": -6.0, "open": -18.0, "close": -18.0, "tab": -20.0, "launch": -4.0}
## Standard-Tonhöhen-Variation je Effekt.
const JITTER := 0.06

var _streams: Dictionary = {}   # id → Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}
var _sucking := false
var music := AudioStreamPlayer.new()
var volume := {"music": 0.6, "sfx": 0.45}   # Effekte standardmäßig leiser als die Musik (MS63)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_MUSIC)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
	_load_files()
	music.bus = BUS_MUSIC
	add_child(music)
	_music_old.bus = BUS_MUSIC
	add_child(_music_old)
	var s := SaveManager.load_settings()
	set_volume("music", float(s.get("vol_music", volume["music"])))
	set_volume("sfx", float(s.get("vol_sfx", volume["sfx"])))
	_start_music()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


## Lautstärke 0..1 für "music" oder "sfx" (0 = stumm).
func set_volume(kind: String, value: float) -> void:
	volume[kind] = clampf(value, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(BUS_MUSIC if kind == "music" else BUS_SFX)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, float(volume[kind]) <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(volume[kind]), 0.001)))


func save_volume() -> void:
	var s := SaveManager.load_settings()
	s["vol_music"] = volume["music"]
	s["vol_sfx"] = volume["sfx"]
	SaveManager.save_settings(s)


func play(id: String, pitch_jitter: float = JITTER, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var list: Array = _streams.get(id, [])
	if list.is_empty() or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = list[randi() % list.size()]
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.volume_db = float(LEVEL_DB.get(id, -6.0)) + volume_db
	p.play()


## Sperrt einen gedrosselten Effekt ab jetzt (z. B. Bot-Bonk direkt nach Rustys eigenem Bonk).
func suppress(id: String) -> void:
	_last_play[id] = Time.get_ticks_msec()


## Wie play, aber höchstens einmal je `min_gap` Sekunden (z. B. Plopp beim Dauersaugen).
func play_throttled(id: String, min_gap: float, pitch_jitter: float = JITTER, volume_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(id, -100000)) < int(min_gap * 1000.0):
		return
	_last_play[id] = now
	play(id, pitch_jitter, volume_db)



## Saugen (MS65, Auswahl des Auftraggebers): kurzes Schlürfen beim Ansetzen, kein Dauerton.
## Alle im Code erzeugten Geräusche sind entfernt; es klingen nur noch echte Sounddateien.
func set_sucking(on: bool) -> void:
	if on and not _sucking:
		play_throttled("slurp", 1.2, 0.08)
	_sucking = on


## Fahrgeräusch entfernt (nervte); bleibt als leere Funktion für bestehende Aufrufe.
func set_driving(_speed_frac: float) -> void:
	pass


func _process(delta: float) -> void:
	_music_tick(delta)


# --- Musik je Zone (MS46) --------------------------------------------------------

var _music_cfg: Dictionary = {}
var _music_path := ""          # gewünschtes Stück (Zone oder Finale)
var _music_playing_path := ""
var _music_state := "off"      # off, fade_in, play, fade_out, pause
var _music_played := 0.0
var _music_pause := 0.0
var _finale := false
var _music_old := AudioStreamPlayer.new()   # zweiter Abspieler fürs Überblenden
var _duck_db := 0.0
var _duck_timer := 0.0


func _start_music() -> void:
	var text := FileAccess.get_file_as_string("res://data/audio.json")
	var cfg: Variant = JSON.parse_string(text) if text != "" else null
	_music_cfg = cfg if cfg is Dictionary else {}
	_music_path = str(_music_cfg.get("default", ""))


## Spieler betritt eine Zone: deren Stück (mit Überblenden), Finale hat Vorrang.
func music_zone(zone_id: String) -> void:
	var path := str((_music_cfg.get("zones", {}) as Dictionary).get(zone_id, _music_cfg.get("default", "")))
	if not _finale:
		_music_path = path


## Rundflug, Abflug, Abspann: Finale-Stück ohne Pausen; danach wieder die Zone.
func music_finale(on: bool, zone_id: String = "") -> void:
	_finale = on
	if on:
		_music_path = str(_music_cfg.get("finale", ""))
	else:
		music_zone(zone_id)


## Musik-Ablauf: Zonenwechsel = echtes Überblenden (altes Stück leiser, neues gleichzeitig lauter,
## zwei Abspieler, MS52). Sonst: Stück läuft min_play_s, blendet aus, Pause, wieder ein.
func _music_tick(delta: float) -> void:
	var base := float(_music_cfg.get("music_db", -10.0)) + _duck_db
	var fade := maxf(float(_music_cfg.get("fade_s", 2.5)), 0.1)
	var step := delta * 60.0 / fade  # 60 dB je Überblendung
	_duck_db = move_toward(_duck_db, 0.0, delta * 8.0) if _duck_timer <= 0.0 else _duck_db
	_duck_timer -= delta
	# Altes Stück (Überblenden) ausklingen lassen
	if _music_old.stream != null and _music_old.volume_db > -60.0:
		_music_old.volume_db = move_toward(_music_old.volume_db, -60.0, step)
		if _music_old.volume_db <= -59.0:
			_music_old.stop()
			_music_old.volume_db = -60.0
	if _music_path != _music_playing_path and _music_path != "":
		if _music_state in ["fade_in", "play", "fade_out"]:
			# Überblenden: aktuelles Stück wandert auf den zweiten Abspieler
			var tmp := _music_old
			_music_old = music
			music = tmp
		_music_begin(base)
		return
	match _music_state:
		"off", "pause":
			if _music_state == "pause":
				_music_pause -= delta
				if _music_pause > 0.0:
					return
			_music_begin(base)
		"fade_in":
			music.volume_db = move_toward(music.volume_db, base, step)
			_music_played += delta
			if music.volume_db >= base:
				_music_state = "play"
		"play":
			music.volume_db = move_toward(music.volume_db, base, delta * 20.0)
			_music_played += delta
			if not _finale and _music_played >= float(_music_cfg.get("min_play_s", 110.0)):
				_music_state = "fade_out"
		"fade_out":
			music.volume_db = move_toward(music.volume_db, -60.0, step)
			if music.volume_db <= -59.0:
				music.stop()
				_music_state = "pause"
				_music_pause = randf_range(float(_music_cfg.get("pause_min_s", 20.0)), float(_music_cfg.get("pause_max_s", 40.0)))


func _music_begin(_base: float) -> void:
	if _music_path == "" or not ResourceLoader.exists(_music_path):
		_music_playing_path = _music_path
		return
	var stream: AudioStream = load(_music_path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	music.stream = stream
	music.volume_db = -60.0
	music.play()
	_music_playing_path = _music_path
	_music_played = 0.0
	_music_state = "fade_in"


## Musik kurz leiser (z. B. für den Zonen-Jingle), danach sanft zurück.
func duck(db: float, seconds: float) -> void:
	_duck_db = -absf(db)
	_duck_timer = seconds


# --- Dateien ------------------------------------------------------------------

## Lädt assets/audio/sfx/<id>_<n>.ogg als Varianten von <id>.
func _load_files() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		var fname := f.trim_suffix(".import").trim_suffix(".remap")
		if not fname.ends_with(".ogg"):
			continue
		var id := fname.get_basename()
		var cut := id.rfind("_")
		if cut > 0:
			id = id.substr(0, cut)
		var stream: AudioStream = load(SFX_DIR + fname)
		if stream == null:
			continue
		if not _streams.has(id):
			_streams[id] = []
		if not (_streams[id] as Array).has(stream):
			_streams[id].append(stream)
