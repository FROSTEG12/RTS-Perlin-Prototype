extends SceneTree
const MODEL = preload("res://scripts/environment/weather_model.gd")
func _initialize() -> void:
	var events := 0
	var dry_days := 0
	var total_days := 12 * 180
	var largest_gap := 0.0
	for seed_value in 12:
		var weather := MODEL.new()
		weather.reset(seed_value * 777 + 4242)
		var rainy := PackedByteArray()
		rainy.resize(180)
		var previous_phase: int = weather.phase
		var previous_start := -1.0
		for tick in 180 * 96:
			var elapsed := tick * 0.25
			weather.advance(7.5, 0.25, fposmod(elapsed, 24.0))
			if weather.phase == MODEL.Phase.RAIN and previous_phase != MODEL.Phase.RAIN:
				events += 1
				if previous_start >= 0:
					var gap := elapsed - previous_start
					assert(gap >= 5.0, "Rain events must have a real dry break")
					largest_gap = maxf(largest_gap, gap)
				previous_start = elapsed
			if weather.rain > 0.1:
				rainy[tick / 96] = 1
			previous_phase = weather.phase
		for value in rainy:
			if value == 0: dry_days += 1
	var days_per_rain := float(total_days) / events
	var dry_fraction := float(dry_days) / total_days
	assert(days_per_rain > 0.4 and days_per_rain < 1.3)
	assert(dry_fraction > 0.08 and dry_fraction < 0.5)
	assert(largest_gap > 24.0 and largest_gap < 49.0)
	# Same schedule after one large step and many small steps.
	var batch := MODEL.new()
	var fine := MODEL.new()
	batch.reset(991)
	fine.reset(991)
	batch._advance_fronts(720.0)
	for step in 2880: fine._advance_fronts(0.25)
	assert(batch.phase == fine.phase and batch.wet_period == fine.wet_period)
	assert(absf(batch.remaining_hours - fine.remaining_hours) < 0.0001)
	assert(batch.rng.state == fine.rng.state)
	# Randomized starts must include both existing rain and clear weather.
	# No per-seed forced first-storm exception: use the warmed-up same model.
	var rainy_starts := 0
	var soon_starts := 0
	var waits: Array[float] = []
	for seed_value in 500:
		var start := MODEL.new()
		start.reset(seed_value * 1291 + 17)
		if start.rain > 0.12: rainy_starts += 1
		var wait_hours := 0.0
		while start.rain < 0.12 and wait_hours < 50.0:
			start.advance(7.5, 0.25, fposmod(8.0 + wait_hours, 24.0))
			wait_hours += 0.25
		assert(wait_hours < 44.0)
		if wait_hours <= 6.0: soon_starts += 1
		waits.append(wait_hours * 0.5) # real minutes at 12 min/day
	waits.sort()
	assert(rainy_starts > 30 and rainy_starts < 180)
	assert(soon_starts > 120)
	print("STARTS PASS: rain already visible=", rainy_starts, "/500; rain within 3 real minutes=", soon_starts,
		"/500; median first-rain minutes=", waits[250], "; p90=", waits[450], "; max=", waits[-1])
	print("FREQUENCY PASS: ", total_days, " simulated days; mean days/rain=", days_per_rain, "; completely dry days=", dry_fraction * 100.0, "%; longest gap hours=", largest_gap)
	quit()
