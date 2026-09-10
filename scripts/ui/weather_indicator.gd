extends Control
## Generated weather artwork; uses the visible climate, not its next target.
const SUN = preload("res://assets/ui/generated_indicators/day.png")
const MOON = preload("res://assets/ui/generated_indicators/night.png")
const WEATHER_ICONS = {
	&"rain": preload("res://assets/ui/generated_indicators/rain.png"),
	&"fog": preload("res://assets/ui/generated_indicators/fog.png"),
	&"cloudy": preload("res://assets/ui/generated_indicators/cloudy.png"),
}
var condition: StringName = &"clear"
var daytime := true

func _init() -> void:
	custom_minimum_size = Vector2(28, 28)
	size_flags_vertical = SIZE_SHRINK_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = MOUSE_FILTER_PASS

func set_weather(value: StringName, is_daytime: bool) -> void:
	if condition != value or daytime != is_daytime:
		condition = value
		daytime = is_daytime
		queue_redraw()

func label_text() -> String:
	match condition:
		&"rain": return "Дождь"
		&"fog": return "Туман"
		&"cloudy": return "Пасмурно"
	return "Солнечно" if daytime else "Ясно"

func _draw() -> void:
	var center := size * 0.5
	var artwork: Texture2D = WEATHER_ICONS.get(condition, SUN if daytime else MOON)
	draw_texture_rect(artwork, Rect2(center - Vector2(14, 14), Vector2(28, 28)), false)
