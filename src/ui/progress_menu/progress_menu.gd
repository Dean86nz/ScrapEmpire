extends CanvasLayer
## Schiff- und Fortschritts-Menü (Select, oder X am Schiff). Tabs: Schiff, Kapitel, Skills, Karte,
## Bots, Drohnen, Journal. LB/RB wechseln den Tab, D-Pad bewegt den Fokus, A kauft, B schließt.

enum Tab { SHIP, GOALS, SKILLS, MAP, HELPERS, DRONES, JOURNAL }
const TAB_COUNT := 7

const CARD_SCENE_MIN := Vector2(440, 150)
const SHIP_CARD_MIN := Vector2(440, 160)
const COST_OK := Color(0.18, 0.55, 0.24)
const COST_NO := Color(0.75, 0.25, 0.2)
const UPG_ICONS := {"speed": "res://assets/sprites/ui/upg_speed.svg", "capacity": "res://assets/sprites/ui/upg_cargo.svg", "tool": "res://assets/sprites/ui/upg_tool.svg"}
const TAB_ICONS := ["res://assets/sprites/buildings/ship_2.svg", "res://assets/sprites/ui/tab_goals.svg", "res://assets/sprites/ui/tab_skills.svg",
	"res://assets/sprites/ui/tab_map.svg", "res://assets/sprites/robot/rusty.svg", "res://assets/sprites/robot/drone.svg", "res://assets/sprites/ui/tab_journal.svg"]
const REFRESH_SECONDS := 0.5

@onready var _tab_labels: Array[Label] = [$Center/Panel/VBox/Tabs/TabTech, $Center/Panel/VBox/Tabs/TabGoals, $Center/Panel/VBox/Tabs/TabSkills, $Center/Panel/VBox/Tabs/TabMap, $Center/Panel/VBox/Tabs/TabHelpers, $Center/Panel/VBox/Tabs/TabDrones, $Center/Panel/VBox/Tabs/TabJournal]
@onready var _journal_tab: Control = $Center/Panel/VBox/Content/JournalTab
@onready var _journal_list: VBoxContainer = $Center/Panel/VBox/Content/JournalTab/List
@onready var _drones_tab: Control = $Center/Panel/VBox/Content/DronesTab
@onready var _drone_buy_btn: Button = $Center/Panel/VBox/Content/DronesTab/Left/BuyButton
@onready var _drone_list: VBoxContainer = $Center/Panel/VBox/Content/DronesTab/Left/DroneList
@onready var _drone_upgrade_list: VBoxContainer = $Center/Panel/VBox/Content/DronesTab/Right/UpgradeList
@onready var _drone_upgrade_title: Label = $Center/Panel/VBox/Content/DronesTab/Right/UpgradeTitle
var _drone_upgrade_cards: Dictionary = {}
var _drone_cards: Dictionary = {}  # Button → drone id
@onready var _helpers_tab: Control = $Center/Panel/VBox/Content/HelpersTab
@onready var _buy_btn: Button = $Center/Panel/VBox/Content/HelpersTab/Left/BuyButton
@onready var _helper_list: VBoxContainer = $Center/Panel/VBox/Content/HelpersTab/Left/HelperList
@onready var _upgrade_list: VBoxContainer = $Center/Panel/VBox/Content/HelpersTab/Right/UpgradeList
@onready var _upgrade_title: Label = $Center/Panel/VBox/Content/HelpersTab/Right/UpgradeTitle
var _upgrade_cards: Dictionary = {}
var _helper_cards: Array[Button] = []
@onready var _map_tab: Control = $Center/Panel/VBox/Content/MapTab
@onready var _map_view: MapView = $Center/Panel/VBox/Content/MapTab/MapView
@onready var _map_info: Label = $Center/Panel/VBox/Content/MapTab/Info
@onready var _ship_grid: GridContainer = $Center/Panel/VBox/Content/TechTab/Grid
@onready var _skill_columns: HBoxContainer = $Center/Panel/VBox/Content/SkillsTab/Columns
@onready var _skill_points_label: Label = $Center/Panel/VBox/Content/SkillsTab/Points
@onready var _goals_list: VBoxContainer = $Center/Panel/VBox/Content/GoalsTab/List
@onready var _ship_tab: Control = $Center/Panel/VBox/Content/TechTab
@onready var _skills_tab: Control = $Center/Panel/VBox/Content/SkillsTab
@onready var _goals_tab: Control = $Center/Panel/VBox/Content/GoalsTab
@onready var _footer: Label = $Center/Panel/VBox/Footer

var _world: SimWorld
var _tab: Tab = Tab.SHIP
var _ship_cards: Dictionary = {}   # "upg:<id>", "repair", "bot", "drone" → Button
var _skill_cards: Dictionary = {}  # id → Button
var _refresh_timer := 0.0
var _stage_track := StageTrack.new()
var _goal_lines: Array[String] = []   # zuletzt gezeigte Ziele (nur bei Änderung neu bauen, sonst geht der Fokus verloren)
var _journal_sig := ""


