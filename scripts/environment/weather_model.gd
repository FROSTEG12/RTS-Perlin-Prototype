extends RefCounted
## Small deterministic weather model. Game hours drive fronts/moisture;
## real seconds smooth visuals, so the time slider never skips a storm.
enum Phase { CLEAR, CLOUDING, RAIN, CLEARING }
# Sample a bounded front arrival, not endless failed chance rolls. Dry spells
# can span a full day; wetter fronts contain several separated showers.
var rng := RandomNumberGenerator.new()
var phase := Phase.CLEAR
var remaining_hours := 4.0
var wet_period := false
var period_remaining_hours := 96.0
var automatic := true
var manual_rain := false
var rain := 0.0
var cloud := 0.0
var fog := 0.0
var moisture := 0.18
var wind := 0.18
var storm_strength := 0.75
var fog_override := -1.0

func reset(seed_value: int, starting_hour: float = 8.0) -> void:
	rng.seed = seed_value ^ 0x43B1CA
	phase = Phase.CLEAR
	wet_period = rng.randf() < 0.5
	remaining_hours = _clear_duration()
	period_remaining_hours = _period_duration()
	automatic = true
	manual_rain = false
	rain = 0.0
	cloud = 0.0
	fog = 0.0
	moisture = 0.18
	wind = 0.18
	fog_override = -1.0
	storm_strength = 0.75
	# Start in the middle of a living climate rather than granting every new
	# session a guaranteed dry interval. Warm up moisture/clouds as well as the
	# phase, so a rainy start is actually rainy on the very first visible frame.
	var warmup_steps := rng.randi_range(6 * 96, 12 * 96)
	for step in warmup_steps:
		var historical_hour := fposmod(starting_hour - (warmup_steps - step - 1) * 0.25, 24.0)
		advance(7.5, 0.25, historical_hour)

func _clear_duration() -> float:
	return rng.randf_range(3.0, 9.0) if wet_period else rng.randf_range(18.0, 42.0)

func _period_duration() -> float:
	return rng.randf_range(24.0, 60.0) if wet_period else rng.randf_range(24.0, 72.0)

func _advance_fronts(game_hours: float) -> void:
	# Process both clocks chronologically, including when a test advances a
	# large interval. RNG order must not depend on frame rate.
	var elapsed := maxf(game_hours, 0.0)
	while elapsed > 0.0:
		var step := minf(elapsed, minf(remaining_hours, period_remaining_hours))
		remaining_hours -= step
		period_remaining_hours -= step
		elapsed -= step
		if period_remaining_hours <= 0.0:
			wet_period = not wet_period
			period_remaining_hours += _period_duration()
		if remaining_hours <= 0.0:
			_next_phase()

func set_rain(enabled: bool) -> void:
	automatic = false
	manual_rain = enabled

func _next_phase() -> void:
	phase = (phase + 1) % 4
	match phase:
		Phase.CLEAR:
			remaining_hours += _clear_duration()
		Phase.CLOUDING:
			storm_strength = rng.randf_range(0.4, 1.0)
			remaining_hours += rng.randf_range(0.35, 0.8)
		Phase.RAIN:
			remaining_hours += rng.randf_range(1.5, 4.0)
		Phase.CLEARING:
			remaining_hours += rng.randf_range(0.4, 1.0)

static func fog_potential(hour: float, wetness: float, wind_amount: float, cloud_amount: float) -> float:
	var h := fposmod(hour, 24.0)
	# Overnight cooling peaks around dawn; sunshine gradually burns it off.
	var cooling := (1.0 - smoothstep(6.5, 10.5, h)) * lerpf(0.22, 1.0, smoothstep(0.0, 4.0, h))
	cooling += smoothstep(20.0, 24.0, h) * 0.22
	var humidity := smoothstep(0.28, 0.85, wetness)
	return clampf(cooling * humidity * (1.0 - wind_amount * 0.85) * (1.0 - cloud_amount * 0.65), 0.0, 1.0)

func advance(seconds: float, game_hours: float, hour: float) -> void:
	if automatic:
		_advance_fronts(game_hours)
	var rain_target := storm_strength if automatic and phase == Phase.RAIN else 0.0
	var cloud_target := 1.0 if automatic and phase in [Phase.CLOUDING, Phase.RAIN] else 0.0
	if not automatic:
		rain_target = 0.8 if manual_rain else 0.0
		cloud_target = 1.0 if manual_rain else 0.0
	var response := 1.0 - exp(-maxf(seconds, 0.0) / 4.5)
	cloud = lerpf(cloud, cloud_target, response)
	# A cloud cover precedes the first drops.
	rain = lerpf(rain, rain_target * smoothstep(0.15, 0.65, cloud), response)
	wind = lerpf(wind, lerpf(0.12, 0.52, rain), response * 0.5)
	var daylight := smoothstep(6.0, 10.0, hour) * (1.0 - smoothstep(16.0, 20.0, hour))
	moisture = clampf(moisture + game_hours * (rain * 1.2 - (0.022 + daylight * 0.07) * (1.0 - rain)), 0.0, 1.0)
	var target_fog := maxf(fog_potential(hour, moisture, wind, cloud), rain * 0.10)
	if fog_override >= 0.0:
		target_fog = fog_override
	fog = lerpf(fog, target_fog, 1.0 - exp(-maxf(seconds, 0.0) / 7.0))

func condition() -> StringName:
	if rain > 0.12:
		return &"rain"
	if fog > 0.18:
		return &"fog"
	if cloud > 0.25:
		return &"cloudy"
	return &"clear"

func description() -> String:
	match condition():
		&"rain": return "Дождь · %d%%" % roundi(rain * 100.0)
		&"fog": return "Туман · %d%%" % roundi(fog * 100.0)
		&"cloudy": return "Пасмурно"
	return "Ясно"
