extends Node
## Kleine Soundeffekte, beim Start selbst erzeugt (Sinus, Dreieck, Rauschen). Keine Dateien, daher
## keine Lizenzfragen. Eigener Bus „SFX“ (Lautstärke-Regler folgt in MS25). Rein kosmetisch.
## Sounds: deliver (Münzen), quest (Glocke), milestone (Arpeggio), repair (Fanfare), buy (Plopp), launch (Grollen).

const RATE := 22050
const VOICES := 6
const BUS := "SFX"
const BUS_DB := -6.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}   # id → Zeitpunkt (ms), für gedrosselte Sounds


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_volume_db(i, BUS_DB)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	_build()


func play(id: String, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	if not _streams.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[id]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


## Wie play, aber höchstens einmal je `min_gap` Sekunden (z. B. Plopp beim Dauersaugen).
func play_throttled(id: String, min_gap: float, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(id, -100000)) < int(min_gap * 1000.0):
		return
	_last_play[id] = now
	play(id, pitch_jitter, volume_db)


# --- Erzeugung ----------------------------------------------------------------

func _build() -> void:
	var buf := PackedFloat32Array()
	# Münzen: drei helle Klicks und ein weicher Schlag
	buf = _silence(0.45)
	_mix_tone(buf, 0.0, 0.12, 110.0, "sine", 0.5, 30.0)
	_mix_tone(buf, 0.0, 0.18, 1568.0, "bell", 0.35, 22.0)
	_mix_tone(buf, 0.06, 0.18, 2093.0, "bell", 0.32, 22.0)
	_mix_tone(buf, 0.12, 0.30, 2637.0, "bell", 0.30, 14.0)
	_streams["deliver"] = _to_stream(buf)
	# Glocke: zwei Töne
	buf = _silence(0.7)
	_mix_tone(buf, 0.0, 0.5, 880.0, "bell", 0.4, 7.0)
	_mix_tone(buf, 0.12, 0.55, 1318.5, "bell", 0.38, 6.0)
	_streams["quest"] = _to_stream(buf)
	# Meilenstein: C-E-G-C aufwärts
	buf = _silence(1.0)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_mix_tone(buf, i * 0.085, 0.6 if i == 3 else 0.3, notes[i], "tri", 0.32, 5.0 if i == 3 else 9.0)
	_streams["milestone"] = _to_stream(buf)
	# Fanfare: Auftakt und gehaltener Dur-Akkord
	buf = _silence(1.4)
	_mix_tone(buf, 0.0, 0.14, 392.0, "tri", 0.3, 8.0)
	_mix_tone(buf, 0.12, 0.14, 523.25, "tri", 0.3, 8.0)
	for f in [523.25, 659.25, 783.99, 1046.5]:
		_mix_tone(buf, 0.26, 1.1, f, "tri", 0.2, 2.6)
	_streams["repair"] = _to_stream(buf)
	# Jubel: weiches, tiefes Dreiklang-Arpeggio (G-C-E), leise
	buf = _silence(0.8)
	var cheer := [392.0, 523.25, 659.25]
	for i in cheer.size():
		_mix_tone(buf, i * 0.09, 0.55 if i == 2 else 0.3, cheer[i], "sine", 0.22, 4.0 if i == 2 else 8.0)
	_streams["cheer"] = _to_stream(buf)
	# Einsaug-Plopp: sehr kurz, tief, leise
	buf = _silence(0.09)
	_mix_sweep(buf, 0.0, 0.07, 520.0, 240.0, 0.28)
	_streams["plop"] = _to_stream(buf)
	# Plopp: kurzer fallender Ton
	buf = _silence(0.12)
	_mix_sweep(buf, 0.0, 0.09, 950.0, 380.0, 0.5)
	_streams["buy"] = _to_stream(buf)
	# Grollen: tiefes, anschwellendes Rauschen
	buf = _silence(3.0)
	_mix_rumble(buf, 3.0, 0.55)
	_streams["launch"] = _to_stream(buf)


func _silence(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


func _mix_tone(buf: PackedFloat32Array, start: float, dur: float, freq: float, wave: String, vol: float, decay: float) -> void:
	var s0 := int(start * RATE)
	var n := mini(int(dur * RATE), buf.size() - s0)
	var attack := int(0.004 * RATE)
	for i in n:
		var t := float(i) / RATE
		var ph := t * freq
		var v := 0.0
		match wave:
			"sine":
				v = sin(TAU * ph)
			"bell":
				v = sin(TAU * ph) + 0.35 * sin(TAU * ph * 2.76) * exp(-t * 18.0)
			"tri":
				v = 1.0 - 4.0 * absf(fposmod(ph, 1.0) - 0.5)
		var env := exp(-t * decay) * (float(i) / attack if i < attack else 1.0)
		var fade := clampf(float(n - i) / (0.01 * RATE), 0.0, 1.0)
		buf[s0 + i] += v * vol * env * fade


func _mix_sweep(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, vol: float) -> void:
	var s0 := int(start * RATE)
	var n := mini(int(dur * RATE), buf.size() - s0)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += lerpf(f0, f1, k) / RATE
		buf[s0 + i] += sin(TAU * ph) * vol * (1.0 - k)


func _mix_rumble(buf: PackedFloat32Array, dur: float, vol: float) -> void:
	var n := mini(int(dur * RATE), buf.size())
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var k := float(i) / n
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		var hum := sin(TAU * 55.0 * i / RATE) * 0.4
		var env := minf(k * 2.5, 1.0) * clampf((1.0 - k) * 6.0, 0.0, 1.0)
		buf[i] += (lp * 3.0 + hum) * vol * env


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
