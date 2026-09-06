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


func _ready() -> void:
	$UI/MapControls/Margin/Rows/ColorGradeToggle.toggled.connect(_on_color_grade_toggled)
	$UI/MapControls/Margin/Rows/ColorGradeStrength.value_changed.connect(_on_color_grade_strength)
	_on_color_grade_strength($UI/MapControls/Margin/Rows/ColorGradeStrength.value)
	world_seed = int(Time.get_unix_time_from_system()) % 2_000_000_000
	time_slider.value_changed.connect(_on_time_slider_changed)
	_set_time_of_day(current_time)
	new_map_button.pressed.connect(_on_new_map_pressed)
	building_button.toggled.connect(_on_building_button_toggled)
	generate_world()


func _process(delta: float) -> void:
	var hours_per_second := 24.0 / (MINUTES_PER_DAY * 60.0)
	_set_time_of_day(fmod(current_time + delta * hours_per_second, 24.0))


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
	time_label.text = "Время: %02d:%02d" % [hour, minute]


func _apply_day_night_lighting() -> void:
	DAY_NIGHT_LIGHTING.apply(current_time, key_light, world_environment.environment)
	map_renderer.WORLD_EDGE.set_mist_color(map_renderer, world_environment.environment.background_color)


func _on_building_button_toggled(enabled: bool) -> void:
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
	test_unit.place_on_cell(spawn_cell, map_renderer.cell_to_world(spawn_cell.x, spawn_cell.y))
	seed_label.text = "Seed: %d  •  Вода: %d%%" % [world_seed, int(map_data["water_percent"])]


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_placing_building:
			building_button.button_pressed = false
			get_viewport().set_input_as_handled()
			return
		test_unit.cancel_movement(map_renderer)
		get_viewport().set_input_as_handled()
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
		var current_cell := test_unit.nearest_route_cell(map_renderer)
		var path := pathfinder.find_path(current_cell, target)
		if not path.is_empty():
			test_unit.follow_path(path, map_renderer)
			get_viewport().set_input_as_handled()
