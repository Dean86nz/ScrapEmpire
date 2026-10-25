extends HBoxContainer
## XP-Leiste unten links: Level, Balken, Skillpunkte. Pulst kurz beim Levelaufstieg.

@onready var _level: Label = $Level
@onready var _bar: ProgressBar = $Bar
@onready var _points: Label = $Points

var _tween: Tween


func bind(progression: Progression) -> void:
	progression.xp_changed.connect(_on_xp_changed)
	progression.level_up.connect(_on_level_up)
	_on_xp_changed(progression.xp, progression.xp_needed(), progression.level)
	_set_points(progression.skill_points)


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	_level.text = tr("HUD_LEVEL") % level
	_bar.max_value = maxi(needed, 1)
	_bar.value = xp
	_bar.tooltip_text = "%d / %d" % [xp, needed]


func _on_level_up(_level: int, skill_points: int) -> void:
	_set_points(skill_points)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_points(points: int) -> void:
	_points.visible = points > 0
	_points.text = tr("HUD_SKILL_POINTS") % points
