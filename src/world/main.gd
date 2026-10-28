extends Node2D
## Hauptszene: lädt die Karte in die Simulation, baut Boden und Wände,
## verbindet Darstellung, HUD, Baumenü und Bau-Cursor mit der SimWorld.

const MAP_PATH := "res://data/maps/main.json"
const MAP_NAME := "main"
const AUTOSAVE_SECONDS := 60.0
const LONG_PRESS_SECONDS := 0.45

@onready var _player: Player = $Player
@onready var _world_view: WorldView = $WorldView
@onready var _hud: CanvasLayer = $Hud
@onready var _progress_menu: CanvasLayer = $ProgressMenu
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _end_screen: CanvasLayer = $EndScreen

var _cam_focus: Node2D = null     # solange gesetzt, schaut die Kamera dorthin (Feier, Abflug)
var _cam_focus_time := 0.0        # > 0: Fokus endet nach dieser Zeit von selbst
var _fade: ColorRect
var _launching := false

var _world: SimWorld
var _map_data: Dictionary = {}
var _zone_gates: Dictionary = {}  # "a|b" → Array[Node]
var _nature: NatureView
var _sky: DayLight
var _rain: RainLayer
var _chapter_timer := 0.0
var _tech_press_time := -1.0
var _first_collected: Dictionary = {}
var _autosave_timer := AUTOSAVE_SECONDS
var _loaded_from_save := false