func _ready() -> void:
	visible = false


func bind(world: SimWorld) -> void:
	_world = world
	# Schiff-Tab: Stufenleiste über dem Kartenraster (ScrollContainer braucht genau ein Kind)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	_ship_tab.remove_child(_ship_grid)
	_ship_tab.add_child(col)
	col.add_child(_stage_track)
	col.add_child(_ship_grid)
	_stage_track.bind(world)
	_build_ship_cards()
	_build_skill_cards()
	_map_view.zone_selected.connect(_on_zone_selected)
	_buy_btn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_helper"}))
	_upgrade_title.text = tr("HELPER_UPGRADES")
	for u: Dictionary in _world.helper_cfg.get("upgrades", []):
		var id := str(u["id"])
		var btn := _make_card(tr(str(u["name_key"])), _upg_icon(id))
		btn.custom_minimum_size = Vector2(560, 162)
		btn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_helper_upgrade", "id": id}))
		_upgrade_list.add_child(btn)
		_upgrade_cards[id] = btn
	_drone_buy_btn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_drone"}))
	_drone_upgrade_title.text = tr("DRONE_UPGRADES")
	for u: Dictionary in _world.drone_cfg.get("upgrades", []):
		var uid := str(u["id"])
		var ubtn := _make_card(tr(str(u["name_key"])), _upg_icon(uid))
		ubtn.custom_minimum_size = Vector2(560, 162)
		ubtn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_drone_upgrade", "id": uid}))
		_drone_upgrade_list.add_child(ubtn)
		_drone_upgrade_cards[uid] = ubtn
	_build_tab_icons()
	_tab_labels[Tab.SHIP].text = tr("MENU_TAB_SHIP")
	_tab_labels[Tab.DRONES].text = tr("MENU_TAB_DRONES")
	_tab_labels[Tab.JOURNAL].text = tr("MENU_TAB_JOURNAL")
	_tab_labels[Tab.HELPERS].text = tr("MENU_TAB_BOTS")
	_tab_labels[Tab.GOALS].text = tr("MENU_TAB_GOALS")
	_tab_labels[Tab.SKILLS].text = tr("MENU_TAB_SKILLS")
	_tab_labels[Tab.MAP].text = tr("MENU_TAB_MAP")


## Am Anfang nur Schiff, Ziele, Karte. Die anderen Tabs kommen, sobald sie etwas zu bieten haben.
func _tab_enabled(t: int) -> bool:
	match t:
		Tab.HELPERS:
			return _world.unlocked_features.has("helpers")
		Tab.DRONES:
			return _world.unlocked_features.has("drones")
		Tab.SKILLS:
			return _world.progression.level >= 2 or _world.progression.skill_points > 0
		Tab.JOURNAL:
			return not _world.collectibles_found.is_empty() or _world.building_count("museum") > 0
	return true


## Jeder Tab bekommt ein Icon links und einen orangen Punkt, solange er neu und noch nicht besucht ist.
func _build_tab_icons() -> void:
	for i in _tab_labels.size():
		var label := _tab_labels[i]
		var parent := label.get_parent()
		var idx := label.get_index()
		var box := HBoxContainer.new()
		box.name = "TabBox%d" % i
		box.add_theme_constant_override("separation", 8)
		parent.add_child(box)
		parent.move_child(box, idx)
		parent.remove_child(label)
		var icon := TextureRect.new()
		icon.texture = load(TAB_ICONS[i])
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
		box.add_child(label)
		var dot := Label.new()
		dot.name = "NewDot"
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 22)
		dot.add_theme_color_override("font_color", Color(0.95, 0.4, 0.15))
		dot.visible = false
		box.add_child(dot)


func _upg_icon(id: String) -> String:
	for k: String in UPG_ICONS:
		if id.ends_with(k):
			return UPG_ICONS[k]
	return ""


func _tab_seen(t: int) -> bool:
	return bool(_world.flags.get("tab_seen_%d" % t, t == Tab.SHIP or t == Tab.GOALS or t == Tab.MAP))


func has_new_tab() -> bool:
	for t in TAB_COUNT:
		if _tab_enabled(t) and not _tab_seen(t):
			return true
	return false


func _next_tab(dir: int) -> void:
	var t := int(_tab)
	for i in TAB_COUNT:
		t = (t + dir + TAB_COUNT) % TAB_COUNT
		if _tab_enabled(t):
			_tab = t as Tab
			return


func bind_player(player: Node2D) -> void:
	_map_view.bind(_world, player)


func set_dirt_texture(tex: Texture2D) -> void:
	_map_view.dirt_texture = tex


