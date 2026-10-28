extends TestCase
## Comic-Geräusche (MS45): mehrere Varianten, kein Knacken am Anfang/Ende, Saugen sehr leise.


func _sfx() -> Node:
	var s: Node = Engine.get_main_loop().root.get_node("Sfx")
	if not (s._streams as Dictionary).has("boing"):
		s._build_comic()
	return s


func test_comic_sounds_have_variants() -> void:
	var s := _sfx()
	for id in ["plop", "hammer", "boing", "slurp"]:
		assert_true((s._streams.get(id, []) as Array).size() >= 3, "mindestens 3 Varianten: " + id)


func test_generated_sounds_start_and_end_quiet() -> void:
	var s := _sfx()
	for buf: PackedFloat32Array in [s._bloop(400.0, 2.3, 0.07), s._bonk(330.0), s._boing(180.0), s._slurp(0)]:
		var peak := 0.0
		for v in buf:
			peak = maxf(peak, absf(v))
		assert_true(peak <= 1.0 and peak > 0.2, "Pegel sinnvoll")
		assert_true(absf(buf[0]) < 0.05 and absf(buf[buf.size() - 1]) < 0.05, "kein Knacken an den Enden")


func test_suction_loop_is_very_quiet() -> void:
	var s := _sfx()
	s.set_sucking(true)
	assert_true(float(s._suck_target) <= -25.0, "Saug-Dauergeräusch sehr leise")
	s.set_sucking(false)
	assert_eq(float(s._suck_target), -80.0)


func test_music_per_zone_and_finale() -> void:
	var s := _sfx()
	s._start_music()
	var cfg: Dictionary = s._music_cfg
	assert_eq((cfg["zones"] as Dictionary).size(), 6, "ein Stück je Zone")
	for p: String in (cfg["zones"] as Dictionary).values():
		assert_true(ResourceLoader.exists(p), "Datei da: " + p)
	assert_true(ResourceLoader.exists(str(cfg["finale"])))
	s.music_zone("z21")
	assert_eq(s._music_path, str(cfg["zones"]["z21"]))
	s.music_finale(true)
	s.music_zone("z11")
	assert_eq(s._music_path, str(cfg["finale"]), "Finale hat Vorrang")
	s.music_finale(false, "z11")
	assert_eq(s._music_path, str(cfg["zones"]["z11"]))
	assert_true(float(cfg["pause_min_s"]) >= 20.0 and float(cfg["pause_max_s"]) <= 40.0, "Pausen 20–40 s")


func test_zone_change_crossfades() -> void:
	# MS52: altes Stück wird leiser, während das neue lauter wird (zwei Abspieler gleichzeitig).
	var s := _sfx()
	s._start_music()
	s.music_zone("z01")
	s._music_tick(0.016)
	s.music.volume_db = -10.0
	s._music_state = "play"
	s.music_zone("z21")
	s._music_tick(0.016)
	s._music_tick(0.5)
	assert_eq(s._music_playing_path, str(s._music_cfg["zones"]["z21"]), "neues Stück läuft")
	assert_true(s._music_old.stream != null and s._music_old.volume_db > -60.0, "altes Stück klingt noch aus")
	assert_true(s.music.volume_db > -60.0 and s.music.volume_db < -10.0, "neues blendet ein")


func test_zone_jingle_is_clean() -> void:
	var s := _sfx()
	var buf: PackedFloat32Array = s._jingle()
	assert_true(absf(buf[0]) < 0.05 and absf(buf[buf.size() - 1]) < 0.05, "kein Knacken")
	assert_true(buf.size() > 20000, "ca. 1 s")
