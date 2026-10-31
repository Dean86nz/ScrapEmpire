extends CanvasLayer
## Schiff- und Fortschritts-Menü (Select, oder X am Schiff). Tabs: Schiff, Kapitel, Skills, Karte,
## Bots, Drohnen, Journal. LB/RB wechseln den Tab, D-Pad bewegt den Fokus, A kauft, B schließt.

enum Tab { SHIP, GOALS, SKILLS, MAP, HELPERS, DRONES, JOURNAL }
const TAB_COUNT := 7

const CARD_SCENE_MIN := Vector2(440, 150)
const SHIP_CARD_MIN := Vector2(670, 160)
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
var _fuse_btn := Button.new()
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
var _goals_sig := ""                  # zuletzt gezeigter Ziele-Stand (nur bei Änderung neu bauen, sonst geht der Fokus verloren)
var _goals_show_done := false
var _journal_sig := ""


func _ready() -> void:
	visible = false
	# Lange Listen (20+ Bots) scrollen mit dem Gamepad-Fokus in beide Richtungen (MS54)
	for list: Control in [_helper_list, _upgrade_list, _drone_list, _drone_upgrade_list]:
		_wrap_in_scroll(list)
	KenneySkin.apply($Center/Panel)  # einheitlicher Menü-Stil (MS54)


func _wrap_in_scroll(list: Control) -> void:
	var parent := list.get_parent()
	var idx := list.get_index()
	var sc := ScrollContainer.new()
	sc.follow_focus = true
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = list.size_flags_horizontal
	sc.custom_minimum_size = Vector2(0, 200)
	parent.add_child(sc)
	parent.move_child(sc, idx)
	# Fokus springt aus der Liste nach oben (z. B. auf „Bot bauen“): Liste ganz nach oben
	get_viewport().gui_focus_changed.connect(func(c: Control) -> void:
		if c != null and c.get_parent() == parent and c.get_index() < sc.get_index():
			sc.scroll_vertical = 0)
	list.reparent(sc, false)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL


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
	_ship_grid.columns = 2   # seit MS25 nur noch vier Karten: Reparatur, Ertrag, Bot, Drohne
	_build_ship_cards()
	_build_skill_cards()
	_map_view.zone_selected.connect(_on_zone_selected)
	_buy_btn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_helper"}))
	# Fusion (MS57): 5 Bots → Super-Bot, 5 Super-Bots → Mega-Bot
	_fuse_btn.custom_minimum_size = _buy_btn.custom_minimum_size
	_buy_btn.get_parent().add_child(_fuse_btn)
	_buy_btn.get_parent().move_child(_fuse_btn, _buy_btn.get_index() + 1)
	_fuse_btn.pressed.connect(func() -> void:
		var p := 25 if HelperSystem.can_fuse(SimClock.world, 25) else (5 if HelperSystem.can_fuse(SimClock.world, 5) else 1)  # höchste Fusion zuerst
		SimClock.world.queue_command({"type": "fuse_helpers", "power": p}))
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
			return not _world.collectibles_found.is_empty()
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
	var panel: Control = $Center/Panel
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	Sfx.play("open")
	InputRouter.context = InputRouter.Context.MENU
	_refresh_all()
	_show_tab()


## Kauf-Feedback im Menü (MS62): fokussierte Karte pulsiert und leuchtet kurz, „+1“ steigt auf.
func purchase_feedback() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not is_ancestor_of(f):
		return
	f.pivot_offset = f.size * 0.5
	var tw := create_tween()
	tw.tween_property(f, "scale", Vector2(1.05, 1.05), 0.07)
	tw.tween_property(f, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	var glow := create_tween()
	glow.tween_property(f, "modulate", Color(1.25, 1.2, 0.9), 0.07)
	glow.tween_property(f, "modulate", Color.WHITE, 0.3)
	var l := Label.new()
	l.text = "+1"
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(0.25, 0.7, 0.3))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	l.global_position = f.global_position + Vector2(f.size.x - 70, 4)
	var up := create_tween()
	up.tween_property(l, "global_position:y", l.global_position.y - 40, 0.6)
	up.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	up.tween_callback(l.queue_free)