func _on_zone_selected(info: Dictionary) -> void:
	if not _world.zones.is_unlocked(str(info["id"])):
		_map_info.text = "%s %d\n\n%s\n\n%s" % [tr("CH_CHAPTER"), _world.zones.chapter_index(str(info["id"])) + 1, tr("ZONE_UNKNOWN"), tr("ZONE_HELP")]
		return
	var stage_key: String = ["ZONE_STAGE_0", "ZONE_STAGE_1", "ZONE_STAGE_2", "ZONE_STAGE_3"][int(info["stage"])]
	var tiers: Array[String] = []
	var by_tier: Dictionary = info["trash_by_tier"]
	var keys := by_tier.keys()
	keys.sort()
	for t in keys:
		tiers.append("T%d: %d" % [int(t), int(by_tier[t])])
	_map_info.text = "%s\n\n%s: %d %%\n%s\n\n%s: %d / %d\n%s\n\n%s" % [
		str(info["name"]), tr("ZONE_CLEAN"), int(round(float(info["cleanliness"]) * 100.0)), tr(stage_key),
		tr("ZONE_TRASH"), int(info["trash_now"]), int(info["trash_start"]),
		(tr("ZONE_BY_TIER") + " " + ", ".join(tiers)) if not tiers.is_empty() else tr("ZONE_NO_TRASH"),
		tr("ZONE_HELP")]


func open(tab: Tab = Tab.SHIP) -> void:
	_tab = tab
	visible = true
	InputRouter.context = InputRouter.Context.MENU
	_refresh_all()
	_show_tab()


func close() -> void:
	visible = false
	InputRouter.context = InputRouter.Context.GAME


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_SECONDS
		_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if MenuInput.back_pressed(event) or event.is_action_pressed("tech_tree"):
		close()
		get_viewport().set_input_as_handled()
	elif MenuInput.accept_pressed(event) and _tab != Tab.MAP:
		MenuInput.press_focused(get_viewport())
	elif event.is_action_pressed("hotbar_next"):
		_next_tab(1)
		_show_tab()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_prev"):
		_next_tab(-1)
		_show_tab()
		get_viewport().set_input_as_handled()
	elif _tab == Tab.MAP and _map_view.handle_input(event):
		get_viewport().set_input_as_handled()
	elif _tab == Tab.DRONES and event.is_action_pressed("tool_secondary"):
		# LT auf einer Drohnenkarte: Drohne abbauen
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _drone_cards.has(f):
			SimClock.world.queue_command({"type": "remove_drone", "id": _drone_cards[f]})
			get_viewport().set_input_as_handled()
	elif _tab == Tab.HELPERS and event.is_action_pressed("tool_secondary"):
		# LT auf einer Bot-Karte: Bot abbauen (A baut nichts ab, damit nichts aus Versehen verschwindet)
		var fh := get_viewport().gui_get_focus_owner()
		if fh != null and _helper_cards.has(fh):
			SimClock.world.queue_command({"type": "remove_helper", "id": int(fh.get_meta("helper_id", -1))})
			get_viewport().set_input_as_handled()


# --- Aufbau ---------------------------------------------------------------

## Karte: optional großes Icon links, rechts Titel, Stufen-Punkte, Text und Kostenzeile (Bolt-Symbol).
func _make_card(title: String, icon_path: String = "") -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SCENE_MIN
	btn.text = ""
	btn.clip_contents = true
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16 if icon_path != "" else 20
	row.offset_top = 10
	row.offset_right = -16
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 14)
	btn.add_child(row)
	if icon_path != "":
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(84, 84)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.name = "Title"
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(0.165, 0.165, 0.2))
	var detail := Label.new()
	detail.name = "Detail"
	detail.add_theme_font_size_override("font_size", 22)
	detail.add_theme_color_override("font_color", Color(0.3, 0.3, 0.36))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pips := Label.new()
	pips.name = "Pips"
	pips.add_theme_font_size_override("font_size", 22)
	pips.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	pips.visible = false
	var cost := HBoxContainer.new()
	cost.name = "Cost"
	cost.visible = false
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bolt := TextureRect.new()
	bolt.name = "Bolt"
	bolt.texture = load("res://assets/sprites/ui/bolt.svg")
	bolt.custom_minimum_size = Vector2(30, 30)
	bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bolt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bolt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Label.new()
	value.name = "Value"
	value.add_theme_font_size_override("font_size", 26)
	cost.add_child(bolt)
	cost.add_child(value)
	box.add_child(name_label)
	box.add_child(pips)
	box.add_child(detail)
	box.add_child(cost)
	row.add_child(box)
	return btn


func _part(btn: Button, part: String) -> Control:
	return btn.find_child(part, true, false) as Control


func _set_card(btn: Button, detail: String, tint: Color) -> void:
	(_part(btn, "Detail") as Label).text = detail
	btn.self_modulate = tint


func _set_title(btn: Button, title: String) -> void:
	(_part(btn, "Title") as Label).text = title


func _set_icon(btn: Button, path: String) -> void:
	var icon := _part(btn, "Icon") as TextureRect
	if icon != null and (icon.texture == null or icon.texture.resource_path != path):
		icon.texture = load(path)