func _ready() -> void:
	_world = SimWorld.new()
	_world.defs = DataRegistry.building_defs
	_world.item_values = DataRegistry.item_values()
	_world.progression = DataRegistry.new_progression()
	_world.rare_items = DataRegistry.rare_items()
	_world.helper_cfg = DataRegistry.helper_config()
	_world.drone_cfg = DataRegistry.drone_config()
	_world.collectible_cfg = DataRegistry.collectible_config()
	_world.ship_cfg = DataRegistry.ship_config()
	_world.dirt_cfg = DirtMap.load_config()
	_world.quests.setup(DataRegistry.quest_defs())
	_world.milestones.setup(MilestoneState.load_defs())
	_world.events_cfg = EventSystem.load_config()
	_world.setup_progression_data(DataRegistry.tech_defs(), DataRegistry.skill_data())
	var start_px: Vector2
	SaveManager.log_step("Spielszene startet (Version %s)" % str(ProjectSettings.get_setting("application/config/version", "?")))
	var save_data := SaveManager.read()
	_map_data = MapLoader.read(MAP_PATH)
	if not save_data.is_empty():
		SaveManager.begin_load(SaveManager.last_read_file)
		SaveCodec.log_steps = true
		SaveManager.log_step("Spielstand %s gelesen, Version %d" % [SaveManager.last_read_file, int(save_data.get("version", 0))])
		MapLoader.apply(_world, _map_data, false)
		start_px = SaveCodec.decode(save_data, _world)
		SaveManager.log_step("Zonen auffüllen")
		MapLoader.fill_missing_zones(_world, _map_data)
		SaveManager.log_step("Schiff prüfen")
		MapLoader.ensure_ship(_world, _map_data)
		SaveManager.log_step("Schmutzkarte prüfen")
		MapLoader.ensure_dirt(_world, _map_data)
		SaveManager.log_step("Aufgaben abgleichen")
		_world.quests.fast_forward(_world, bool(_world.flags.get("tutorial_done", false)))
		if not _world.flags.has("milestones_v1"):
			_world.milestones.check(_world, true)   # alte Stände: Erreichtes still nachtragen
		_world.flags["milestones_v1"] = true
		_loaded_from_save = true
	else:
		SaveManager.log_step("Neues Spiel")
		start_px = Vector2(MapLoader.apply(_world, _map_data))
	SaveManager.log_step("Fundstücke")
	_world.spawn_collectibles()
	SimClock.reset_world(_world)
	var start := Vector2i(start_px)

	var size := _world.size_px()
	_build_ground(size.x, size.y)
	_build_walls(size.x, size.y)
	_build_zone_fences()

	_player.position = Vector2(start)
	var cam: Camera2D = _player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = size.x
	cam.limit_bottom = size.y
	cam.zoom = Vector2.ONE * GameConfig.CAMERA_ZOOM
	cam.reset_smoothing()

	SaveManager.log_step("Weltansicht aufbauen")
	_world_view.bind(_world, _player)
	_player.setup_look(_world)
	var events := EventView.new()
	events.name = "Events"
	add_child(events)
	events.bind(_world, _hud)
	SaveManager.log_step("HUD und Menüs")
	_hud.bind(_world)
	_hud.minimap.dirt_texture = _world_view.dirt_view.map_texture
	_progress_menu.bind(_world)
	_player.hotbar_selected.connect(_hud.set_selected_slot)
	if _loaded_from_save:
		_player.selected_slot = int(save_data.get("player", {}).get("selected_slot", 0))
		_hud.set_selected_slot(_player.selected_slot)
		_first_collected = {"scrap": true, "copper": true, "plastic": true, "chrome": true}
	_world.drone_failed.connect(func(reason: String) -> void: Quips.say("drone_fail_" + reason, true))
	_world.drone_added.connect(func(_d: Drone) -> void:
		_player.celebrate()
		Quips.say("drone_bought", true))
	_world.helper_failed.connect(func(reason: String) -> void: Quips.say("helper_fail_" + reason, true))
	_world.helper_added.connect(func(_h: Helper) -> void: _player.celebrate())
	_hud.bind_minimap(_player)
	_progress_menu.bind_player(_player)
	_progress_menu.set_dirt_texture(_world_view.dirt_view.map_texture)
	_world.zones.stage_changed.connect(_on_zone_stage_changed)
	SaveManager.log_step("Zonen und Natur")
	_world.zones.refresh(_world.nodes)
	_world.quest_completed.connect(_on_quest_completed)
	_world.ship_upgraded.connect(_on_ship_upgraded)
	_world.ship_failed.connect(func(reason: String) -> void: Quips.say("ship_fail_" + reason, true))
	_world.ship_upgrade_bought.connect(func(_id: String, _lvl: int) -> void:
		_player.celebrate()
		Quips.say("upgrade_bought", true))
	_world.ship_delivered.connect(_on_ship_delivered)
	_world.milestone_reached.connect(_on_milestone_reached)
	_world.boss_defeated.connect(_on_boss_defeated)
	_world.boss_rally.connect(_on_boss_rally)
	_world.hammer_impact.connect(func(_n: ResourceNode, tier: int, one_hit: bool) -> void:
		if tier >= 4 or one_hit:
			_shake(3.0 + 1.5 * tier, 0.16)
		if one_hit:
			_hit_stop(0.06))
	_world.boss_blocked.connect(func(_b: ResourceNode, have: int, _need: int) -> void:
		if have == 0 and BossSystem.helpers_at(_world, _b) == 0 and _world.helpers.is_empty():
			EventBus.quip.emit("QUIP_RALLY_NOBODY"))
	_end_screen.connect("closed", _on_credits_closed)
	_world.courier_failed.connect(func(r: String) -> void:
		if r == "empty":
			EventBus.quip.emit("QUIP_COURIER_EMPTY")
		elif r == "cooldown" or r == "busy":
			EventBus.quip.emit("QUIP_COURIER_WAIT"))
	_world.helper_bored.connect(func(h: Helper) -> void:
		var key := "bored_hint_%d" % h.id
		if not _world.flags.has(key):
			_world.flags[key] = true
			EventBus.quip.emit("QUIP_BOT_BORED"))
	# Jeder Kauf: Menü zu, Rusty jubelt ca. 1 s, dann Steuerung zurück
	_world.ship_upgrade_bought.connect(func(_id: String, _l: int) -> void: _celebrate_purchase())
	_world.skill_bought.connect(func(_id: String, _l: int) -> void: _celebrate_purchase())
	_world.helper_upgrade_bought.connect(func(_id: String, _l: int) -> void: _celebrate_purchase())
	_world.drone_upgrade_bought.connect(func(_id: String, _l: int) -> void: _celebrate_purchase())
	_world.helper_added.connect(func(_h: Helper) -> void: _celebrate_purchase())
	_world.drone_added.connect(func(_d: Drone) -> void: _celebrate_purchase())
	_world.zone_unlocked.connect(_on_zone_unlocked)
	_world.collectible_found.connect(_on_collectible_found)
	_setup_nature()
	_refresh_chapter_hud()
	_open_unlocked_gates()
	_pause_menu.opened.connect(save_game)
	_pause_menu.save_quit_requested.connect(_on_save_quit)
	_pause_menu.new_game_requested.connect(_on_new_game)
	_pause_menu.language_changed.connect(_on_language_changed)
	get_tree().auto_accept_quit = false
	_world.skill_bought.connect(func(_id: String, _lvl: int) -> void: Quips.say("skill_bought"))


	_world.inventory_full.connect(func() -> void: Quips.say("inventory_full"))
	_world.wreck_destroyed.connect(func(_id: int) -> void: Quips.say("wreck_destroyed"))
	_world.item_collected.connect(_on_item_collected)
	_world.place_failed.connect(func(reason: String) -> void: Quips.say("fail_" + reason, true))
	_world.deposit_rejected.connect(func(_b: Building, _item: String) -> void: Quips.say("deposit_rejected", true))
	_world.building_placed.connect(_on_building_placed)
	_world.too_hard.connect(func(_n: ResourceNode, tool: String) -> void: Quips.say("too_hard_" + tool, true))
	_world.progression.level_up.connect(_on_level_up)
	SaveManager.log_step("Spielszene bereit")
	# Ladeschutz erst nach 3 s ohne Absturz entfernen (die ersten Frames zeichnen die ganze Welt).
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		SaveManager.end_load()
		SaveCodec.log_steps = false
		SaveManager.log_step("Laden abgeschlossen"))
	if not _loaded_from_save:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: Quips.say("start"))
	else:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: Quips.say("loaded", true))


