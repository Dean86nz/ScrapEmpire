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
const LEVEL_DB := {"hammer_bot": -16.0, "slurp": -14.0, "boing": -8.0, "plop": -11.0, "deliver": -5.0, "quest": -6.0, "milestone": -5.0, "cheer": -6.0, "hammer": -7.0,
	"repair": -6.0, "honk": -6.0, "thud": -6.0, "courier": -6.0, "open": -18.0, "close": -18.0, "tab": -20.0, "launch": -4.0}
## Standard-Tonhöhen-Variation je Effekt.
const JITTER := 0.06

var _streams: Dictionary = {}   # id → Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}
var _suck := AudioStreamPlayer.new()
var _suck_target := -80.0
var _sucking := false
var _drive := AudioStreamPlayer.new()
var _drive_target := -80.0
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
	_drive.bus = BUS_SFX
	_drive.volume_db = -80.0
	add_child(_drive)
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


## Sanftes Rauschen, solange Rusty saugt (sehr leise, weich ein- und ausgeblendet). Beim
## Ansetzen ein kurzes Comic-Schlürfen (MS45).
func set_sucking(on: bool) -> void:
	_suck_target = -27.0 if on else -80.0
	if on and not _sucking:
		play_throttled("slurp", 0.6, 0.1)
	_sucking = on
	if on and not _suck.playing:
		_suck.play()


## Fahrsummen: 0 = steht (still), 1 = volles Tempo (höher und etwas lauter).
func set_driving(speed_frac: float) -> void:
	var f := clampf(speed_frac, 0.0, 1.5)
	_drive_target = -80.0 if f < 0.05 else lerpf(-26.0, -18.0, minf(f, 1.0))
	_drive.pitch_scale = lerpf(0.8, 1.25, minf(f, 1.0))
	if f >= 0.05 and not _drive.playing:
		_drive.play()


func _process(delta: float) -> void:
	_music_tick(delta)
	if _drive.playing:
		_drive.volume_db = move_toward(_drive.volume_db, _drive_target, delta * 80.0)
		if _drive.volume_db <= -79.0 and _drive_target <= -80.0:
			_drive.stop()
	if _suck.playing:
		_suck.volume_db = move_toward(_suck.volume_db, _suck_target, delta * (25.0 if _suck_target > _suck.volume_db else 60.0))
		if _suck.volume_db <= -79.0 and _suck_target <= -80.0:
			_suck.stop()


# --- Musik je Zone (MS46) --------------------------------------------------------

var _music_cfg: Dictionary = {}
var _music_path := ""          # gewünschtes Stück (Zone oder Finale)
var _music_playing_path := ""
var _music_state := "off"      # off, fade_in, play, fade_out, pause
var _music_played := 0.0
var _music_pause := 0.0
var _finale := false


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


func _music_tick(delta: float) -> void:
	var base := float(_music_cfg.get("music_db", -10.0))
	var fade := maxf(float(_music_cfg.get("fade_s", 2.5)), 0.1)
	var step := delta * 60.0 / fade  # ca. 60 dB je Überblendung
	if _music_path != _music_playing_path and _music_state in ["play", "fade_in"]:
		_music_state = "fade_out"
	match _music_state:
		"off", "pause":
			if _music_state == "pause" and _music_path == _music_playing_path:
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
			_music_played += delta
			if not _finale and _music_played >= float(_music_cfg.get("min_play_s", 110.0)):
				_music_state = "fade_out"
		"fade_out":
			music.volume_db = move_toward(music.volume_db, -60.0, step)
			if music.volume_db <= -59.0:
				music.stop()
				if _music_path != _music_playing_path:
					_music_state = "off"  # Zonenwechsel: gleich das neue Stück
				else:
					_music_state = "pause"
					_music_pause = randf_range(float(_music_cfg.get("pause_min_s", 20.0)), float(_music_cfg.get("pause_max_s", 40.0)))