func _set_pips(btn: Button, level: int, max_level: int) -> void:
	var p := _part(btn, "Pips") as Label
	p.visible = max_level > 1
	p.text = "●".repeat(level) + "○".repeat(maxi(max_level - level, 0))


## Kostenzeile: Bolt-Symbol mit Betrag (grün = leistbar, rot = fehlt) oder ein kurzer Text ohne Symbol.
func _set_cost(btn: Button, text: String, color: Color, with_bolt: bool) -> void:
	var c := _part(btn, "Cost")
	c.visible = text != ""
	(_part(btn, "Bolt") as TextureRect).visible = with_bolt
	var v := _part(btn, "Value") as Label
	v.text = text
	v.add_theme_color_override("font_color", color)


## Schiff-Tab: Reparatur, fünf Upgrades, Bot und Drohne bauen.
func _build_ship_cards() -> void:
	for c in _ship_grid.get_children():
		c.queue_free()
	_ship_cards.clear()
	var repair := _make_card(tr("SHIP_REPAIR"), "res://assets/sprites/buildings/ship_2.svg")
	repair.custom_minimum_size = SHIP_CARD_MIN
	repair.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "upgrade_ship"}))
	_ship_grid.add_child(repair)
	_ship_cards["repair"] = repair
	for u: Dictionary in ShipSystem.upgrade_defs(_world):
		var id := str(u["id"])
		var btn := _make_card(tr(str(u["name_key"])), str(u.get("icon", "")))
		btn.custom_minimum_size = SHIP_CARD_MIN
		btn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_upgrade", "id": id}))
		_ship_grid.add_child(btn)
		_ship_cards["upg:" + id] = btn
	var bot := _make_card(tr("BOT_BUILD"), "res://assets/sprites/robot/rusty.svg")
	bot.custom_minimum_size = SHIP_CARD_MIN
	(_part(bot, "Icon") as TextureRect).modulate = Color(0.75, 0.9, 1.0)
	bot.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_helper"}))
	_ship_grid.add_child(bot)
	_ship_cards["bot"] = bot
	var drone := _make_card(tr("DRONE_BUILD"), "res://assets/sprites/robot/drone.svg")
	drone.custom_minimum_size = SHIP_CARD_MIN
	drone.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_drone"}))
	_ship_grid.add_child(drone)
	_ship_cards["drone"] = drone


func _build_skill_cards() -> void:
	for c in _skill_columns.get_children():
		c.queue_free()
	_skill_cards.clear()
	for br: Dictionary in _world.skills.branches:
		var skills := _world.skills.skills_in_branch(str(br["id"]))
		if skills.is_empty():
			continue
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		var header := Label.new()
		header.text = tr(str(br["name_key"]))
		header.add_theme_font_size_override("font_size", 28)
		header.add_theme_color_override("font_color", Color.html(str(br.get("color", "#FFFFFF"))))
		header.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
		header.add_theme_constant_override("outline_size", 8)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(header)
		for d: Dictionary in skills:
			var id := str(d["id"])
			var btn := _make_card(tr(str(d["name_key"])))
			btn.custom_minimum_size = Vector2(350, 150)
			btn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_skill", "id": id}))
			col.add_child(btn)
			_skill_cards[id] = btn
		_skill_columns.add_child(col)


# --- Aktualisieren ----------------------------------------------------------

const TINT_OK := Color.WHITE
const TINT_NO := Color(0.85, 0.85, 0.85)
const TINT_DONE := Color(0.75, 1.0, 0.8)


func _bolts_text(n: int) -> String:
	return "%d %s" % [n, tr("HUD_BOLTS")]


func _missing_text(cost: int) -> String:
	return tr("TECH_MISSING_BOLTS") % (cost - _world.bolts)


