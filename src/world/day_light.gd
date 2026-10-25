class_name DayLight
extends CanvasModulate
## Weiches Tageslicht ohne Nacht und gelegentlicher leichter Regen (rein kosmetisch).
## Farbe pendelt zwischen warmem Morgen und kühlem Nachmittag; nie dunkler als 90 %.

signal rain_started
signal rain_stopped

const WARM := Color(1.0, 0.975, 0.92)
const COOL := Color(0.92, 0.955, 1.03)
const RAIN_TINT := Color(0.86, 0.9, 1.0)

var day_cycle_s := 360.0
var rain_min_gap := 240.0
var rain_max_gap := 420.0
var rain_duration := 30.0
var enabled := true

var _t := 0.0
var _rain_timer := 0.0
var _raining := false
var _rain_left := 0.0
var _rng := RandomNumberGenerator.new()


func setup(cfg: Dictionary) -> void:
	day_cycle_s = float(cfg.get("day_cycle_s", 360))
	var r: Dictionary = cfg.get("rain", {})
	rain_min_gap = float(r.get("min_gap_s", 240))
	rain_max_gap = float(r.get("max_gap_s", 420))
	rain_duration = float(r.get("duration_s", 30))
	_rng.randomize()
	_rain_timer = _rng.randf_range(rain_min_gap, rain_max_gap)


## Tageslichtfarbe für einen Zyklusanteil 0..1 (statisch, testbar).
static func color_at(fraction: float) -> Color:
	var k := 0.5 - 0.5 * cos(fraction * TAU)  # 0 → warm, 0.5 → kühl, 1 → warm
	return WARM.lerp(COOL, k)


func is_raining() -> bool:
	return _raining


func _process(delta: float) -> void:
	if not enabled:
		color = Color.WHITE
		return
	_t = fmod(_t + delta, day_cycle_s)
	var c := color_at(_t / day_cycle_s)
	if _raining:
		_rain_left -= delta
		c = c * RAIN_TINT
		if _rain_left <= 0.0:
			_raining = false
			_rain_timer = _rng.randf_range(rain_min_gap, rain_max_gap)
			rain_stopped.emit()
	else:
		_rain_timer -= delta
		if _rain_timer <= 0.0:
			_raining = true
			_rain_left = rain_duration
			rain_started.emit()
	color = color.lerp(c, minf(1.0, delta * 2.0))


## Für Tests und Debug: Regen sofort starten.
func start_rain_now() -> void:
	_rain_timer = 0.0