func close() -> void:
	_map_view.reset_zoom()
	if visible:
		Sfx.play("close")
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
		Sfx.play("tab")
		_next_tab(1)
		_show_tab()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_prev"):
		Sfx.play("tab")
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
	KenneySkin.card(btn)
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
	_lift_on_focus(btn)
	return btn


## Tabwechsel: Inhalt blendet weich ein und wächst ein kleines Stück.
func _pop_content() -> void:
	var content: Control = $Center/Panel/VBox/Content
	content.pivot_offset = content.size * 0.5
	content.scale = Vector2(0.97, 0.97)
	content.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(content, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "modulate:a", 1.0, 0.14)


## Fokus hebt Karten leicht an.
func _lift_on_focus(btn: Control) -> void:
	btn.focus_entered.connect(func() -> void:
		btn.pivot_offset = btn.size * 0.5
		btn.create_tween().tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1))
	btn.focus_exited.connect(func() -> void: btn.create_tween().tween_property(btn, "scale", Vector2.ONE, 0.1))


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
	if max_level > 10:
		# Tiefe Upgrades (MS57): Stufe als Zahl mit kurzem Balken statt 50 Punkten
		var filled := int(round(10.0 * level / max_level))
		p.text = "%s  %d/%d" % ["▮".repeat(filled) + "▯".repeat(10 - filled), level, max_level]
	else:
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
	var auto := _make_card(tr("COURIER_AUTO"), "res://assets/sprites/robot/courier.svg")
	auto.custom_minimum_size = SHIP_CARD_MIN
	auto.pressed.connect(func() -> void:
		_world.flags["courier_auto"] = not bool(_world.flags.get("courier_auto", true))
		_refresh_ship())
	_ship_cards["courier_auto"] = auto
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
	_ship_grid.add_child(auto)


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
			var btn := _make_card(tr(str(d["name_key"])), str(d.get("icon", "")))
			btn.custom_minimum_size = Vector2(350, 170)
			btn.pressed.connect(func() -> void: SimClock.world.queue_command({"type": "buy_skill", "id": id}))
			col.add_child(btn)
			_skill_cards[id] = btn
		_skill_columns.add_child(col)


# --- Aktualisieren ----------------------------------------------------------

const TINT_OK := Color.WHITE
const TINT_NO := Color(0.85, 0.85, 0.85)
const TINT_DONE := Color(0.75, 1.0, 0.8)


func _bolts_text(n: int) -> String:
	return "%s %s" % [Fmt.short(n), tr("HUD_BOLTS")]


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
			if reason == "boss":
				_set_cost(repair, tr("SHIP_NEEDS_BOSS"), COST_NO, false)
			elif reason == "planet":
				_set_cost(repair, tr("SHIP_NEEDS_PLANET") % int(round(float(ShipSystem.stage_def(w, s.stage + 1).get("requires_planet", 0.0)) * 100.0)), COST_NO, false)
			else:
				_set_cost(repair, Fmt.short(ShipSystem.next_stage_cost(w, s)), COST_OK if reason == "" else COST_NO, true)
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
		elif reason == "locked":
			_set_cost(btn, tr("UPG_LOCKED_STAGE3"), COST_NO, false)
		else:
			_set_cost(btn, Fmt.short(ShipSystem.upgrade_cost(w, id)), COST_OK if reason == "" else COST_NO, true)
	if _ship_cards.has("courier_auto"):
		var auto_btn: Button = _ship_cards["courier_auto"]
		auto_btn.visible = w.unlocked_features.has("courier")
		var on := bool(w.flags.get("courier_auto", true))
		_set_card(auto_btn, tr("COURIER_AUTO_DESC"), TINT_OK)
		_set_cost(auto_btn, tr("COURIER_AUTO_ON") if on else tr("COURIER_AUTO_OFF"), COST_OK if on else COST_NO, false)
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
			_set_cost(btn, Fmt.short(cost), COST_OK if reason == "" else COST_NO, true)


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
	var cost_txt := _bolts_text(Costs.upgrade(u, level)) if level < maxl else ""
	var st := tr("HELPER_UPG_BUY")
	match reason:
		"max":
			st = tr("SKILL_MAXED")
		"locked":
			st = tr("HELPER_UPG_LOCKED")
		"bolts":
			st = _missing_text(Costs.upgrade(u, level))
	return "%d / %d · %s\n%s · %s" % [level, maxl, tr(str(u["desc_key"])), cost_txt, st]


