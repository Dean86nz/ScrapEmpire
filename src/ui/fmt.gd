class_name Fmt
extends RefCounted
## Zahlen für die Anzeige.


## Ganzzahl mit Tausenderpunkt (de) bzw. -komma (en): 12.000 / 12,000.
static func int_str(n: int) -> String:
	var s := str(absi(n))
	var sep := "." if TranslationServer.get_locale().begins_with("de") else ","
	var out := ""
	while s.length() > 3:
		out = sep + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Kurz für große Zahlen (MS57): bis 9.999 exakt, dann 12,3K / 3,4M / 1,2B (de mit Komma).
static func short(n: int) -> String:
	var a := absi(n)
	if a < 10000:
		return int_str(n)
	var units := [[1000000000.0, "B"], [1000000.0, "M"], [1000.0, "K"]]
	for u: Array in units:
		if a >= float(u[0]):
			var v := float(a) / float(u[0])
			var txt := ("%.1f" % v) if v < 100.0 else ("%d" % int(v))
			if TranslationServer.get_locale().begins_with("de"):
				txt = txt.replace(".", ",")
			return ("-" if n < 0 else "") + txt + str(u[1])
	return int_str(n)