func _process(delta: float) -> void:
	_update_camera_focus(delta)
	Sfx.set_sucking(_world.player.suck_held and InputRouter.context == InputRouter.Context.GAME)
	Sfx.set_driving(_player.velocity.length() / maxf(GameConfig.PLAYER_SPEED_PX, 1.0))
	_hud.set_hint(_current_hint())
	_chapter_timer -= delta
	if _chapter_timer <= 0.0:
		_chapter_timer = 1.0
		_refresh_chapter_hud()
		_hud.set_planet(_world.zones.planet_health(_world.nodes))
	# Kurz/Lang-Erkennung per Zustandsabfrage (funktioniert auch mit simulierten Eingaben).
	if _tech_press_time >= 0.0:
		_tech_press_time += delta
		if not Input.is_action_pressed("tech_tree"):
			var held_t := _tech_press_time
			_tech_press_time = -1.0
			if InputRouter.context == InputRouter.Context.GAME and held_t < LONG_PRESS_SECONDS:
				_progress_menu.open()
		elif _tech_press_time >= LONG_PRESS_SECONDS:
			_tech_press_time = -1.0
			_hud.toggle_minimap()
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


## Speichert den kompletten Stand (Autosave, Pause, Beenden, F5).
func save_game() -> bool:
	var data := SaveCodec.encode(_world, MAP_NAME, _player.global_position, _player.selected_slot)
	var ok := SaveManager.write(data)
	if ok:
		EventBus.quip.emit("HUD_SAVED")
	return ok


func _on_save_quit() -> void:
	save_game()
	get_tree().quit()


func _on_new_game() -> void:
	SaveManager.delete_all()
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME
	get_tree().reload_current_scene()


func _on_language_changed(locale: String) -> void:
	save_game()
	SaveManager.save_settings({"locale": locale})
	TranslationServer.set_locale(locale)
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("call_courier") and InputRouter.context == InputRouter.Context.GAME:
		_world.queue_command({"type": "call_courier"})
		get_viewport().set_input_as_handled()
		return
	if InputRouter.context == InputRouter.Context.GAME and event.is_action_pressed("tool_swap") and _player.nearby_building() is Ship:
		# X am Schiff: Schiff-Menü (Upgrades, Reparatur, Bots, Drohnen)
		_progress_menu.open(_progress_menu.Tab.SHIP)
		get_viewport().set_input_as_handled()
	elif InputRouter.context == InputRouter.Context.GAME and event.is_action_pressed("tech_tree"):
		# Select kurz: Fortschritt; Select lang: Minimap ein/aus.
		_tech_press_time = 0.0
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("minimap_toggle"):
		_hud.toggle_minimap()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_perf"):
		debug_scenario("helpers")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_chain"):
		debug_scenario("drones")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_cheat"):
		# Dev-Cheat: Bolts, Material, XP und Chrom zum Testen der Menüs.
		_world.bolts += 500
		_world.bolts_changed.emit(_world.bolts)
		_world.player.inventory.add("scrap", 10)
		_world.player.inventory.add("copper", 10)
		_world.progression.add_xp(100)
		EventBus.quip.emit("DEBUG_CHEAT")
		get_viewport().set_input_as_handled()


