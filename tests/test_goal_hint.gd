extends TestCase
## Nächstes Ziel im HUD (MS27).


func test_shows_cheapest_ship_goal_with_missing_bolts() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	w.bolts = 20
	var g := GoalHint.next_goal(w)
	assert_false(g["ready"])
	assert_true(str(g["text"]).contains("40"), "Ertrag 1 kostet 60, es fehlen 40: " + str(g["text"]))


func test_affordable_goal_first_then_skill_point() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	w.bolts = 70
	w.progression.skill_points = 1
	assert_true(GoalHint.next_goal(w)["ready"])
	assert_true(str(GoalHint.next_goal(w)["icon"]).ends_with("upg_yield.svg"), "leistbares Schiff-Ziel zuerst")
	w.bolts = 0
	assert_true(str(GoalHint.next_goal(w)["icon"]).ends_with("tab_skills.svg"), "dann der freie Skillpunkt")