func _refresh_ship() -> void:
	var w := _world
	var s := w.ship()
	_stage_track.refresh()
	# Reparatur: Bild der nächsten Stufe, Geschenke, Kosten
	var repair: Button = _ship_cards["repair"]
	if s == null:
		_set_card(repair, "", TINT_NO)
	else:
		var reason := ShipSystem.can_upgrade(w, s)
		if reason == "max":
			_set_title(repair, tr("SHIP_REPAIRED"))
			_set_card(repair, "", TINT_DONE)
			_set_cost(repair, "✓", COST_OK, false)
		else:
			_set_title(repair, tr("SHIP_REPAIR_TO") % (s.stage + 1))
			_set_icon(repair, str(ShipSystem.stage_def(w, s.stage + 1).get("sprite", "")))
			var gifts: Array[String] = []
			for f in ShipSystem.next_stage_unlocks(w, s):
				gifts.append("+ " + tr("GIFT_" + str(f).to_upper()))
			_set_card(repair, "  ".join(gifts), TINT_OK if reason == "" else TINT_NO)
			if reason == "planet":
				_set_cost(repair, tr("SHIP_NEEDS_PLANET") % int(round(float(ShipSystem.stage_def(w, s.stage + 1).get("requires_planet", 0.0)) * 100.0)), COST_NO, false)
			else:
				_set_cost(repair, Fmt.int_str(ShipSystem.next_stage_cost(w, s)), COST_OK if reason == "" else COST_NO, true)
	# Upgrades: Stufen-Punkte, kurzer Text, Kosten
	for u: Dictionary in ShipSystem.upgrade_defs(w):
		var id := str(u["id"])
		var btn: Button = _ship_cards["upg:" + id]
		var level := ShipSystem.upgrade_level(w, id)
		_set_pips(btn, level, int(u["max_level"]))
		var reason := ShipSystem.can_buy_upgrade(w, id)
		_set_card(btn, tr(str(u["desc_key"])), TINT_DONE if reason == "max" else (TINT_OK if reason == "" else TINT_NO))
		if reason == "max":
			_set_cost(btn, "✓ " + tr("SKILL_MAXED"), COST_OK, false)
		else:
			_set_cost(btn, Fmt.int_str(ShipSystem.upgrade_cost(w, id)), COST_OK if reason == "" else COST_NO, true)
	# Bot und Drohne
	_refresh_build_card(_ship_cards["bot"], "BOT_CARD", "BOT_DESC", "BOT_LOCKED", w.can_buy_helper(), int(w.next_helper_cost()["bolts"]),
		w.helpers.size(), int(w.helper_cfg.get("max_helpers", 10)))
	_refresh_build_card(_ship_cards["drone"], "DRONE_CARD", "DRONE_DESC", "DRONE_LOCKED", w.can_buy_drone(), int(w.next_drone_cost()["bolts"]),
		w.drones.size(), int(w.drone_cfg.get("max_drones", 6)))


func _refresh_build_card(btn: Button, title_key: String, desc_key: String, locked_key: String, reason: String, cost: int, have: int, max_n: int) -> void:
	_set_title(btn, "%s   %d/%d" % [tr(title_key), have, max_n])
	match reason:
		"locked":
			_set_card(btn, tr(locked_key), TINT_NO)
			_set_cost(btn, "", COST_NO, false)
		"max":
			_set_card(btn, tr(desc_key), TINT_DONE)
			_set_cost(btn, "✓ " + tr("SKILL_MAXED"), COST_OK, false)
		_:
			_set_card(btn, tr(desc_key), TINT_OK if reason == "" else TINT_NO)
			_set_cost(btn, Fmt.int_str(cost), COST_OK if reason == "" else COST_NO, true)


func _build_status(reason: String, cost: int, locked_key: String) -> String:
	match reason:
		"locked":
			return tr(locked_key)
		"max":
			return tr("SKILL_MAXED")
		"bolts":
			return "%s · %s" % [_bolts_text(cost), _missing_text(cost)]
		"":
			return "%s · %s" % [_bolts_text(cost), tr("SHIP_BUY")]
	return tr(locked_key)


func _upgrade_status(u: Dictionary, level: int, reason: String) -> String:
	var maxl := int(u["max_level"])
	var cost_txt := _bolts_text(int(u["cost_bolts"][level])) if level < maxl else ""
	var st := tr("HELPER_UPG_BUY")
	match reason:
		"max":
			st = tr("SKILL_MAXED")
		"locked":
			st = tr("HELPER_UPG_LOCKED")
		"bolts":
			st = _missing_text(int(u["cost_bolts"][level]))
	return "%d / %d · %s\n%s · %s" % [level, maxl, tr(str(u["desc_key"])), cost_txt, st]


func _refresh_helpers() -> void:
	var w := _world
	var reason := w.can_buy_helper()
	var cost := int(w.next_helper_cost()["bolts"])
	_buy_btn.text = "%s  –  %s" % [tr("BOT_BUILD"), _build_status(reason, cost, "BOT_LOCKED")]
	_buy_btn.disabled = reason != ""
	var focused_bot := -1
	var fb := get_viewport().gui_get_focus_owner()
	if fb != null and _helper_cards.has(fb):
		focused_bot = int(fb.get_meta("helper_id", -1))
	for c in _helper_list.get_children():
		_helper_list.remove_child(c)
		c.queue_free()
	_helper_cards.clear()
	var names: Array = w.helper_cfg.get("names", [])
	for h: Helper in w.helpers.values():
		var card := _make_card(h.display_name(names), "res://assets/sprites/robot/rusty.svg")
		(_part(card, "Icon") as TextureRect).modulate = Color(0.75, 0.9, 1.0)
		(_part(card, "Icon") as TextureRect).custom_minimum_size = Vector2(60, 60)
		card.custom_minimum_size = Vector2(740, 96)
		card.set_meta("helper_id", h.id)
		var state := tr("HELPER_STATE_WAIT") if h.tasks.wait_ticks > 0 else (tr("HELPER_STATE_WORK") if h.tasks.active else tr("HELPER_STATE_IDLE"))
		var zone_name: String = str(w.zones.zone_by_id(w.zones.zone_id_at(h.zone_tile)).get("name", "?"))
		_set_card(card, "%s · %s · %s %d/%d" % [state, zone_name, tr("HELPER_LOAD"), h.inventory.total(), h.inventory.slot_count * h.inventory.stack_size], Color.WHITE)
		_helper_list.add_child(card)
		_helper_cards.append(card)
		if h.id == focused_bot:
			card.grab_focus()
	for u: Dictionary in w.helper_cfg.get("upgrades", []):
		var id := str(u["id"])
		_refresh_upgrade_card(_upgrade_cards[id], u, int(w.helper_upgrades.get(id, 0)), w.can_buy_helper_upgrade(id))