func _refresh_helpers() -> void:
	var w := _world
	var reason := w.can_buy_helper()
	var cost := int(w.next_helper_cost()["bolts"])
	_buy_btn.text = "%s  –  %s" % [tr("BOT_BUILD"), _build_status(reason, cost, "BOT_LOCKED")]
	_buy_btn.disabled = reason != ""
	var fuse1 := HelperSystem.can_fuse(w, 1)
	var fuse5 := HelperSystem.can_fuse(w, 5)
	var fuse25 := HelperSystem.can_fuse(w, 25)
	_fuse_btn.visible = w.unlocked_features.has("helpers")
	_fuse_btn.disabled = not (fuse1 or fuse5 or fuse25)
	_fuse_btn.text = tr("BOT_FUSE_GIGA") if fuse25 else (tr("BOT_FUSE_MEGA") if fuse5 else tr("BOT_FUSE"))
	_fuse_btn.text += "  ·  " + tr("BOT_ARMY") % HelperSystem.army(w)
	var focused_bot := -1
	var fb := get_viewport().gui_get_focus_owner()
	if fb != null and _helper_cards.has(fb):
		focused_bot = int(fb.get_meta("helper_id", -1))
	# Neuaufbau der Karten setzt sonst die Liste nach oben, obwohl der Fokus unten bleibt
	var scroll := _helper_list.get_parent() as ScrollContainer
	var keep_scroll := scroll.scroll_vertical if scroll != null else 0
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
		if h.bored != "" and h.inventory.total() == 0:
			state = tr("HELPER_STATE_BORED_HARD") if h.bored == "too_hard" else tr("HELPER_STATE_BORED")
		var zone_name: String = str(w.zones.zone_by_id(h.zone_id if h.zone_id != "" else w.zones.zone_id_at(h.zone_tile)).get("name", "?"))
		_set_card(card, "%s · %s · %s %d/%d" % [state, zone_name, tr("HELPER_LOAD"), h.inventory.total(), h.inventory.slot_count * h.inventory.stack_size], Color.WHITE)
		_helper_list.add_child(card)
		_helper_cards.append(card)
		if h.id == focused_bot:
			card.grab_focus()
	if scroll != null:
		scroll.set_deferred("scroll_vertical", keep_scroll)
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
			_set_cost(btn, Fmt.short(Costs.upgrade(u, level)), COST_OK if reason == "" else COST_NO, true)


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
			_map_view.queue_redraw()
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
		var reason := _world.skills.can_buy(id, _world.progression.skill_points)
		_set_pips(btn, level, maxl)
		_set_card(btn, tr(str(d.get("desc_key", ""))), TINT_DONE if level >= maxl else (TINT_OK if reason == "" else TINT_NO))
		var pts := _world.skills.cost(id)
		match reason:
			"max":
				_set_cost(btn, "✓ " + tr("SKILL_MAXED"), COST_OK, false)
			"requires":
				var miss := _world.skills.missing_requirement(id)
				_set_cost(btn, tr("SKILL_NEEDS") % [tr(str(_world.skills.by_id[miss["skill"]]["name_key"])), int(miss["level"])], COST_NO, false)
			_:
				_set_cost(btn, "★ " + (tr("SKILL_COST_POINTS") % pts if pts > 1 else tr("SKILL_COST_ONE")), COST_OK if reason == "" else COST_NO, false)