## Dev-Szenarien (nur Debug/Tests): "helpers" = zwei Bots, "drones" = zwei Drohnen mit losem Schrott,
## "endgame" = viele Bolts für die Schiffsstufen.
func debug_scenario(name: String) -> void:
	match name:
		"network":
			for f in ["collection", "helpers", "drones", "courier"]:
				_world.unlocked_features[f] = true
			_world.bolts += 5000
			_world.bolts_changed.emit(_world.bolts)
			var pt := _world.place_free("collection_point", _world.player_tile() + Vector2i(5, -4), 0)
			if pt != null:
				NetworkSystem.on_point_built(_world, pt as CollectionPoint)
				(pt as CollectionPoint).accept_stack("scrap", 30)
				_world.building_changed.emit(pt)
			for i in 3:
				_world.queue_command({"type": "buy_helper"})
			var inv := _world.player.inventory
			for i in inv.slot_count:
				inv.add("scrap", inv.stack_size)
		"army":
			# 40 Bots in allen Zonen, Sammelstellen, 12 Drohnen: Leistungstest
			for f in ["collection", "helpers", "drones", "courier", "helper_tools"]:
				_world.unlocked_features[f] = true
			for z: Dictionary in _world.zones.zones:
				_world.zones.unlocked[str(z["id"])] = true
			_world.bolts += 1000000
			for z: Dictionary in _world.zones.zones:
				var r: Rect2i = z["rect"]
				var pt := _world.place_free("collection_point", r.get_center(), 0)
				if pt != null:
					(pt as CollectionPoint).accept_stack("scrap", 60)
			while _world.drones.size() < int(_world.drone_cfg.get("max_drones", 12)):
				_world.add_drone()
			var zs: Array = _world.zones.zones
			for i in int(_world.helper_cfg.get("max_helpers", 40)):
				var zr: Rect2i = zs[i % zs.size()]["rect"]
				var hh := HelperSystem.add_helper(_world, zr.get_center(), _world.ship().tile)
				hh.zone_id = str(zs[i % zs.size()]["id"])
		"endgame":
			_world.bolts += 100000
			_world.bolts_changed.emit(_world.bolts)
		"helpers":
			_world.unlocked_features["helpers"] = true
			_world.unlocked_features["helper_tools"] = true
			_world.bolts += 3000
			_world.bolts_changed.emit(_world.bolts)
			_world.queue_command({"type": "buy_helper", "zone": _world.player_tile() + Vector2i(-4, -3)})
			_world.queue_command({"type": "buy_helper", "zone": _world.player_tile() + Vector2i(5, 3)})
		"drones":
			_world.unlocked_features["drones"] = true
			_world.bolts += 3000
			_world.bolts_changed.emit(_world.bolts)
			for i in 30:
				_world.add_loose("scrap", _world.player.pos + Vector2i(_world.rng.randi_range(-300, 300), _world.rng.randi_range(150, 400)))
			_world.queue_command({"type": "buy_drone"})
			_world.queue_command({"type": "buy_drone"})


## Rusty liefert ab: kleiner Spruch beim ersten Mal und bei großen Lieferungen.
func _on_ship_delivered(_items: Dictionary, bolts: int, by_player: bool) -> void:
	if not by_player:
		return
	Sfx.play("deliver", 0.04)
	if not bool(_world.flags.get("first_delivery", false)):
		_world.flags["first_delivery"] = true
		Quips.say("first_delivery", true)
	elif bolts >= 100:
		Quips.say("big_delivery")


func _on_zone_stage_changed(zone_id: String, stage: int) -> void:
	if stage >= 2:
		_player.celebrate()
	var z := _world.zones.zone_by_id(zone_id)
	EventBus.quip.emit(["ZONE_Q_0", "ZONE_Q_1", "ZONE_Q_2", "ZONE_Q_3"][stage])
	_hud.set_tutorial(_hud.get_node("Tutorial/Label").text)  # unverändert lassen
	print("Zone %s → Stufe %d" % [str(z.get("name", zone_id)), stage])


func _on_collectible_found(_c: Collectible, def: Dictionary) -> void:
	_player.celebrate()
	Quips.say("collectible_found", true)
	_hud.set_tutorial(tr("HUD_FOUND") % tr(str(def.get("name_key", "?"))))
	_chapter_timer = 5.0