## Upgrade-Karte für Bots und Drohnen: Stufen-Punkte, kurzer Text, Kosten (oder Sperre).
func _refresh_upgrade_card(btn: Button, u: Dictionary, level: int, reason: String) -> void:
	_set_pips(btn, level, int(u["max_level"]))
	_set_card(btn, tr(str(u["desc_key"])), TINT_DONE if reason == "max" else (TINT_OK if reason == "" else TINT_NO))
	match reason:
		"max":
			_set_cost(btn, "✓ " + tr("SKILL_MAXED"), COST_OK, false)
		"locked":
			_set_cost(btn, tr("HELPER_UPG_LOCKED"), COST_NO, false)
		_:
			_set_cost(btn, Fmt.int_str(int(u["cost_bolts"][level])), COST_OK if reason == "" else COST_NO, true)


func _refresh_drones() -> void:
	var w := _world
	var reason := w.can_buy_drone()
	var cost := int(w.next_drone_cost()["bolts"])
	_drone_buy_btn.text = "%s  –  %s" % [tr("DRONE_BUILD"), _build_status(reason, cost, "DRONE_LOCKED")]
	_drone_buy_btn.disabled = reason != ""
	var focused_id := -1
	var f := get_viewport().gui_get_focus_owner()
	if f != null and _drone_cards.has(f):
		focused_id = _drone_cards[f]
	for c in _drone_list.get_children():
		_drone_list.remove_child(c)
		c.queue_free()
	_drone_cards.clear()
	var i := 0
	for d: Drone in w.drones.values():
		i += 1
		var card := _make_card("%s %d" % [tr("DRONE_NAME"), i], "res://assets/sprites/robot/drone.svg")
		(_part(card, "Icon") as TextureRect).custom_minimum_size = Vector2(60, 60)
		card.custom_minimum_size = Vector2(740, 96)
		var state := tr("DRONE_STATE_FETCH")
		match d.state:
			Drone.State.RETURN:
				state = tr("DRONE_STATE_DELIVER")
			Drone.State.IDLE:
				state = tr("HELPER_STATE_IDLE")
		_set_card(card, "%s · %s %d/%d · %s %d" % [state, tr("HELPER_LOAD"), d.carry_total(), d.capacity, tr("DRONE_TRIPS"), d.trips], Color.WHITE)
		_drone_list.add_child(card)
		_drone_cards[card] = d.id
		if d.id == focused_id:
			card.grab_focus()
	for u: Dictionary in w.drone_cfg.get("upgrades", []):
		var id := str(u["id"])
		_refresh_upgrade_card(_drone_upgrade_cards[id], u, int(w.drone_upgrades.get(id, 0)), w.can_buy_drone_upgrade(id))


func _refresh_all() -> void:
	_refresh_ship()
	_refresh_skills()
	_refresh_goals()
	_refresh_helpers()
	_refresh_drones()
	if _tab == Tab.JOURNAL:
		_refresh_journal()
	match _tab:
		Tab.MAP:
			_footer.text = tr("MENU_PROGRESS_FOOTER_MAP")
		Tab.HELPERS:
			_footer.text = tr("MENU_PROGRESS_FOOTER_HELPERS")
		Tab.DRONES:
			_footer.text = tr("MENU_PROGRESS_FOOTER_DRONES")
		_:
			_footer.text = tr("MENU_PROGRESS_FOOTER")


func _refresh_skills() -> void:
	_skill_points_label.text = tr("HUD_SKILL_POINTS") % _world.progression.skill_points
	for d: Dictionary in _world.skills.defs:
		var id := str(d["id"])
		if not _skill_cards.has(id):
			continue
		var btn: Button = _skill_cards[id]
		var level := _world.skills.level_of(id)
		var maxl := int(d["max_level"])
		var desc := tr(str(d.get("desc_key", "")))
		var reason := _world.skills.can_buy(id, _world.progression.skill_points)
		var status := ""
		match reason:
			"max":
				status = tr("SKILL_MAXED")
			"requires":
				var miss := _world.skills.missing_requirement(id)
				status = tr("SKILL_NEEDS") % [tr(str(_world.skills.by_id[miss["skill"]]["name_key"])), int(miss["level"])]
			"points":
				status = tr("SKILL_NO_POINTS")
			_:
				status = tr("SKILL_BUY")
		_set_card(btn, "%d / %d · %s\n%s" % [level, maxl, desc, status],
			TINT_DONE if level >= maxl else (TINT_OK if reason == "" else TINT_NO))


