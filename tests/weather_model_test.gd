extends SceneTree
const MODEL = preload("res://scripts/weather_model.gd")
func _initialize() -> void:
	var weather := MODEL.new()
	weather.reset(4242)
	var twin := MODEL.new()
	twin.reset(4242)
	var daylight_rain := false
	var night_rain := false
	for minute in 60 * 24 * 20:
		var hour := fposmod(float(minute) / 60.0, 24.0)
		weather.advance(0.5, 1.0 / 60.0, hour)
		twin.advance(0.5, 1.0 / 60.0, hour)
		assert(weather.rain == twin.rain and weather.fog == twin.fog)
		for amount in [weather.rain, weather.fog, weather.cloud, weather.moisture]:
			assert(is_finite(amount) and amount >= 0.0 and amount <= 1.0)
		daylight_rain = daylight_rain or (hour > 9 and hour < 16 and weather.rain > 0.3)
		night_rain = night_rain or (hour < 4 and weather.rain > 0.3)
	assert(daylight_rain and night_rain)
	assert(MODEL.fog_potential(6, 1, 0.1, 0) > 0.8)
	assert(MODEL.fog_potential(12, 1, 0.1, 0) == 0.0)
	assert(MODEL.fog_potential(6, 0.1, 0.1, 0) == 0.0)
	assert(MODEL.fog_potential(6, 1, 0.8, 0) < MODEL.fog_potential(6, 1, 0.1, 0))
	assert(absf(MODEL.fog_potential(23.9999, 1, 0.1, 0) - MODEL.fog_potential(0, 1, 0.1, 0)) < 0.0001)
	weather.reset(10)
	weather.set_rain(true)
	for second in 90:
		weather.advance(1, 1.0 / 30.0, 1.0)
	assert(weather.rain > 0.75 and weather.moisture > 0.9)
	weather.set_rain(false)
	for second in 90:
		weather.advance(1, 1.0 / 30.0, 5.5)
	assert(weather.rain < 0.001 and weather.fog > 0.4)
	for second in 120:
		weather.advance(1, 1.0 / 30.0, 12)
	assert(weather.fog < 0.01)
	weather.fog_override = 0.95
	weather.advance(60, 0, 12)
	assert(weather.fog > 0.94)
	weather.fog_override = -1
	weather.advance(60, 0, 12)
	assert(weather.fog < 0.001)
	print("WEATHER PASS: 20 deterministic days, day/night rain, wet dawn fog, dry/windy suppression, burn-off, manual switches")
	quit()
