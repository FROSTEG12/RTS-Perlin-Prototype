extends SceneTree
const MODEL = preload("res://scripts/weather_model.gd")
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var rows = world.get_node("UI/MapControls/Margin/Rows")
	var speed: OptionButton = rows.get_node("SimulationSpeed")
	assert(speed.item_count == 3)
	speed.select(2)
	speed.item_selected.emit(2)
	assert(world.simulation_speed == 6.0)
	world.current_day = 5
	world._set_time_of_day(23.99)
	world.weather.climate.phase = MODEL.Phase.CLEAR
	world.weather.climate.remaining_hours = 4.0
	world.weather.climate.period_remaining_hours = 24.0
	world._process(1.0)
	assert(world.current_day == 6 and is_equal_approx(world.current_time, 0.19))
	assert(is_equal_approx(world.weather.climate.remaining_hours, 3.8))
	# The lighting-only slider changes neither the date nor the weather timer.
	world._on_time_slider_changed(18.0)
	assert(world.current_day == 6)
	assert(is_equal_approx(world.weather.climate.remaining_hours, 3.8))
	world.weather.climate.set_rain(false)
	world._process(1.0)
	assert(is_equal_approx(world.weather.climate.remaining_hours, 3.8))
	assert(is_equal_approx(world.current_time, 18.2))
	# Find an ordinary rainy reset, without forcing phase/rain after reset.
	var rainy_seed := -1
	for seed_value in 100:
		world.weather.climate.reset(seed_value)
		if world.weather.climate.rain > 0.3 and world.weather.climate.phase == MODEL.Phase.RAIN:
			rainy_seed = seed_value
			break
	assert(rainy_seed >= 0)
	world.current_day = 1
	world.simulation_speed = 1.0
	speed.select(0)
	world._set_time_of_day(8.0)
	world._sync_weather_controls()
	assert(rows.get_node("AutoWeather").button_pressed)
	assert(rows.get_node("RainToggle").button_pressed)
	assert(world.weather.rain_particles.amount_ratio > 0.0)
	assert(world.time_label.text.begins_with("День 1"))
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "weather_natural_rain_start.png")
	print("WEATHER_STARTUP PASS: day rollover, x6 shared clock, lighting slider isolation, manual override, naturally rainy startup seed=", rainy_seed)
	quit()
