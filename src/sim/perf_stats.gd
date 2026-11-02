class_name PerfStats
extends RefCounted
## Leistungsanzeige (MS79): zählt Durchsatz in 10-s-Fächern über die letzten 5 Minuten.
## Schlüssel: "trash" (Teile, die am Schiff ankommen), "bolts" (Bolts daraus), "station"/"roamer"/
## "rusty" (abgeliefert je Quelle). Rein zählend, deterministisch; Rate = Summe / abgedeckte Zeit.

const BUCKET_TICKS := 200          # 10 s bei 20 Ticks/s
const BUCKETS := 30                # 30 × 10 s = 5 min

var _data: Dictionary = {}         # Schlüssel → Array[int] (BUCKETS Fächer)
var _bucket := -1                  # laufende Fach-Nummer (tick / BUCKET_TICKS)
var _first_tick := -1              # ab wann gezählt wird (für kurze Spielzeiten)


func add(key: String, n: int, tick: int) -> void:
	if n == 0:
		return
	_roll(tick)
	if not _data.has(key):
		var arr: Array[int] = []
		arr.resize(BUCKETS)
		arr.fill(0)
		_data[key] = arr
	_data[key][_bucket % BUCKETS] += n


## Rate pro Minute über die letzten 5 Minuten (bzw. seit Zählbeginn, mindestens 30 s).
func per_min(key: String, tick: int) -> float:
	_roll(tick)
	if not _data.has(key) or _first_tick < 0:
		return 0.0
	var sum := 0
	for v: int in _data[key]:
		sum += v
	var span_ticks := clampi(tick - _first_tick, BUCKET_TICKS * 3, BUCKET_TICKS * BUCKETS)
	return float(sum) * 1200.0 / float(span_ticks)


func _roll(tick: int) -> void:
	if _first_tick < 0:
		_first_tick = tick
	var b := tick / BUCKET_TICKS
	if _bucket < 0:
		_bucket = b
		return
	# Fächer, die seit dem letzten Mal abgelaufen sind, leeren
	var steps := mini(b - _bucket, BUCKETS)
	for i in steps:
		var idx := (_bucket + 1 + i) % BUCKETS
		for key in _data:
			_data[key][idx] = 0
	_bucket = maxi(_bucket, b)


func to_dict() -> Dictionary:
	var d := {}
	for key in _data:
		d[key] = (_data[key] as Array).duplicate()
	return {"data": d, "bucket": _bucket, "first": _first_tick}


func from_dict(d: Dictionary) -> void:
	_data.clear()
	for key in d.get("data", {}):
		var arr: Array[int] = []
		for v in d["data"][key]:
			arr.append(int(v))
		arr.resize(BUCKETS)
		_data[str(key)] = arr
	_bucket = int(d.get("bucket", -1))
	_first_tick = int(d.get("first", -1))
