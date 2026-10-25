class_name TestCase
extends RefCounted
## Minimale Test-Basisklasse. Jede Methode, die mit "test_" beginnt, wird vom
## Runner (tests/run_tests.gd) aufgerufen. Fehlschläge werden gesammelt, nicht geworfen.

var failures: Array[String] = []
var _current: String = ""


func set_current(name: String) -> void:
	_current = name


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s %s" % [_current, str(expected), str(actual), msg])


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s: expected true %s" % [_current, msg])


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		failures.append("%s: expected false %s" % [_current, msg])