## Zonen-Heilung (Phase 2): Dekor und Tiere je Stufe, Tageslicht, Regen.
func _setup_nature() -> void:
	var cfg := NaturePlanner.load_config()
	_nature = NatureView.new()
	_nature.name = "Nature"
	add_child(_nature)
	_nature.bind(_world, _player, cfg)
	_world_view.dirt_view.tiles_changed.connect(_nature.on_tiles_changed)
	_nature.critters_appeared.connect(func(_id: String) -> void: Quips.say("critter", true))
	_sky = DayLight.new()
	_sky.name = "Sky"
	_sky.setup(cfg)
	add_child(_sky)
	_rain = RainLayer.new()
	_rain.name = "Rain"
	add_child(_rain)
	_sky.rain_started.connect(func() -> void:
		_rain.set_raining(true)
		Quips.say("rain", true))
	_sky.rain_stopped.connect(func() -> void: _rain.set_raining(false))


## Aufgaben-Anzeige oben: genau eine aktuelle Aufgabe mit Haken; ohne Aufgaben das Zonenziel.
func _refresh_chapter_hud() -> void:
	var q := _world.quests
	if not q.is_done():
		var p := q.progress(_world)
		var text := tr(str(q.current().get("text_key", "")))
		if int(p[1]) > 1:
			text += "  (%d/%d)" % [int(p[0]), int(p[1])]
		_hud.set_tutorial("☐  " + text)
		return
	var cur := _world.zones.current_chapter_zone()
	if cur == "":
		_hud.set_tutorial("")
		return
	var z := _world.zones.zone_by_id(cur)
	var pct := int(round(_world.zones.cleanliness(cur, _world.nodes) * 100.0))
	var idx := _world.zones.chapter_index(cur) + 1
	var next := _world.zones.next_chapter_zone()
	var text := tr("CH_HUD") % [idx, str(z.get("name", cur)), pct]
	if next != "":
		text += "  ·  " + tr("CH_HUD_GATE") % int(round(_world.zones.unlock_cleanliness * 100.0))
	else:
		text += "  ·  " + tr("CH_HUD_LAST")
	_hud.set_tutorial(text)


## Boss geknackt: großes Schild, Fanfare, Konfetti; das Tor öffnet sich (Sim prüft es im Tick).
## Rusty ruft Verstärkung: beim ersten Mal Erklärkarte, sonst Spruch; kurz wackeln.
func _on_boss_rally(boss: ResourceNode, _called: int) -> void:
	if not _world.flags.has("boss_help_seen"):
		_world.flags["boss_help_seen"] = true
		_hud.stage_banner.show_card(tr("BOSS_HELP_TITLE"), tr("BOSS_HELP_SUB"), "", str(ResourceNode.defs.get(boss.kind, {}).get("sprite", "")), 4.5)
	EventBus.quip.emit("QUIP_RALLY")
	Sfx.play("honk")
	_shake(10.0, 0.35)


## Kurzer Trefferstopp beim Ein-Schlag: Zeit fast anhalten, dann weiter (Echtzeit-Timer).
func _hit_stop(seconds: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _shake(strength: float, seconds: float) -> void:
	var cam: Camera2D = _player.get_node("Camera2D")
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		cam.offset += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - t), 0.0, 1.0, seconds)


func _on_boss_defeated(kind: String, _zone_id: String, reward: int) -> void:
	_player.celebrate()
	Sfx.play("repair")
	var def: Dictionary = ResourceNode.defs.get(kind, {})
	var final := bool(def.get("final", false))
	_hud.stage_banner.show_card(tr("BOSS_DEFEATED_TITLE"), tr("BOSS_DEFEATED_SUB") % tr(str(def.get("name_key", kind))),
		(tr("BOSS_FINAL_REWARD") if final else tr("BOSS_DEFEATED_REWARD")) % Fmt.int_str(reward), str(def.get("sprite", "")), 3.2)


## Meilenstein: Pokal-Schild mit Zahl und Belohnung, Arpeggio, Konfetti.
func _on_milestone_reached(def: Dictionary, _step: int, value: int, bolts: int) -> void:
	_player.celebrate()
	Sfx.play("milestone")
	_hud.stage_banner.show_card(tr("MS_TITLE"), tr(str(def.get("name_key", ""))) % Fmt.int_str(value),
		tr("MS_REWARD") % Fmt.int_str(bolts) if bolts > 0 else "", "res://assets/sprites/ui/trophy.svg", 2.6)


