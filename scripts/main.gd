extends Node3D

const DEFAULT_MAP_SIZE := 104
const DEFAULT_SCALE := 34.0
const DEFAULT_WATER := 40
const DEFAULT_RESOURCE_DENSITY := 130
const MINUTES_PER_DAY := 12.0
const DAY_NIGHT_LIGHTING := preload("res://scripts/day_night_lighting.gd")
const TEMP_BUILDING_SCENE := preload("res://assets/temporary_building/house4.18.fbx")
const TEMP_BUILDING_FOOTPRINT := 4.5

@onready var map_renderer: MapRenderer3D = $MapRenderer
@onready var test_unit: TestUnit3D = $MapRenderer/TestUnit
@onready var game_camera: IsometricGameCamera = $GameCamera
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var temporary_buildings: Node3D = $TemporaryBuildings
@onready var new_map_button: Button = $UI/MapControls/Margin/Rows/NewMapButton
@onready var building_button: Button = $UI/MapControls/Margin/Rows/BuildingButton
@onready var seed_label: Label = $UI/MapControls/Margin/Rows/SeedLabel
@onready var time_label: Label = $UI/MapControls/Margin/Rows/TimeLabel
@onready var time_slider: HSlider = $UI/MapControls/Margin/Rows/TimeSlider

var world_seed: int
var current_cells := PackedByteArray()
var pathfinder := GridPathfinder.new()
var is_generating := false
var is_placing_building := false
var current_time := 8.0
var current_day := 1
var simulation_speed := 1.0
var weather: Node3D
var rts: Control
var player_units: Array[TestUnit3D] = []
var training: Node3D
var initial_squad_size := 5 # Optional interactive test: -- --units=150.


func _ready() -> void:
	$UI/MapControls/Margin/Rows/ColorGradeToggle.toggled.connect(_on_color_grade_toggled)
	$UI/MapControls/Margin/Rows/ColorGradeStrength.value_changed.connect(_on_color_grade_strength)
	_on_color_grade_strength($UI/MapControls/Margin/Rows/ColorGradeStrength.value)
	world_seed = int(Time.get_unix_time_from_system()) % 2_000_000_000
	weather = preload("res://scripts/weather_effects.gd").new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(game_camera, test_unit, world_seed)
	_setup_weather_controls()
	_setup_rts_controls()
	training = preload("res://scripts/knight_training.gd").new()
	training.name = "KnightTraining"
	training.world = self
	add_child(training)
	time_slider.value_changed.connect(_on_time_slider_changed)
	_set_time_of_day(current_time)
	new_map_button.pressed.connect(_on_new_map_pressed)
	building_button.toggled.connect(_on_building_button_toggled)
	generate_world()
	_sync_weather_controls()
	if initial_squad_size > 5:
		var center := Vector3.ZERO
		var occupied := {}
		for unit in player_units:
			center += unit.global_position
			assert(map_renderer.is_land(unit.grid_cell) and not occupied.has(unit.grid_cell))
			occupied[unit.grid_cell] = true
		game_camera.size = game_camera.MAX_SIZE
		game_camera.focus_on(center / player_units.size())
		rts.set_selection(player_units)
		print("INTERACTIVE_SQUAD_READY count=", player_units.size(), " unique_land_cells=", occupied.size())


func _process(delta: float) -> void:
	var hours_per_second := 24.0 / (MINUTES_PER_DAY * 60.0)
	var game_hours := delta * hours_per_second * simulation_speed
	# Shared elapsed clock for date, weather and lighting. The lighting slider
	# is an explicit preview override; it does not fabricate elapsed days.
	current_day += floori((current_time + game_hours) / 24.0)
	weather.climate.advance(delta, game_hours, current_time)
	_set_time_of_day(fmod(current_time + game_hours, 24.0))
	_sync_weather_controls()


func _on_color_grade_toggled(_enabled: bool) -> void:
	_on_color_grade_strength($UI/MapControls/Margin/Rows/ColorGradeStrength.value)


func _on_color_grade_strength(amount: float) -> void:
	var effect = world_environment.compositor.compositor_effects[0]
	effect.enabled = $UI/MapControls/Margin/Rows/ColorGradeToggle.button_pressed and amount > 0.0
	# Hue and tint are OKHSL controls supplied by Rytelier's effect.
	effect.shadows = Vector4(0.65, 0.055 * amount, lerpf(1.0, 1.18, amount), lerpf(1.0, 0.84, amount))
	effect.midtones = Vector4(0.30, 0.025 * amount, lerpf(1.0, 1.65, amount), lerpf(1.0, 1.12, amount))
	effect.highlights = Vector4(0.12, 0.055 * amount, lerpf(1.0, 1.08, amount), lerpf(1.0, 0.96, amount))
	effect.night_noise = 0.0


func _on_time_slider_changed(value: float) -> void:
	_set_time_of_day(value)


