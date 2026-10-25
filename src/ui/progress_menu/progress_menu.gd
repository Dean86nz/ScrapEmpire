extends CanvasLayer
## Fortschritts-Menü (Select / T) mit drei Tabs: Techbaum, Skilltree, Nächste Ziele.
## LB/RB wechseln den Tab, D-Pad bewegt den Fokus, A forscht / kauft, B schließt.

enum Tab { TECH, SKILLS, GOALS, MAP }
const TAB_COUNT := 4

const CARD_SCENE_MIN := Vector2(362, 150)
const REFRESH_SECONDS := 0.5

@onready var _tab_labels: Array[Label] = [$Center/Panel/VBox/Tabs/TabTech, $Center/Panel/VBox/Tabs/TabSkills, $Center/Panel/VBox/Tabs/TabGoals, $Center/Panel/VBox/Tabs/TabMap]
@onready var _map_tab: Control = $Center/Panel/VBox/Content/MapTab
@onready var _map_view: MapView = $Center/Panel/VBox/Content/MapTab/MapView
@onready var _map_info: Label = $Center/Panel/VBox/Content/MapTab/Info
@onready var _tech_grid: GridContainer = $Center/Panel/VBox/Content/TechTab/Grid
@onready var _skill_columns: HBoxContainer = $Center/Panel/VBox/Content/SkillsTab/Columns
@onready var _skill_points_label: Label = $Center/Panel/VBox/Content/SkillsTab/Points
@onready var _goals_list: VBoxContainer = $Center/Panel/VBox/Content/GoalsTab/List
@onready var _tech_tab: Control = $Center/Panel/VBox/Content/TechTab
@onready var _skills_tab: Control = $Center/Panel/VBox/Content/SkillsTab
@onready var _goals_tab: Control = $Center/Panel/VBox/Content/GoalsTab
@onready var _footer: Label = $Center/Panel/VBox/Footer

var _world: SimWorld
var _tab: Tab = Tab.TECH
var _tech_cards: Dictionary = {}   # id → Button
var _skill_cards: Dictionary = {}  # id → Button
var _refresh_timer := 0.0


func _ready() -> void:
	visible = false


func bind(world: SimWorld) -> void:
	_world = world
	_build_tech_cards()
	_build_skill_cards()
	_map_view.zone_selected.connect(_on_zone_selected)


func bind_player(player: Node2D) -> void:
	_map_view.bind(_world, player)


func _on_zone_selected(info: Dictionary) -> void:
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


func open(tab: Tab = Tab.TECH) -> void:
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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("tech_tree"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_next"):
		_tab = (_tab + 1) % TAB_COUNT as Tab
		_show_tab()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_prev"):
		_tab = (_tab + TAB_COUNT - 1) % TAB_COUNT as Tab
		_show_tab()
		get_viewport().set_input_as_handled()
	elif _tab == Tab.MAP and _map_view.handle_input(event):
		get_viewport().set_input_as_handled()


# --- Aufbau ---------------------------------------------------------------

func _make_card(title: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SCENE_MIN
	btn.text = ""
	btn.clip_contents = true
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_top = 10
	box.offset_right = -20
	box.offset_bottom = -10
	var name_label := Label.new()
	name_label.name = "Title"
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(0.165, 0.165, 0.2))
	var detail := Label.new()
	detail.name = "Detail"
	detail.add_theme_font_size_override("font_size", 20)
	detail.add_theme_color_override("font_color", Color(0.3, 0.3, 0.36))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	box.add_child(detail)
	btn.add_child(box)
	return btn


func _set_card(btn: Button, detail: String, tint: Color) -> void:
	(btn.get_node("Box/Detail") as Label).text = detail
	btn.self_modulate = tint


func _build_tech_cards() -> void:
	for c in _tech_grid.get_children():
		c.queue_free()
	_tech_cards.clear()
	for d: Dictionary in _world.tech.defs:
		var id := str(d["id"])
		var btn := _make_card(tr(str(d["name_key"])))
		btn.pressed.connect(func() -> void: _on_tech_pressed(id))
		_tech_grid.add_child(btn)
		_tech_cards[id] = btn


func _build_skill_cards() -> void:
	for c in _skill_columns.get_children():
		c.queue_free()
	_skill_cards.clear()
	for br: Dictionary in _world.skills.branches:
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
		for d: Dictionary in _world.skills.skills_in_branch(str(br["id"])):
			var id := str(d["id"])
			var btn := _make_card(tr(str(d["name_key"])))
			btn.custom_minimum_size = Vector2(350, 150)
			btn.pressed.connect(func() -> void: _on_skill_pressed(id))
			col.add_child(btn)
			_skill_cards[id] = btn
		_skill_columns.add_child(col)


# --- Aktualisieren ----------------------------------------------------------

func _refresh_all() -> void:
	_refresh_tech()
	_refresh_skills()
	_refresh_goals()
	_footer.text = tr("MENU_PROGRESS_FOOTER_MAP") if _tab == Tab.MAP else tr("MENU_PROGRESS_FOOTER")


func _cost_text(d: Dictionary) -> String:
	var parts: Array[String] = ["%d %s" % [int(d.get("cost_bolts", 0)), tr("HUD_BOLTS")]]
	for item in d.get("cost_items", {}):
		parts.append("%d %s" % [int(d["cost_items"][item]), DataRegistry.item_name(str(item))])
	return ", ".join(parts)


func _refresh_tech() -> void:
	for d: Dictionary in _world.tech.defs:
		var id := str(d["id"])
		var btn: Button = _tech_cards[id]
		var desc := tr(str(d.get("desc_key", "")))
		if _world.tech.is_unlocked(id):
			_set_card(btn, "✔ %s" % tr("TECH_DONE"), Color(0.75, 1.0, 0.8))
		elif _world.tech.current_id == id:
			var secs := int(ceil(_world.tech.remaining_ticks / 20.0))
			_set_card(btn, "%s … %d s" % [tr("TECH_RESEARCHING"), secs], Color(1.0, 0.85, 0.6))
		else:
			var reason := _world.tech.can_start(id, _world.bolts, _world.player.inventory)
			var status := ""
			match reason:
				"requires":
					var req: Array = []
					for r in d.get("requires", []):
						req.append(tr(str(_world.tech.by_id[str(r)]["name_key"])))
					status = tr("TECH_NEEDS") % ", ".join(req)
				"bolts":
					status = tr("TECH_MISSING_BOLTS") % (int(d.get("cost_bolts", 0)) - _world.bolts)
				"items":
					status = tr("TECH_MISSING_ITEMS")
				"busy":
					status = tr("TECH_BUSY")
				_:
					status = tr("TECH_READY")
			_set_card(btn, "%s\n%s · %d s · %s" % [desc, _cost_text(d), int(d.get("time_s", 0)), status],
				Color.WHITE if reason == "" else Color(0.85, 0.85, 0.85))


func _refresh_skills() -> void:
	_skill_points_label.text = tr("HUD_SKILL_POINTS") % _world.progression.skill_points
	for d: Dictionary in _world.skills.defs:
		var id := str(d["id"])
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
			Color(0.75, 1.0, 0.8) if level >= maxl else (Color.WHITE if reason == "" else Color(0.85, 0.85, 0.85)))