func _refresh_goals() -> void:
	var w := _world
	var q := w.quests
	var sig := "%d|%s|%d|%d|%d|%s|%d" % [q.index, str(q.progress(w)), w.bolts, int(round(w.zones.planet_health(w.nodes) * 100.0)),
		w.ship().stage if w.ship() != null else 0, str(w.milestones.done), int(_goals_show_done)]
	if sig == _goals_sig and _goals_list.get_child_count() > 0:
		return
	_goals_sig = sig
	var focus_idx := _clear_keep_focus(_goals_list)
	# 1) Aktuelle Aufgabe groß
	if q.is_done():
		_goals_list.add_child(_hero_card("res://assets/sprites/ui/trophy.svg", tr("GOAL_NOW"), tr("HUD_QUESTS_DONE"), 1.0, ""))
	else:
		var qd: Dictionary = q.current()
		var p := q.progress(w)
		var frac := float(p[0]) / float(maxi(int(p[1]), 1))
		var count := "%s / %s" % [Fmt.short(int(p[0])), Fmt.short(int(p[1]))] if int(p[1]) > 1 else ""
		_goals_list.add_child(_hero_card(_quest_icon(qd), tr("GOAL_NOW"), tr(str(qd.get("text_key", ""))), frac, count))
	# 2) Als Nächstes: höchstens zwei
	var next_row := HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 14)
	for i in range(q.index + 1, mini(q.index + 3, q.total())):
		var nd: Dictionary = q.defs[i]
		var c := _mini_card(_quest_icon(nd), tr("GOAL_NEXT"), tr(str(nd.get("text_key", ""))), -1.0)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_row.add_child(c)
	if next_row.get_child_count() > 0:
		_goals_list.add_child(next_row)
	# 3) Erledigt: eingeklappt, A klappt auf
	if q.index > 0:
		var done := _mini_card("res://assets/sprites/ui/tab_goals.svg", tr("GOAL_DONE_N") % q.index, tr("GOAL_DONE_HIDE") if _goals_show_done else tr("GOAL_DONE_SHOW"), -1.0)
		done.pressed.connect(func() -> void:
			_goals_show_done = not _goals_show_done
			_refresh_goals())
		_goals_list.add_child(done)
		if _goals_show_done:
			for i in q.index:
				var dd: Dictionary = q.defs[i]
				var l := Label.new()
				l.text = "   ✓  " + tr(str(dd.get("text_key", "")))
				l.add_theme_color_override("font_color", Color(0.25, 0.5, 0.25))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_goals_list.add_child(l)
	# 4) Kapitel und Schiff nebeneinander
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var cur := w.zones.current_chapter_zone()
	if cur != "":
		var z := w.zones.zone_by_id(cur)
		var pct := w.zones.cleanliness(cur, w.nodes)
		var goal := w.zones.unlock_cleanliness
		var sub := tr("CH_GOAL_CLEAN") % [int(round(goal * 100.0)), int(round(pct * 100.0))] if w.zones.next_chapter_zone() != "" else tr("CH_GOAL_CLEAN_LAST") % int(round(pct * 100.0))
		var cc := _mini_card("res://assets/sprites/ui/tab_map.svg", "%s %d · %s" % [tr("CH_CHAPTER"), w.zones.chapter_index(cur) + 1, str(z.get("name", cur))], sub, clampf(pct / maxf(goal, 0.01), 0.0, 1.0))
		cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cc)
	var s := w.ship()
	if s != null and ShipSystem.next_stage_cost(w, s) > 0:
		var cost := ShipSystem.next_stage_cost(w, s)
		var gifts: Array[String] = []
		for f in ShipSystem.next_stage_unlocks(w, s):
			gifts.append(tr("GIFT_" + str(f).to_upper()))
		var sc := _mini_card(str(ShipSystem.stage_def(w, s.stage + 1).get("sprite", "")), tr("GOAL_SHIP_STAGE") % (s.stage + 1),
			"%s / %s Bolts · %s" % [Fmt.short(mini(w.bolts, cost)), Fmt.short(cost), ", ".join(gifts)], clampf(float(w.bolts) / float(cost), 0.0, 1.0))
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sc)
	if row.get_child_count() > 0:
		_goals_list.add_child(row)
	# 5) Tipp zum Werkzeug, falls härterer Müll wartet
	var obj := _next_locked_object()
	if not obj.is_empty():
		_goals_list.add_child(_mini_card("res://assets/sprites/ui/upg_tool.svg", tr("GOAL_OBJECT") + ": " + tr(str(obj["name_key"])),
			tr("GOAL_NEEDS_TOOL") % [int(obj["tier"]), tr("SKILL_TOOL")], -1.0))
	# 6) Meilensteine als kleine Kacheln, drei je Reihe
	var head := Label.new()
	head.text = tr("MS_HEADER")
	head.add_theme_font_size_override("font_size", 28)
	head.add_theme_color_override("font_color", Color(0.95, 0.5, 0.12))
	_goals_list.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for md: Dictionary in w.milestones.defs:
		var nxt := w.milestones.next_step(md)
		var cur_v := MilestoneState.stat(w, str(md.get("stat", "")))
		var done_n := w.milestones.steps_done(str(md["id"]))
		var stars := "★".repeat(done_n) + "☆".repeat((md.get("steps", []) as Array).size() - done_n)
		var title := tr(str(md["name_key"])) % Fmt.short(nxt if nxt >= 0 else cur_v)
		var mc := _mini_card(str(md.get("icon", "")), title, stars + ("  " + tr("MS_ALL_DONE") if nxt < 0 else "  %s / %s" % [Fmt.short(mini(cur_v, nxt)), Fmt.short(nxt)]),
			1.0 if nxt < 0 else clampf(float(cur_v) / float(maxi(nxt, 1)), 0.0, 1.0))
		mc.custom_minimum_size = Vector2(673, 112)
		grid.add_child(mc)
	_goals_list.add_child(grid)
	_restore_focus(_goals_list, focus_idx)