func _on_quest_completed(_id: String, def: Dictionary) -> void:
	_player.celebrate()
	Sfx.play("quest")
	Quips.say("quest_done", true)
	_hud.set_tutorial("☑  " + tr("HUD_QUEST_DONE") % tr(str(def.get("text_key", ""))))
	_chapter_timer = 2.5


## Kauf-Jubel: Menü schließen, Rusty hüpft, dreht sich, Sterne, Jingle. Eingaben ruhen so lange
## (höchstens CHEER_SECONDS), danach geht es sofort weiter. Mehrere Käufe im selben Frame jubeln einmal.
func _celebrate_purchase(jingle: bool = true) -> void:
	if _launching or _player.is_cheering():
		return
	if _progress_menu.visible:
		_progress_menu.close()
	InputRouter.context = InputRouter.Context.MENU
	_player.cheer()
	Sfx.play("boing", 0.04)
	if jingle:
		Sfx.play("cheer", 0.03)
	get_tree().create_timer(Player.CHEER_SECONDS).timeout.connect(func() -> void:
		if not _launching and InputRouter.context == InputRouter.Context.MENU and not _any_menu_open():
			InputRouter.context = InputRouter.Context.GAME)


func _any_menu_open() -> bool:
	return _progress_menu.visible or _pause_menu.visible or _end_screen.visible


## Reparatur: Menü zu, Kamera zum Schiff, Konfetti, Putzring, Jubel-Schild. Auf der letzten Stufe
## folgt der Abflug.
func _on_ship_upgraded(s: Ship) -> void:
	_celebrate_purchase(false)
	_player.celebrate()
	Sfx.play("repair")
	Quips.say("ship_upgraded", true)
	var sd := ShipSystem.stage_def(_world, s.stage)
	_hud.set_tutorial(tr("HUD_SHIP_UP") % [s.stage, tr(str(sd.get("name_key", "")))])
	_chapter_timer = 4.0
	var gifts: Array[String] = []
	for f in sd.get("unlocks", []):
		gifts.append(tr("GIFT_" + str(f).to_upper()))
	_hud.stage_banner.show_stage(s.stage, tr(str(sd.get("name_key", ""))), s.sprite_path, gifts)
	var view := _world_view.ship_view()
	if view != null and view.ship_fx != null:
		view.ship_fx.celebrate(ShipSystem.clean_target(_world, s))
		_focus_camera(view, 1.2)
	if s.stage >= ShipSystem.max_stage(_world):
		save_game()
		get_tree().create_timer(2.5).timeout.connect(_launch_sequence)


## Finale (MS37): Rundflug über alle Zonen, dann Abflug. Rusty kann nicht fahren, die Kamera folgt
## dem Schiff nach oben, Weißblende, Abspann. Danach steht das Schiff wieder da und es geht weiter.
func _launch_sequence() -> void:
	var view := _world_view.ship_view()
	if view == null or view.ship_fx == null:
		_end_screen.show_stats(_world)
		return
	if _progress_menu.visible:
		_progress_menu.close()
	InputRouter.context = InputRouter.Context.MENU
	_launching = true
	await _finale_tour()
	_focus_camera(view)
	await get_tree().create_timer(1.2).timeout
	EventBus.quip.emit("LAUNCH_Q")
	Sfx.play("launch")
	var base := view.position
	_focus_camera(view)
	view.ship_fx.launch()
	await view.ship_fx.launch_finished
	await _fade_to(1.0, 0.9)
	view.ship_fx.land(base)
	_cam_focus = null
	_launching = false
	_end_screen.show_stats(_world)
	_fade_to(0.0, 0.8)


## Kamera fliegt jede Zone an und zeigt, wie sauber sie geworden ist.
func _finale_tour() -> void:
	EventBus.quip.emit("FINALE_TOUR_Q")
	var marker := Node2D.new()
	_world_view.add_child(marker)
	for z in _world.zones.summary(_world.nodes):
		var r: Rect2i = z["rect"]
		marker.position = Vector2(r.get_center() * ResourceNode.TILE)
		_focus_camera(marker)
		_hud.stage_banner.show_card(str(z["name"]), tr("FINALE_ZONE") % int(round(float(z["cleanliness"]) * 100.0)), "",
			"res://assets/sprites/ui/tab_map.svg", 1.6)
		await get_tree().create_timer(1.9).timeout
	marker.queue_free()


