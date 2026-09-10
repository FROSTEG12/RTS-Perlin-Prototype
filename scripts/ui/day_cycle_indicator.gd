extends Control
## Presentation of the existing world clock, not a second simulation clock.
const PHASE_ICONS = {
	&"morning": preload("res://assets/ui/generated_indicators/morning.png"),
	&"day": preload("res://assets/ui/generated_indicators/day.png"),
	&"evening": preload("res://assets/ui/generated_indicators/evening.png"),
	&"night": preload("res://assets/ui/generated_indicators/night.png"),
}
const PHASE_NAMES = {&"morning": "Утро", &"day": "День", &"evening": "Вечер", &"night": "Ночь"}
const DAY_COLOR := Color("#eac875")
const NIGHT_COLOR := Color("#aaa2ec")
var hour := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(36, 36)
	size_flags_vertical = SIZE_SHRINK_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = MOUSE_FILTER_PASS

static func is_day(value: float) -> bool:
	var t := fposmod(value, 24.0)
	return t >= 6.0 and t < 18.0

static func marker_direction(value: float) -> Vector2:
	# Midnight bottom, dawn left, noon top, dusk right.
	return Vector2.from_angle(fposmod(value, 24.0) * TAU / 24.0 + PI * 0.5)

static func icon_phase(value: float) -> StringName:
	# Presentation windows only; ring halves and world lighting are unchanged.
	var t := fposmod(value, 24.0)
	if t >= 6.0 and t < 9.0: return &"morning"
	if t >= 9.0 and t < 17.0: return &"day"
	if t >= 17.0 and t < 20.0: return &"evening"
	return &"night"

static func phase_progress(value: float) -> float:
	return fposmod(value - (6.0 if is_day(value) else 18.0), 24.0) / 12.0

func set_hour(value: float) -> void:
	var next := fposmod(value, 24.0)
	if not is_equal_approx(hour, next):
		hour = next
		queue_redraw()
	var remaining := ceili((1.0 - phase_progress(hour)) * 12.0 * 60.0)
	tooltip_text = "%s · до %s %02d:%02d" % [PHASE_NAMES[icon_phase(hour)], "заката" if is_day(hour) else "рассвета", remaining / 60, remaining % 60]

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	var day := is_day(hour)
	draw_arc(center, radius, PI, TAU, 48, Color("#8f80535c"), 2.0, true)
	draw_arc(center, radius, 0, PI, 48, Color("#73769466"), 2.0, true)
	var start := PI if day else 0.0
	var progress := phase_progress(hour)
	if progress > 0.0001:
		draw_arc(center, radius, start, start + progress * PI, 48, DAY_COLOR if day else NIGHT_COLOR, 2.6, true)
	draw_texture_rect(PHASE_ICONS[icon_phase(hour)], Rect2(center - Vector2(12, 12), Vector2(24, 24)), false)
	var direction := marker_direction(hour)
	draw_line(center + direction * (radius - 2.2), center + direction * (radius + 2.2), Color("#f1f4f3"), 2.2, true)
	draw_circle(center + direction * radius, 1.6, Color("#f1f4f3"), true, -1, true)