func _set_time_of_day(value: float) -> void:
	current_time = fposmod(value, 24.0)
	_apply_day_night_lighting()
	time_slider.set_value_no_signal(current_time)
	var hour := floori(current_time)
	var minute := floori(fmod(current_time, 1.0) * 60.0)
	time_label.text = "День %d · %02d:%02d" % [current_day, hour, minute]


func _apply_day_night_lighting() -> void:
	DAY_NIGHT_LIGHTING.apply(current_time, key_light, world_environment.environment)
	preload("res://scripts/tree_resources.gd").update_shadow_direction(map_renderer, -key_light.global_basis.z)
	if weather != null:
		weather.update_visuals(current_time, key_light, world_environment.environment)
	map_renderer.WORLD_EDGE.set_mist_color(map_renderer, world_environment.environment.background_color)


func _on_building_button_toggled(enabled: bool) -> void:
	if rts != null:
		rts.cancel_drag()
	is_placing_building = enabled
	building_button.text = "Кликните по суше…" if enabled else "Поставить дом"


func _place_temporary_building(world_position: Vector3) -> void:
	var building := TEMP_BUILDING_SCENE.instantiate() as Node3D
	if building == null:
		push_error("Temporary FBX root is not a Node3D")
		return
	temporary_buildings.add_child(building)
	_normalize_temporary_building_materials(building)
	var bounds := _get_model_bounds(building)
	var footprint := maxf(bounds.size.x, bounds.size.z)
	var uniform_scale := TEMP_BUILDING_FOOTPRINT / footprint if footprint > 0.001 else 1.0
	building.scale = Vector3.ONE * uniform_scale
	building.position = Vector3(
		world_position.x,
		MapRenderer3D.LAND_Y + 0.02 - bounds.position.y * uniform_scale,
		world_position.z
	)
	weather.refresh_world(map_renderer.get_half_extent())


func _normalize_temporary_building_materials(root: Node3D) -> void:
	# The source FBX flags every material as emissive and stores several diffuse
	# colors with partial alpha. Both make it turn white by day and reveal only
	# fragments of its textures at night.
	var corrected_materials := {}
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_index)
			if not source is StandardMaterial3D:
				continue
			var source_id := source.get_instance_id()
			if not corrected_materials.has(source_id):
				var corrected := source.duplicate() as StandardMaterial3D
				corrected.emission_enabled = false
				corrected.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				corrected.albedo_color.a = 1.0
				corrected.roughness = 0.82
				corrected_materials[source_id] = corrected
			mesh_instance.set_surface_override_material(surface_index, corrected_materials[source_id])


func _get_model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	var root_inverse := root.global_transform.affine_inverse()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative_transform := root_inverse * mesh_instance.global_transform
		var child_bounds := relative_transform * mesh_instance.get_aabb()
		result = result.merge(child_bounds) if has_bounds else child_bounds
		has_bounds = true
	return result


func generate_world() -> void:
	if rts != null:
		rts.reset()
	for building in temporary_buildings.get_children():
		building.queue_free()
	var generator := MapGenerator.new()
	var map_data := generator.generate_map(world_seed, DEFAULT_SCALE, DEFAULT_WATER, DEFAULT_MAP_SIZE)
	var generated_resources := generator.generate_resources(
		map_data["cells"], DEFAULT_MAP_SIZE, world_seed, DEFAULT_RESOURCE_DENSITY
	)
	current_cells = map_data["cells"]
	pathfinder.setup(current_cells, DEFAULT_MAP_SIZE)
	map_renderer.set_world(current_cells, DEFAULT_MAP_SIZE, generated_resources, map_data["bathymetry"])
	var cloud_random := RandomNumberGenerator.new()
	cloud_random.seed = world_seed ^ 0x5A17C9E3
	map_renderer.set_cloud_shadow_offset(Vector2(
		cloud_random.randf_range(-10_000.0, 10_000.0),
		cloud_random.randf_range(-10_000.0, 10_000.0)
	))
	game_camera.configure_map(map_renderer.get_half_extent())
	var spawn_cell := generator.find_mainland_spawn(current_cells, DEFAULT_MAP_SIZE)
	var used := {}
	for unit in player_units:
		var chosen := spawn_cell
		var found := false
		for radius in range(DEFAULT_MAP_SIZE):
			if found:
				break
			for y in range(-radius, radius + 1):
				if found:
					break
				for x in range(-radius, radius + 1):
					if maxi(absi(x), absi(y)) != radius:
						continue
					var candidate := spawn_cell + Vector2i(x, y)
					if not map_renderer.is_land(candidate):
						continue
					var occupied := false
					# Integer cells <2 units apart are exactly these 3x3 neighbors.
					for oy in range(-1, 2):
						for ox in range(-1, 2):
							if used.has(candidate + Vector2i(ox, oy)): occupied = true
					if not occupied and not pathfinder.find_path(spawn_cell, candidate).is_empty():
						chosen = candidate
						found = true
						break
		used[chosen] = true
		unit.set_trail_wear(map_renderer.trail_wear)
		unit.place_on_cell(chosen, map_renderer.cell_to_world(chosen.x, chosen.y))
	seed_label.text = "Seed: %d  •  Вода: %d%%" % [world_seed, int(map_data["water_percent"])]
	if weather != null:
		weather.refresh_world(map_renderer.get_half_extent())
	if rts != null:
		rts.grid_overlay.refresh()
	game_camera.focus_on(test_unit.global_position)
	if training != null:
		training.reset_arena()


