extends SceneTree
## Headless-Test-Runner ohne Plugin.
## Aufruf: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
## Lädt alle tests/test_*.gd, ruft jede test_*-Methode, Exit-Code 1 bei Fehlern.


func _initialize() -> void:
	var total := 0
	var failed: Array[String] = []
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for file in files:
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			# Parse-Fehler: zählt als Fehlschlag, darf den Runner aber nicht hängen lassen.
			failed.append(file + ": konnte nicht geladen werden (Parse-Fehler?)")
			total += 1
			continue
		var case: TestCase = script.new()
		for m in script.get_script_method_list():
			var method_name: String = m["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			case.set_current(file + "::" + method_name)
			case.call(method_name)
		failed.append_array(case.failures)
	for f in failed:
		printerr("FAIL " + f)
	print("%d tests, %d failures" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
