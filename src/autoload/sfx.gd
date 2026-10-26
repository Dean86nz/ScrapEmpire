extends Node
## Ton (MS32): Soundeffekte aus CC0-Dateien (Kenney, siehe docs/CREDITS.md) unter assets/audio/sfx/,
## je Effekt mehrere Varianten und leichte Tonhöhen-Variation. Nur zwei Dinge sind selbst erzeugt:
## das sanfte Rauschen beim Dauersaugen und das tiefe Grollen beim Abflug.
## Busse „Music“ und „SFX“ mit Lautstärke aus den Einstellungen (Pause-Menü). Rein kosmetisch.

const SFX_DIR := "res://assets/audio/sfx/"
const RATE := 22050
const VOICES := 8
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
## Grundlautstärke je Effekt (dB), damit alles leise unter der Musik liegt.
const LEVEL_DB := {"plop": -10.0, "deliver": -6.0, "quest": -6.0, "milestone": -5.0, "cheer": -5.0,
	"repair": -8.0, "honk": -6.0, "thud": -6.0, "open": -10.0, "close": -10.0, "tab": -12.0, "buy": -8.0, "launch": -4.0}
## Standard-Tonhöhen-Variation je Effekt.
const JITTER := 0.06

var _streams: Dictionary = {}   # id → Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}
var _suck := AudioStreamPlayer.new()
var _suck_target := -80.0
var music := AudioStreamPlayer.new()
var volume := {"music": 0.6, "sfx": 0.8}


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
	_build_generated()
	_suck.bus = BUS_SFX
	_suck.volume_db = -80.0
	add_child(_suck)
	music.bus = BUS_MUSIC
	add_child(music)
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


func play(id: String, pitch_jitter: float = JITTER, volume_db: float = 0.0) -> void:
	var list: Array = _streams.get(id, [])
	if list.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = list[randi() % list.size()]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = float(LEVEL_DB.get(id, -6.0)) + volume_db
	p.play()


## Wie play, aber höchstens einmal je `min_gap` Sekunden (z. B. Plopp beim Dauersaugen).
func play_throttled(id: String, min_gap: float, pitch_jitter: float = JITTER, volume_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(id, -100000)) < int(min_gap * 1000.0):
		return
	_last_play[id] = now
	play(id, pitch_jitter, volume_db)


## Sanftes Rauschen, solange Rusty saugt (weich ein- und ausgeblendet).
func set_sucking(on: bool) -> void:
	_suck_target = -16.0 if on else -80.0
	if on and not _suck.playing:
		_suck.play()


func _process(delta: float) -> void:
	if _suck.playing:
		_suck.volume_db = move_toward(_suck.volume_db, _suck_target, delta * (60.0 if _suck_target > _suck.volume_db else 90.0))
		if _suck.volume_db <= -79.0 and _suck_target <= -80.0:
			_suck.stop()


## Musik aus data/audio.json („music“: Pfad). Leer = keine Musik (Auswahl durch den Auftraggeber).
func _start_music() -> void:
	var text := FileAccess.get_file_as_string("res://data/audio.json")
	var cfg: Variant = JSON.parse_string(text) if text != "" else null
	var path := str(cfg.get("music", "")) if cfg is Dictionary else ""
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	music.stream = stream
	music.volume_db = float(cfg.get("music_db", -8.0))
	music.play()


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


# --- selbst erzeugt: Saug-Rauschen und Abflug-Grollen --------------------------

func _build_generated() -> void:
	var buf := PackedFloat32Array()
	buf.resize(RATE)  # 1 s Schleife, gefiltertes Rauschen
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.2
		buf[i] = lp2 * 2.2
	# Anfang und Ende überblenden, damit die Schleife nicht knackt
	var fade := 600
	for i in fade:
		var k := float(i) / fade
		buf[i] = buf[i] * k + buf[buf.size() - fade + i] * (1.0 - k)
	buf.resize(buf.size() - fade)
	var loop := _to_stream(buf)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = buf.size()
	_suck.stream = loop
	buf = PackedFloat32Array()
	buf.resize(RATE * 3)
	lp = 0.0
	for i in buf.size():
		var k := float(i) / buf.size()
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		var env := minf(k * 2.5, 1.0) * clampf((1.0 - k) * 6.0, 0.0, 1.0)
		buf[i] = (lp * 3.0 + sin(TAU * 55.0 * i / RATE) * 0.4) * 0.5 * env
	_streams["launch"] = [_to_stream(buf)]


func _to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
