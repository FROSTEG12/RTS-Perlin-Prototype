extends Node3D

# Temporary playtest switches; original squad/UI systems remain available.
@export var formation_features_enabled := false
@export var start_with_single_unit := true
@export var fog_of_war_enabled_at_start := false

const FORMATION := preload("res://scripts/units/squad_formation.gd")
const SQUAD_SIZE := FORMATION.SIZE
const DEFAULT_MAP_SIZE := 104
const DEFAULT_SCALE := 34.0
const DEFAULT_WATER := 40
const DEFAULT_RESOURCE_DENSITY := 130
const MINUTES_PER_DAY := 12.0
const DAY_NIGHT_LIGHTING := preload("res://scripts/environment/day_night_lighting.gd")

@onready var map_renderer: MapRenderer3D = $MapRenderer
@onready var lead_unit: Unit3D = $MapRenderer/LeadUnit
@onready var game_camera: IsometricGameCamera = $GameCamera
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var new_map_button: Button = $UI/MapControls/Margin/Rows/NewMapButton
@onready var seed_label: Label = $UI/MapControls/Margin/Rows/SeedLabel
@onready var time_label: Label = $UI/MapControls/Margin/Rows/TimeLabel
@onready var time_slider: HSlider = $UI/MapControls/Margin/Rows/TimeSlider
@onready var world_controls: PanelContainer = $UI/MapControls

var world_seed: int
var current_cells := PackedByteArray()
var pathfinder := GridPathfinder.new()
var is_generating := false
var current_time := 8.0
var current_day := 1
var simulation_speed := 1.0
var weather: Node3D
var rts: Control
var developer_tools: Control
var hud: Control
var pause_menu: Control
var display_layout: Node
var vision: Node3D
var placement: Node3D
var stockpile := {"Дерево": 0, "Камень": 0, "Металл": 0, "Мясо": 0, "Ягоды": 0, "Уголь": 0}
var local_team_id := 0
var player_units: Array[Unit3D] = []


func _ready() -> void:
	display_layout = preload("res://scripts/ui/display_layout.gd").new()
	display_layout.name = "DisplayLayout"
	add_child(display_layout)
	world_controls.get_node("Margin/Rows/ColorGradeToggle").toggled.connect(_on_color_grade_toggled)
	world_controls.get_node("Margin/Rows/ColorGradeStrength").value_changed.connect(_on_color_grade_strength)
	_on_color_grade_strength(world_controls.get_node("Margin/Rows/ColorGradeStrength").value)
	world_seed = int(Time.get_unix_time_from_system()) % 2_000_000_000
	weather = preload("res://scripts/environment/weather_effects.gd").new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(game_camera, world_seed)
	_setup_weather_controls()
	_setup_rts_controls()
	vision = preload("res://scripts/world/map_visibility.gd").new()
	vision.name = "MapVisibility"
	vision.world = self
	vision.enabled = fog_of_war_enabled_at_start
	add_child(vision)
	developer_tools = preload("res://scripts/ui/developer_tools.gd").new()
	developer_tools.name = "DeveloperTools"
	developer_tools.world = self
	$UI.add_child(developer_tools)
	time_slider.value_changed.connect(_on_time_slider_changed)
	_set_time_of_day(current_time)
	new_map_button.pressed.connect(_on_new_map_pressed)
	generate_world()
	_sync_weather_controls()
	hud = preload("res://scripts/ui/game_hud.gd").new()
	hud.world = self
	$UI.add_child(hud)
	# Utility menu above HUD; modal pause menu above both.
	$UI.move_child(developer_tools, -1)
	pause_menu = preload("res://scripts/ui/pause_menu.gd").new()
	pause_menu.world = self
	$UI.add_child(pause_menu)
	placement = preload("res://scripts/buildings/building_placement.gd").new()
	placement.name = "BuildingPlacement"
	placement.world = self
	add_child(placement)
	hud.buildings.building_selected.connect(placement.begin)
	print("WORLD_READY units=", player_units.size())


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
	_on_color_grade_strength(world_controls.get_node("Margin/Rows/ColorGradeStrength").value)


func _on_color_grade_strength(amount: float) -> void:
	var effect = world_environment.compositor.compositor_effects[0]
	effect.enabled = world_controls.get_node("Margin/Rows/ColorGradeToggle").button_pressed and amount > 0.0
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
	preload("res://scripts/world/tree_resources.gd").update_shadow_direction(map_renderer, -key_light.global_basis.z)
	if weather != null:
		weather.update_visuals(current_time, key_light, world_environment.environment)
	map_renderer.WORLD_EDGE.set_mist_color(map_renderer, world_environment.environment.background_color)






func generate_world() -> void:
	if placement != null: placement.reset_world()
	if rts != null:
		rts.reset()
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
	var spawn_cells := FORMATION.find_cells(map_renderer, spawn_cell, player_units.size(), DEFAULT_MAP_SIZE, pathfinder, spawn_cell)
	if spawn_cells.is_empty():
		push_error("No reachable land footprint for the default squad formation")
		return
	for index in player_units.size():
		var unit := player_units[index]
		var chosen: Vector2i = spawn_cells[index]
		unit.set_trail_wear(map_renderer.trail_wear)
		unit.place_on_cell(chosen, map_renderer.cell_to_world(chosen.x, chosen.y))
	seed_label.text = "Seed: %d  •  Вода: %d%%" % [world_seed, int(map_data["water_percent"])]
	if weather != null:
		weather.refresh_world(map_renderer.get_half_extent())
	if rts != null:
		rts.grid_overlay.refresh()
	game_camera.focus_on(lead_unit.global_position)
	if vision != null: vision.reset_world()


func _setup_weather_controls() -> void:
	var rows := world_controls.get_node("Margin/Rows")
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
	var focus := Button.new()
	focus.text = "К юниту"
	focus.pressed.connect(func():
		if rts != null and not rts.selected.is_empty():
			rts.focus_selected()
		else:
			game_camera.focus_on(lead_unit.global_position))
	rows.add_child(focus)
	var status := Label.new()
	status.name = "WeatherStatus"
	status.add_theme_font_size_override("font_size", 12)
	rows.add_child(status)


func _sync_weather_controls() -> void:
	var rows := world_controls.get_node("Margin/Rows")
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
	lead_unit.cancel_movement(map_renderer)
	var random := RandomNumberGenerator.new()
	random.randomize()
	world_seed = random.randi_range(1, 2_000_000_000)
	generate_world()
	new_map_button.text = "Новая карта"
	new_map_button.disabled = false
	is_generating = false



func _setup_rts_controls() -> void:
	lead_unit.squad_id = 1
	lead_unit.individual_control = start_with_single_unit
	player_units.append(lead_unit)
	var scene := preload("res://scenes/units/knight.tscn")
	for index in range(0 if start_with_single_unit else SQUAD_SIZE - 1):
		var unit := scene.instantiate() as Unit3D
		unit.name = "Worker_%d" % (index + 2)
		unit.display_name = "Синий рыцарь №%d" % (index + 2)
		unit.squad_id = 1
		map_renderer.add_child(unit)
		player_units.append(unit)
	rts = preload("res://scripts/input/rts_controller.gd").new()
	rts.name = "RTSControls"
	rts.world = self
	$UI.add_child(rts)
	# Prevent a focused button consuming Space, the selection-focus shortcut.
	for button in world_controls.find_children("*", "BaseButton", true, false):
		button.focus_mode = Control.FOCUS_NONE
