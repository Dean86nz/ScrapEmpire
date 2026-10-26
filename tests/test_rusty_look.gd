extends TestCase
## Rustys Anbauteile (MS28): drei sichtbare Stufen je Skill.


func test_tiers_follow_skill_levels() -> void:
	var look := RustyLook.new()
	look.set_levels({"drive": 0, "bags": 1, "suck": 4, "tool": 3}, {"drive": 8, "bags": 8, "suck": 8, "tool": 3})
	assert_eq(look.tier("drive"), 0, "nicht gelernt: nichts dran")
	assert_eq(look.tier("bags"), 1, "angefangen")
	assert_eq(look.tier("suck"), 2, "ab der Hälfte")
	assert_eq(look.tier("tool"), 3, "voll ausgebaut")
	assert_eq(look.total(), 8)
	look.free()