## Bild zur Aufgabe nach ihrem Typ.
func _quest_icon(qd: Dictionary) -> String:
	match str(qd.get("type", "")):
		"collect":
			return "res://assets/sprites/items/%s.svg" % str(qd.get("item", "scrap"))
		"ship_delivered", "deliveries":
			return "res://assets/sprites/ui/ms_crate.svg"
		"upgrades_bought", "upgrade_level":
			return "res://assets/sprites/ui/upg_%s.svg" % str(qd.get("upgrade", "yield"))
		"skills_bought", "level":
			return "res://assets/sprites/ui/tab_skills.svg"
		"skill_level":
			return str(_world.skills.by_id.get(str(qd.get("skill", "")), {}).get("icon", "res://assets/sprites/ui/tab_skills.svg"))
		"wrecks", "bosses", "flag":
			return "res://assets/sprites/ui/ms_hammer.svg"
		"bolts_earned":
			return "res://assets/sprites/ui/bolt.svg"
		"zone_gate", "planet":
			return "res://assets/sprites/ui/tab_map.svg"
		"ship_stage":
			return "res://assets/sprites/buildings/ship_%d.svg" % clampi(int(qd.get("amount", 2)), 1, 5)
		"helpers":
			return "res://assets/sprites/robot/rusty.svg"
		"drones":
			return "res://assets/sprites/robot/drone.svg"
		"collectibles":
			return "res://assets/sprites/ui/tab_journal.svg"
		"cleaned":
			return "res://assets/sprites/ui/ms_broom.svg"
	return "res://assets/sprites/robot/rusty.svg"


