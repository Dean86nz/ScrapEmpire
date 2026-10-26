extends SceneTree
## Lädt jedes Skript unter res://src und meldet Skripte, die nicht kompilieren (Exit 1).
func _initialize() -> void:
	var bad := 0
	var stack: Array[String] = ["res://src"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + d)
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: GDScript = load(dir + "/" + f)
				if s == null or not s.can_instantiate():
					print("KOMPILIERT NICHT: " + dir + "/" + f)
					bad += 1
	print("Skripte geprüft, Fehler: %d" % bad)
	quit(1 if bad > 0 else 0)
