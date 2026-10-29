extends TestCase
## Sounds (MS65): nur echte Dateien mit Varianten, Musik je Zone mit Überblenden.


func _sfx() -> Node:
	var s: Node = Engine.get_main_loop().root.get_node("Sfx")
	if (s._streams as Dictionary).is_empty():
		s._load_files()
	return s


func test_chosen_sounds_have_variants_and_nothing_generated() -> void:
	# MS65: nur echte Sounddateien (Auswahl des Auftraggebers), keine im Code erzeugten Töne mehr
	var s := _sfx()
	if (s._streams as Dictionary).is_empty():
		s._load_files()
	for id in ["plop", "hammer", "deliver", "slurp", "buy", "bot"]:
		assert_true((s._streams.get(id, []) as Array).size() >= 2, "Varianten aus Dateien: " + id)
	assert_false(s.has_method("_build_comic"), "keine erzeugten Comic-Töne mehr")
	assert_false(s.has_method("_build_generated"), "kein Fahr-/Saugrauschen mehr")


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