func _music_begin(_base: float) -> void:
	if _music_path == "" or not ResourceLoader.exists(_music_path):
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
	# Fahrsummen: tiefer, weicher Motor mit leichtem Kettenrattern, 1 s Schleife
	buf = PackedFloat32Array()
	buf.resize(RATE)
	lp = 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var hum := sin(TAU * 62.0 * t) * 0.5 + sin(TAU * 124.0 * t) * 0.18
		var rattle := (1.0 if fmod(t * 18.0, 1.0) < 0.12 else 0.0) * rng.randf_range(-0.3, 0.3)
		lp += ((hum + rattle) - lp) * 0.3
		buf[i] = lp * 0.6
	var drive := _to_stream(buf)
	drive.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drive.loop_end = buf.size()
	_drive.stream = drive
	buf = PackedFloat32Array()
	buf.resize(RATE * 3)
	lp = 0.0
	for i in buf.size():
		var k := float(i) / buf.size()
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		var env := minf(k * 2.5, 1.0) * clampf((1.0 - k) * 6.0, 0.0, 1.0)
		buf[i] = (lp * 3.0 + sin(TAU * 55.0 * i / RATE) * 0.4) * 0.5 * env
	_streams["launch"] = [_to_stream(buf)]
	_build_comic()


# --- Comic-Geräusche (MS45), je mehrere Varianten --------------------------------

func _build_comic() -> void:
	var plops: Array = []
	for v in 5:
		plops.append(_to_stream(_bloop(380.0 + 45.0 * v, 2.3, 0.07)))
	_streams["plop"] = plops
	var bonks: Array = []
	for v in 4:
		bonks.append(_to_stream(_bonk(330.0 + 25.0 * v)))
	_streams["hammer"] = bonks
	_streams["hammer_bot"] = bonks
	var boings: Array = []
	for v in 3:
		boings.append(_to_stream(_boing(180.0 + 30.0 * v)))
	_streams["boing"] = boings
	var slurps: Array = []
	for v in 4:
		slurps.append(_to_stream(_slurp(v)))
	_streams["slurp"] = slurps


## Bloop: Sinus, Tonhöhe steigt schnell, kurzes Ausklingen (Plopp beim Einsammeln).
func _bloop(f0: float, rise: float, dur: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * f0 * (1.0 + (rise - 1.0) * sqrt(k)) / RATE
		var env := minf(k * 40.0, 1.0) * pow(1.0 - k, 2.0)
		buf[i] = sin(ph) * env * 0.8
	return buf


## Bonk: Holzklotz-Schlag, Tonhöhe fällt, dazu ein kurzer Klick.
func _bonk(f0: float) -> PackedFloat32Array:
	var n := int(RATE * 0.16)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0)
	for i in n:
		var k := float(i) / n
		ph += TAU * f0 * (1.0 - 0.45 * k) / RATE
		var tri := 2.0 * absf(2.0 * fmod(ph / TAU, 1.0) - 1.0) - 1.0
		var click := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - k * 25.0)
		buf[i] = (tri * 0.75 + sin(ph * 2.0) * 0.2 + click * 0.5) * pow(1.0 - k, 3.0) * minf(k * 120.0, 1.0)
	return buf


## Boing: Feder mit Vibrato, Tonhöhe schwingt nach oben.
func _boing(f0: float) -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		var f := f0 * (1.0 + 1.2 * k) * (1.0 + 0.18 * sin(TAU * 14.0 * k * 0.45 * 2.2) * (1.0 - k))
		ph += TAU * f / RATE
		buf[i] = sin(ph) * minf(k * 30.0, 1.0) * pow(1.0 - k, 1.4) * 0.7
	return buf


## Schlürfen: gefiltertes Rauschen mit Tonhöhen-Glissando nach oben, 0,25 s.
func _slurp(seed_value: int) -> PackedFloat32Array:
	var n := int(RATE * 0.25)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + seed_value
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (0.05 + 0.25 * k)
		ph += TAU * (220.0 + 520.0 * k + 30.0 * seed_value) / RATE
		var env := sin(PI * k) * (0.8 + 0.2 * sin(TAU * 18.0 * k))
		buf[i] = (lp * 1.6 + sin(ph) * 0.25) * env * 0.7
	return buf


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