func _refresh_goals() -> void:
	var lines: Array[String] = []
	var cur := _world.zones.current_chapter_zone()
	if cur != "":
		var z := _world.zones.zone_by_id(cur)
		var idx := _world.zones.chapter_index(cur) + 1
		var pct := int(round(_world.zones.cleanliness(cur, _world.nodes) * 100.0))
		var goal_pct := int(round(_world.zones.unlock_cleanliness * 100.0))
		lines.append("📍 %s %d: %s" % [tr("CH_CHAPTER"), idx, str(z.get("name", cur))])
		var next := _world.zones.next_chapter_zone()
		if next != "":
			lines.append("%s %s" % ["☑" if pct >= goal_pct else "☐", tr("CH_GOAL_CLEAN") % [goal_pct, pct]])
			lines.append("🚪 " + tr("CH_NEXT") % str(_world.zones.zone_by_id(next).get("name", next)))
		else:
			lines.append("☑ " + tr("CH_GOAL_CLEAN_LAST") % pct)
	# Aufgabenkette: zwei erledigte, die aktuelle, zwei kommende
	var q := _world.quests
	lines.append("")
	lines.append("📋 %s (%d / %d)" % [tr("GOAL_QUESTS"), q.index, q.total()])
	for i in range(maxi(q.index - 2, 0), mini(q.index + 3, q.total())):
		var qd: Dictionary = q.defs[i]
		var text := tr(str(qd.get("text_key", "")))
		if i < q.index:
			lines.append("☑ " + text)
		elif i == q.index:
			var p := q.progress(_world)
			lines.append("☐ " + text + ("  (%d/%d)" % [int(p[0]), int(p[1])] if int(p[1]) > 1 else ""))
		else:
			lines.append("○ " + text)
	if q.is_done():
		lines.append("☑ " + tr("HUD_QUESTS_DONE"))
	lines.append("")
	# Nächste Schiffsstufe
	var s := _world.ship()
	if s != null and ShipSystem.next_stage_cost(_world, s) > 0:
		var gifts: Array[String] = []
		for f in ShipSystem.next_stage_unlocks(_world, s):
			gifts.append(tr("UNLOCK_" + str(f).to_upper()))
		lines.append("🚀 %s: %s → %s" % [tr("GOAL_SHIP_STAGE") % (s.stage + 1), _bolts_text(ShipSystem.next_stage_cost(_world, s)), ", ".join(gifts)])
	# Werkzeug für härteren Müll
	var next_tier_obj := _next_locked_object()
	if not next_tier_obj.is_empty():
		lines.append("🔧 %s: %s (T%d) – %s" % [tr("GOAL_OBJECT"), tr(str(next_tier_obj["name_key"])), int(next_tier_obj["tier"]),
			tr("GOAL_NEEDS_TOOL") % [int(next_tier_obj["tier"]), tr("UPG_TOOL")]])
	if _world.collectible_total() > 0:
		lines.append("🧸 %s: %d / %d" % [tr("GOAL_COLLECTIBLES"), _world.collectibles_found.size(), _world.collectible_total()])
	if not _world.progression.is_max_level():
		lines.append("⭐ %s: %d / %d XP" % [tr("HUD_LEVEL") % (_world.progression.level + 1), _world.progression.xp, _world.progression.xp_needed()])
	# Meilensteine: nächste Schwelle je Zähler
	lines.append("")
	lines.append("🏆 " + tr("MS_HEADER"))
	for md: Dictionary in _world.milestones.defs:
		var nxt := _world.milestones.next_step(md)
		var cur_v := MilestoneState.stat(_world, str(md.get("stat", "")))
		var stars := "★".repeat(_world.milestones.steps_done(str(md["id"]))) + "☆".repeat((md.get("steps", []) as Array).size() - _world.milestones.steps_done(str(md["id"])))
		if nxt < 0:
			lines.append("%s  %s · %s" % [stars, tr(str(md["name_key"])) % Fmt.int_str(cur_v), tr("MS_ALL_DONE")])
		else:
			lines.append("%s  %s  (%s / %s)" % [stars, tr(str(md["name_key"])) % Fmt.int_str(nxt), Fmt.int_str(mini(cur_v, nxt)), Fmt.int_str(nxt)])
	if lines == _goal_lines and _goals_list.get_child_count() == lines.size():
		return
	_goal_lines = lines
	var focus_idx := _clear_keep_focus(_goals_list)
	for text in lines:
		if text == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 14)
			_goals_list.add_child(gap)
			continue
		var card := _make_card(text)
		card.custom_minimum_size = Vector2(1360, 110 if text.length() > 80 else 72)
		var title := _part(card, "Title") as Label
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_part(card, "Detail").visible = false
		_goals_list.add_child(card)
	_restore_focus(_goals_list, focus_idx)