func _setup_weather_controls() -> void:
	var rows := $UI/MapControls/Margin/Rows
	time_slider.tooltip_text = "Проверка освещения: переводит часы, но не проматывает погоду. Для смены погоды используй скорость времени."
	var speed := OptionButton.new()
	speed.name = "SimulationSpeed"
	for value in [1, 3, 6]:
		speed.add_item("Время ×%d" % value)
	speed.tooltip_text = "Ускоряет часы, смену дней и погоду вместе. Не ускоряет юнита или анимации."
	speed.item_selected.connect(func(index: int): simulation_speed = [1.0, 3.0, 6.0][index])
	rows.add_child(speed)
	var separator := HSeparator.new()
	rows.add_child(separator)
	var automatic := CheckButton.new()
	automatic.name = "AutoWeather"
	automatic.text = "Автопогода"
	automatic.button_pressed = true
	automatic.toggled.connect(func(enabled: bool): weather.climate.automatic = enabled)
	rows.add_child(automatic)
	var rain := CheckButton.new()
	rain.name = "RainToggle"
	rain.text = "Дождь"
	rain.tooltip_text = "Ручное управление дождём. Автопогода отключится; переход занимает несколько секунд."
	rain.toggled.connect(func(enabled: bool):
		weather.climate.set_rain(enabled)
		automatic.set_pressed_no_signal(false))
	rows.add_child(rain)
	var fog := CheckButton.new()
	fog.name = "FogPreview"
	fog.text = "Туман: тест"
	fog.tooltip_text = "Показать плотный туман в любое время. Выключение возвращает естественный расчёт."
	fog.toggled.connect(func(enabled: bool): weather.climate.fog_override = 0.95 if enabled else -1.0)
	rows.add_child(fog)
	var focus := Button.new()
	focus.text = "К юниту"
	focus.pressed.connect(func():
		if rts != null and not rts.selected.is_empty():
			rts.focus_selected()
		else:
			game_camera.focus_on(test_unit.global_position))
	rows.add_child(focus)
	var status := Label.new()
	status.name = "WeatherStatus"
	status.add_theme_font_size_override("font_size", 12)
	rows.add_child(status)


func _sync_weather_controls() -> void:
	var rows := $UI/MapControls/Margin/Rows
	rows.get_node("AutoWeather").set_pressed_no_signal(weather.climate.automatic)
	var requested_rain: bool = weather.climate.phase == weather.MODEL.Phase.RAIN if weather.climate.automatic else weather.climate.manual_rain
	rows.get_node("RainToggle").set_pressed_no_signal(requested_rain)
	rows.get_node("WeatherStatus").text = "%s · Влажность %d%%" % [weather.climate.description(), roundi(weather.climate.moisture * 100.0)]


func _on_new_map_pressed() -> void:
	if is_generating:
		return
	is_generating = true
	new_map_button.disabled = true
	new_map_button.text = "Генерация…"
	await get_tree().process_frame
	test_unit.cancel_movement(map_renderer)
	var random := RandomNumberGenerator.new()
	random.randomize()
	world_seed = random.randi_range(1, 2_000_000_000)
	generate_world()
	new_map_button.text = "Новая карта"
	new_map_button.disabled = false
	is_generating = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing_building or is_generating:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		building_button.button_pressed = false
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_placing_building:
			building_button.button_pressed = false
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ground_position := game_camera.screen_to_ground(event.position, MapRenderer3D.LAND_Y)
		if not ground_position.is_finite():
			return
		var target := map_renderer.world_to_cell(ground_position)
		if not map_renderer.is_land(target):
			return
		if is_placing_building:
			_place_temporary_building(map_renderer.cell_to_world(target.x, target.y))
			get_viewport().set_input_as_handled()
			return


func _setup_rts_controls() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--units="):
			var value := argument.trim_prefix("--units=")
			if value.is_valid_int(): initial_squad_size = clampi(int(value), 1, 300)
	player_units.append(test_unit)
	var scene := preload("res://scenes/worker_unit.tscn")
	for index in range(initial_squad_size - 1):
		var unit := scene.instantiate() as TestUnit3D
		unit.name = "Worker_%d" % (index + 2)
		unit.display_name = "Синий рыцарь №%d" % (index + 2)
		map_renderer.add_child(unit)
		player_units.append(unit)
	rts = preload("res://scripts/rts_controller.gd").new()
	rts.name = "RTSControls"
	rts.world = self
	$UI.add_child(rts)
	# Prevent a focused button consuming Space, the selection-focus shortcut.
	for button in $UI/MapControls.find_children("*", "BaseButton", true, false):
		button.focus_mode = Control.FOCUS_NONE