func _on_credits_closed() -> void:
	_hud.stage_banner.show_card(tr("FINALE_AFTER_TITLE"), tr("FINALE_AFTER_SUB"), "", "res://assets/sprites/robot/rusty.svg", 3.5)
	EventBus.quip.emit("FINALE_AFTER_Q")


func _focus_camera(target: Node2D, seconds: float = 0.0) -> void:
	_cam_focus = target
	_cam_focus_time = seconds


func _update_camera_focus(delta: float) -> void:
	var cam: Camera2D = _player.get_node("Camera2D")
	if _cam_focus_time > 0.0:
		_cam_focus_time -= delta
		if _cam_focus_time <= 0.0:
			_cam_focus = null
	var target := Vector2.ZERO
	if _cam_focus != null and is_instance_valid(_cam_focus):
		target = _cam_focus.global_position - _player.global_position
	cam.offset = cam.offset.lerp(target, 1.0 - exp(-5.0 * delta))


func _fade_to(alpha: float, seconds: float) -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(1, 1, 1, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", alpha, seconds)
	await tw.finished


func _ship_hint(s: Ship, kb: String) -> String:
	var sd := ShipSystem.stage_def(_world, s.stage)
	var load := _world.player.inventory.total()
	var deliver := tr("SHIP_HINT_DELIVER" + kb) % load if load > 0 else tr("SHIP_HINT_EMPTY")
	return "%s · %s %d (%s)   ·   %s   ·   %s" % [tr("BLD_SHIP"), tr("SHIP_STAGE"), s.stage, tr(str(sd.get("name_key", ""))), deliver, tr("SHIP_HINT_MENU" + kb)]


func _on_zone_unlocked(zone_id: String) -> void:
	_open_unlocked_gates()
	_player.celebrate()
	var z := _world.zones.zone_by_id(zone_id)
	EventBus.quip.emit("QUIP_BOSS_SPOTTED" if _world.zones.boss_alive(zone_id, _world.nodes) else "ZONE_UNLOCKED")
	_hud.set_tutorial(tr("CH_UNLOCKED") % str(z.get("name", zone_id)))
	_chapter_timer = 4.0


## Zäune aus Schrottbergen an allen Zonengrenzen; Tore zwischen Nachbarzonen öffnen sich mit dem Kapitel.
func _build_zone_fences() -> void:
	var fence_tex := load("res://assets/sprites/tiles/fence.svg")
	var gate_tex := load("res://assets/sprites/tiles/gate.svg")
	var zones := _world.zones.zones
	var fence_tiles: Dictionary = {}
	var gate_tiles: Dictionary = {}  # tile → pair key
	for z in zones:
		var r: Rect2i = z["rect"]
		if r.end.x < _world.width_tiles:
			for y in range(r.position.y, r.end.y):
				fence_tiles[Vector2i(r.end.x, y)] = true
		if r.end.y < _world.height_tiles:
			for x in range(r.position.x, r.end.x + 1):
				fence_tiles[Vector2i(x, r.end.y)] = true
	# Tore: Mitte jeder gemeinsamen Kante zweier Nachbarzonen, 6 Kacheln breit
	for i in zones.size():
		for j in zones.size():
			if j <= i:
				continue
			var a: Rect2i = zones[i]["rect"]
			var b: Rect2i = zones[j]["rect"]
			var key := "%s|%s" % [zones[i]["id"], zones[j]["id"]]
			if a.end.x == b.position.x and a.position.y == b.position.y:      # b rechts von a
				var cy := a.position.y + a.size.y / 2
				for y in range(cy - 3, cy + 3):
					gate_tiles[Vector2i(a.end.x, y)] = key
			elif b.end.x == a.position.x and a.position.y == b.position.y:   # b links von a
				var cy := a.position.y + a.size.y / 2
				for y in range(cy - 3, cy + 3):
					gate_tiles[Vector2i(b.end.x, y)] = key
			elif a.end.y == b.position.y and a.position.x == b.position.x:   # b unter a
				var cx := a.position.x + a.size.x / 2
				for x in range(cx - 3, cx + 3):
					gate_tiles[Vector2i(x, a.end.y)] = key
			elif b.end.y == a.position.y and a.position.x == b.position.x:   # b über a
				var cx := a.position.x + a.size.x / 2
				for x in range(cx - 3, cx + 3):
					gate_tiles[Vector2i(x, b.end.y)] = key
	for t in fence_tiles.keys():
		if t.x >= _world.width_tiles or t.y >= _world.height_tiles:
			continue
		var is_gate := gate_tiles.has(t)
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 64)
		shape.shape = rect
		body.add_child(shape)
		body.position = Vector2(t * 64) + Vector2(32, 32)
		var sprite := Sprite2D.new()
		sprite.texture = gate_tex if is_gate else fence_tex
		sprite.z_index = 3
		body.add_child(sprite)
		add_child(body)
		_world.blocked_tiles[t] = true
		if is_gate:
			var key: String = gate_tiles[t]
			if not _zone_gates.has(key):
				_zone_gates[key] = []
			_zone_gates[key].append(body)