## Leert eine Liste sofort und merkt sich, welcher Eintrag den Fokus hatte (-1: keiner).
func _clear_keep_focus(list: Container) -> int:
	var f := get_viewport().gui_get_focus_owner()
	var idx := -1
	for i in list.get_child_count():
		if list.get_child(i) == f:
			idx = i
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	return idx


func _restore_focus(list: Container, idx: int) -> void:
	if idx < 0:
		return
	for i in range(mini(idx, list.get_child_count() - 1), -1, -1):
		var c := list.get_child(i) as Control
		if c != null and c.focus_mode != Control.FOCUS_NONE:
			c.grab_focus()
			return


## Journal: Fundstücke mit Text, Unbekannte mit Kapitel-Hinweis.
func _refresh_journal() -> void:
	var sig := "%d|%s|%d" % [_world.building_count("museum"), ",".join(_world.collectibles_found.keys()), _world.zones.unlocked.size()]
	if sig == _journal_sig and _journal_list.get_child_count() > 0:
		return
	_journal_sig = sig
	var focus_idx := _clear_keep_focus(_journal_list)
	var found := _world.collectibles_found.size()
	var total := _world.collectible_total()
	var has_museum := _world.building_count("museum") > 0
	var head := _make_card("🏛 %s: %d / %d   ·   %s" % [tr("JOURNAL_HEADER"), found, total, tr("JOURNAL_MUSEUM_YES") if has_museum else tr("JOURNAL_MUSEUM_NO")])
	head.custom_minimum_size = Vector2(1360, 72)
	_part(head, "Detail").visible = false
	_journal_list.add_child(head)
	for def: Dictionary in _world.collectible_cfg.get("collectibles", []):
		var def_id := str(def.get("id", ""))
		var zone_id := str(def.get("zone", ""))
		var card: Button
		if _world.collectibles_found.has(def_id):
			card = _make_card("🧸 " + tr(str(def.get("name_key", def_id))))
			_set_card(card, tr(str(def.get("text_key", ""))), Color.WHITE)
		else:
			card = _make_card("❔ ???")
			var where := "%s %d" % [tr("CH_CHAPTER"), _world.zones.chapter_index(zone_id) + 1]
			if _world.zones.is_unlocked(zone_id):
				where = str(_world.zones.zone_by_id(zone_id).get("name", zone_id))
			_set_card(card, tr("JOURNAL_UNKNOWN") % where, TINT_NO)
		card.custom_minimum_size = Vector2(1360, 96)
		_journal_list.add_child(card)
	_restore_focus(_journal_list, focus_idx)


func _next_locked_object() -> Dictionary:
	var best: Dictionary = {}
	for n: ResourceNode in _world.nodes.values():
		var tool_tier := _world.player.hammer_tier if n.uses_hammer() else _world.player.suction_tier
		if n.tier <= tool_tier:
			continue
		if best.is_empty() or n.tier < int(best["tier"]):
			var d: Dictionary = ResourceNode.defs.get(n.kind, {})
			best = {"tier": n.tier, "tool": n.tool, "name_key": d.get("name_key", n.kind)}
	return best


# --- Tabs -----------------------------------------------------------------

func _show_tab() -> void:
	_ship_tab.visible = _tab == Tab.SHIP
	_skills_tab.visible = _tab == Tab.SKILLS
	_goals_tab.visible = _tab == Tab.GOALS
	_map_tab.visible = _tab == Tab.MAP
	_helpers_tab.visible = _tab == Tab.HELPERS
	_drones_tab.visible = _tab == Tab.DRONES
	_journal_tab.visible = _tab == Tab.JOURNAL
	_world.flags["tab_seen_%d" % int(_tab)] = true
	for i in _tab_labels.size():
		var box := _tab_labels[i].get_parent() as Control
		box.visible = _tab_enabled(i)
		box.get_node("NewDot").visible = _tab_enabled(i) and not _tab_seen(i)
		_tab_labels[i].add_theme_color_override("font_color", Color(0.95, 0.55, 0.16) if i == _tab else Color(0.165, 0.165, 0.2))
	if _tab == Tab.MAP:
		_map_view.refresh()
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
		return
	var first: Control = null
	match _tab:
		Tab.SHIP:
			first = _ship_cards.get("repair")
		Tab.SKILLS:
			var col: Node = _skill_columns.get_child(0) if _skill_columns.get_child_count() > 0 else null
			first = col.get_child(1) if col and col.get_child_count() > 1 else null
		Tab.GOALS:
			first = _goals_list.get_child(0) if _goals_list.get_child_count() > 0 else null
		Tab.HELPERS:
			first = _buy_btn
		Tab.DRONES:
			first = _drone_buy_btn
		Tab.JOURNAL:
			first = _journal_list.get_child(0) if _journal_list.get_child_count() > 0 else null
	if first:
		first.grab_focus()