func _bar(frac: float, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = frac
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.165, 0.165, 0.2, 0.15)
	bg.set_corner_radius_all(height / 2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.8, 0.35) if frac < 1.0 else Color(0.95, 0.65, 0.2)
	fill.set_corner_radius_all(height / 2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Große Karte für die aktuelle Aufgabe: Bild, Überschrift, Text, Balken.
func _hero_card(icon: String, kicker: String, text: String, frac: float, count: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(1360, 210)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -26
	row.offset_top = 16
	row.offset_bottom = -16
	row.add_theme_constant_override("separation", 26)
	btn.add_child(row)
	var pic := TextureRect.new()
	pic.texture = load(icon)
	pic.custom_minimum_size = Vector2(170, 170)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	var k := Label.new()
	k.text = kicker
	k.add_theme_font_size_override("font_size", 24)
	k.add_theme_color_override("font_color", Color(0.95, 0.5, 0.12))
	col.add_child(k)
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color(0.165, 0.165, 0.2))
	col.add_child(t)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 14)
	var bar := _bar(frac, 30)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(bar)
	if count != "":
		var c := Label.new()
		c.text = count
		c.add_theme_font_size_override("font_size", 26)
		c.add_theme_color_override("font_color", Color(0.165, 0.165, 0.2))
		brow.add_child(c)
	col.add_child(brow)
	_lift_on_focus(btn)
	return btn


## Kleine Karte: Bild, Titel, Untertitel, optional Balken (frac < 0: ohne).
func _mini_card(icon: String, title: String, sub: String, frac: float) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 112)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.offset_top = 10
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 14)
	btn.add_child(row)
	if icon != "":
		var pic := TextureRect.new()
		pic.texture = load(icon)
		pic.custom_minimum_size = Vector2(72, 72)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.165, 0.165, 0.2))
	t.clip_text = true
	col.add_child(t)
	var s2 := Label.new()
	s2.text = sub
	s2.add_theme_font_size_override("font_size", 22)
	s2.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	s2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(s2)
	if frac >= 0.0:
		col.add_child(_bar(frac, 16))
	_lift_on_focus(btn)
	return btn


## Leert eine Liste sofort und merkt sich, welcher Eintrag den Fokus hatte (-1: keiner).
func _clear_keep_focus(list: Container) -> int:
	var f := get_viewport().gui_get_focus_owner()
	var idx := -1
	for i in list.get_child_count():
		var c := list.get_child(i)
		if f != null and (c == f or c.is_ancestor_of(f)):
			idx = i
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	return idx


func _restore_focus(list: Container, idx: int) -> void:
	if idx < 0:
		return
	for i in range(mini(idx, list.get_child_count() - 1), -1, -1):
		var c := _first_focusable(list.get_child(i))
		if c != null:
			c.grab_focus()
			return


func _first_focusable(n: Node) -> Control:
	if n is Control and (n as Control).focus_mode != Control.FOCUS_NONE and (n as Control).visible:
		return n as Control
	for ch in n.get_children():
		var f := _first_focusable(ch)
		if f != null:
			return f
	return null


## Journal: Fundstücke mit Text, Unbekannte mit Kapitel-Hinweis.
func _refresh_journal() -> void:
	var sig := "%s|%d" % [",".join(_world.collectibles_found.keys()), _world.zones.unlocked.size()]
	if sig == _journal_sig and _journal_list.get_child_count() > 0:
		return
	_journal_sig = sig
	var focus_idx := _clear_keep_focus(_journal_list)
	var found := _world.collectibles_found.size()
	var total := _world.collectible_total()
	var head := _make_card("📖 %s: %d / %d" % [tr("JOURNAL_HEADER"), found, total])
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
		if n.tier <= tool_tier or n.boss:
			continue  # Bosse brauchen Bots statt Werkzeugstufe (MS66)
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
	_pop_content()
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
	if _tab == Tab.GOALS:
		(_goals_tab as ScrollContainer).set_deferred("scroll_vertical", 0)
