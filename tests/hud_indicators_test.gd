extends SceneTree
const CYCLE = preload("res://scripts/ui/day_cycle_indicator.gd")
const WEATHER = preload("res://scripts/ui/weather_indicator.gd")
const MODEL = preload("res://scripts/environment/weather_model.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	assert(CYCLE.marker_direction(0).is_equal_approx(Vector2.DOWN))
	assert(CYCLE.marker_direction(6).is_equal_approx(Vector2.LEFT))
	assert(CYCLE.marker_direction(12).is_equal_approx(Vector2.UP))
	assert(CYCLE.marker_direction(18).is_equal_approx(Vector2.RIGHT))
	assert(CYCLE.marker_direction(24).is_equal_approx(CYCLE.marker_direction(0)))
	assert(not CYCLE.is_day(5.999) and CYCLE.is_day(6))
	assert(CYCLE.is_day(17.999) and not CYCLE.is_day(18))
	assert(is_equal_approx(CYCLE.phase_progress(12), 0.5))
	assert(is_equal_approx(CYCLE.phase_progress(0), 0.5))
	assert(is_equal_approx(CYCLE.phase_progress(18), 0.0))
	assert(CYCLE.marker_direction(23.999).distance_to(CYCLE.marker_direction(0.001)) < 0.001)
	for sample in [[5.999, &"night"], [6.0, &"morning"], [8.999, &"morning"], [9.0, &"day"], [16.999, &"day"], [17.0, &"evening"], [19.999, &"evening"], [20.0, &"night"], [24.0, &"night"], [-1.0, &"night"]]:
		assert(CYCLE.icon_phase(sample[0]) == sample[1])
	var artwork_paths: Array[String] = []
	for artwork in CYCLE.PHASE_ICONS.values() + WEATHER.WEATHER_ICONS.values():
		assert(artwork.resource_path not in artwork_paths)
		artwork_paths.append(artwork.resource_path)
		var source := Image.load_from_file(ProjectSettings.globalize_path(artwork.resource_path))
		assert(artwork.resource_path.begins_with("res://assets/ui/generated_indicators/"))
		assert(source.get_width() >= 1024 and source.detect_alpha() != Image.ALPHA_NONE)
		assert(source.get_pixel(0, 0).a < 0.01)
		var import_settings := ConfigFile.new()
		assert(import_settings.load(artwork.resource_path + ".import") == OK)
		assert(import_settings.get_value("params", "mipmaps/generate") == true)
		assert(import_settings.get_value("params", "process/size_limit") == 256)
	assert(artwork_paths.size() == 7)
	root.size = Vector2i(1000,240)
	root.content_scale_size = Vector2i(1000,240)
	var background := ColorRect.new()
	background.color = Color("#0a151d")
	background.size = Vector2(1000,240)
	root.add_child(background)
	var times := [0.0, 5.983333, 6.0, 9.65, 12.0, 17.5, 18.0, 22.116667]
	for i in times.size():
		var ring := CYCLE.new()
		ring.position = Vector2(32 + i * 120, 35)
		root.add_child(ring)
		ring.set_hour(times[i])
		assert(ring.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		assert(ring.custom_minimum_size == Vector2(36,36))
		var caption := Label.new()
		caption.position = Vector2(22 + i * 120, 82)
		caption.text = "%02d:%02d\n%s" % [int(times[i]), roundi(fposmod(times[i], 1) * 60), CYCLE.PHASE_NAMES[CYCLE.icon_phase(times[i])]]
		root.add_child(caption)
	var samples := [
		[0.8, 0.6, 1.0, &"rain", true, "Дождь"],
		[0.0, 0.4, 0.6, &"fog", true, "Туман"],
		[0.0, 0.0, 0.8, &"cloudy", true, "Пасмурно"],
		[0.0, 0.0, 0.0, &"clear", true, "Солнечно"],
		[0.0, 0.0, 0.0, &"clear", false, "Ясно"],
	]
	var climate := MODEL.new()
	for i in samples.size():
		var sample: Array = samples[i]
		climate.rain = sample[0]
		climate.fog = sample[1]
		climate.cloud = sample[2]
		assert(climate.condition() == sample[3])
		var glyph := WEATHER.new()
		glyph.position = Vector2(32 + i * 185, 140)
		root.add_child(glyph)
		glyph.set_weather(climate.condition(), sample[4])
		assert(glyph.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		assert(glyph.label_text() == sample[5])
		var caption := Label.new()
		caption.position = Vector2(72 + i * 185, 144)
		caption.text = glyph.label_text()
		root.add_child(caption)
	assert(climate.description() == "Ясно")
	if DisplayServer.get_name() != "headless":
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/hud-indicators.png")
	print("HUD_INDICATORS_PASS compass times four phase boundaries seven original icons weather priority clear night")
	quit()