func _refresh_goals() -> void:
	for c in _goals_list.get_children():
		c.queue_free()
	var lines: Array[String] = []
	# Forschung
	var avail := _world.tech.available()
	if _world.tech.is_researching():
		var d: Dictionary = _world.tech.by_id[_world.tech.current_id]
		lines.append("🔬 %s: %s (%d s)" % [tr("GOAL_RESEARCHING"), tr(str(d["name_key"])), int(ceil(_world.tech.remaining_ticks / 20.0))])
	for id in avail.slice(0, 3):
		var d: Dictionary = _world.tech.by_id[id]
		var missing := int(d.get("cost_bolts", 0)) - _world.bolts
		var chrome_need := int(d.get("cost_items", {}).get("chrome", 0)) - _world.player.inventory.count_of("chrome")
		var what := tr("GOAL_READY") if missing <= 0 and chrome_need <= 0 else ""
		if missing > 0:
			what = tr("GOAL_MISSING_BOLTS") % missing
		if chrome_need > 0:
			what += (" · " if what != "" else "") + tr("GOAL_MISSING_CHROME") % chrome_need
		lines.append("🔬 %s: %s – %s" % [tr("GOAL_TECH"), tr(str(d["name_key"])), what])
	# Werkzeuge und Objekte
	var next_tier_obj := _next_locked_object()
	if not next_tier_obj.is_empty():
		var tool_key := "SKILL_SMASH" if str(next_tier_obj["tool"]) == "hammer" else "SKILL_SUCTION_POWER"
		lines.append("🔧 %s: %s (T%d) – %s" % [tr("GOAL_OBJECT"), tr(str(next_tier_obj["name_key"])), int(next_tier_obj["tier"]),
			tr("GOAL_NEEDS_TOOL") % [int(next_tier_obj["tier"]), tr(tool_key)]])
	# Helfer
	if not _world.unlocked_features.has("helpers"):
		var hw: Dictionary = _world.tech.by_id["helper_workshop"]
		lines.append("🤖 %s: %s – %s" % [tr("GOAL_HELPERS"), tr(str(hw["name_key"])), _cost_text(hw)])
	# Level
	if not _world.progression.is_max_level():
		lines.append("⭐ %s: %d / %d XP" % [tr("HUD_LEVEL") % (_world.progression.level + 1), _world.progression.xp, _world.progression.xp_needed()])
	for text in lines:
		var card := _make_card(text)
		card.custom_minimum_size = Vector2(1360, 72)
		(card.get_node("Box/Detail") as Label).visible = false
		_goals_list.add_child(card)


## Nächstes Objekt in der Welt, dessen Stufe über dem passenden Werkzeug liegt.
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


# --- Tabs und Aktionen -----------------------------------------------------

func _show_tab() -> void:
	_tech_tab.visible = _tab == Tab.TECH
	_skills_tab.visible = _tab == Tab.SKILLS
	_goals_tab.visible = _tab == Tab.GOALS
	_map_tab.visible = _tab == Tab.MAP
	for i in _tab_labels.size():
		_tab_labels[i].add_theme_color_override("font_color", Color(0.95, 0.55, 0.16) if i == _tab else Color(0.165, 0.165, 0.2))
	if _tab == Tab.MAP:
		_map_view.refresh()
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
		return
	var first: Control = null
	match _tab:
		Tab.TECH:
			first = _tech_grid.get_child(0) if _tech_grid.get_child_count() > 0 else null
		Tab.SKILLS:
			var col: Node = _skill_columns.get_child(0) if _skill_columns.get_child_count() > 0 else null
			first = col.get_child(1) if col and col.get_child_count() > 1 else null
		Tab.GOALS:
			first = _goals_list.get_child(0) if _goals_list.get_child_count() > 0 else null
	if first:
		first.grab_focus()


func _on_tech_pressed(id: String) -> void:
	SimClock.world.queue_command({"type": "research", "id": id})


func _on_skill_pressed(id: String) -> void:
	SimClock.world.queue_command({"type": "buy_skill", "id": id})