## Entfernt alle Tore zwischen zwei freigeschalteten Zonen.
func _open_unlocked_gates() -> void:
	for key in _zone_gates.keys():
		var parts: PackedStringArray = key.split("|")
		if _world.zones.is_unlocked(parts[0]) and _world.zones.is_unlocked(parts[1]):
			for n in _zone_gates[key]:
				if is_instance_valid(n):
					var t := Vector2i((n.position - Vector2(32, 32)) / 64.0)
					_world.blocked_tiles.erase(t)
					n.queue_free()
			_zone_gates.erase(key)


func _on_level_up(_level: int, _points: int) -> void:
	_player.celebrate()
	Quips.say("level_up", true)


## Hinweiszeile je nach Kontext und Eingabegerät (Gamepad-Tasten oder Tastatur/Maus).
func _current_hint() -> String:
	var kb := "" if InputRouter.is_gamepad else "_KB"
	if _launching or _player.is_cheering():
		return ""
	match InputRouter.context:
		InputRouter.Context.MENU:
			# Das Fortschritts-Menü hat eine eigene Fußzeile: unten keine zweite
			return "" if _progress_menu.visible else tr("HINT_MENU" + kb)
	var b := _player.nearby_building()
	if b != null and b is Ship:
		return _ship_hint(b as Ship, kb)
	var site := NetworkSystem.site_near_player(_world)
	if b == null and site != "":
		if not _world.is_building_unlocked(NetworkSystem.POINT_DEF):
			return tr("HINT_SITE_LOCKED")
		var cost := int(_world.next_cost(_world.defs[NetworkSystem.POINT_DEF]).get("bolts", 0))
		return tr("HINT_SITE" + kb) % Fmt.int_str(cost)
	if b != null and b is CollectionPoint:
		return tr("HINT_POINT" + kb) % [(b as CollectionPoint).total(), _world.player.inventory.total()]
	if b != null:
		var slot: Dictionary = _world.player.inventory.slots[_player.selected_slot]
		if slot["item"] != "":
			return tr("HINT_DEPOSIT" + kb) % [slot["count"], DataRegistry.item_name(slot["item"]), tr(b.def.name_key)]
		if not b.contents().is_empty():
			return tr("HINT_WITHDRAW" + kb) % tr(b.def.name_key)
	if _progress_menu.has_new_tab():
		return tr("HUD_HINT_NEW_TAB" + kb)
	return tr("HUD_HINT_GAME" + kb)


func _on_building_placed(_b: Building) -> void:
	pass


func _on_item_collected(item_id: String, _from: Vector2i) -> void:
	if not _first_collected.has(item_id):
		_first_collected[item_id] = true
		Quips.say("first_" + item_id)


func _build_ground(px: int, py: int) -> void:
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = load("res://assets/sprites/tiles/ground.svg")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, px, py)
	ground.centered = false
	ground.z_index = -10
	add_child(ground)
	move_child(ground, 0)


func _build_walls(px: int, py: int) -> void:
	var t := GameConfig.TILE_SIZE
	var walls := [
		Rect2(-t, -t, px + 2 * t, t),   # oben
		Rect2(-t, py, px + 2 * t, t),   # unten
		Rect2(-t, 0, t, py),            # links
		Rect2(px, 0, t, py),            # rechts
	]
	for wall: Rect2 in walls:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall.size
		shape.shape = rect
		shape.position = wall.position + wall.size / 2.0
		body.add_child(shape)
		add_child(body)
