extends Node3D

const DEFAULT_MAP_SIZE := 104
const DEFAULT_SCALE := 34.0
const DEFAULT_WATER := 40
const DEFAULT_RESOURCE_DENSITY := 130

@onready var map_renderer: MapRenderer3D = $MapRenderer
@onready var test_unit: TestUnit3D = $MapRenderer/TestUnit
@onready var game_camera: IsometricGameCamera = $GameCamera

var world_seed: int
var current_cells := PackedByteArray()
var pathfinder := GridPathfinder.new()


func _ready() -> void:
	world_seed = int(Time.get_unix_time_from_system()) % 2_000_000_000
	generate_world()


func generate_world() -> void:
	var generator := MapGenerator.new()
	var map_data := generator.generate_map(world_seed, DEFAULT_SCALE, DEFAULT_WATER, DEFAULT_MAP_SIZE)
	var generated_resources := generator.generate_resources(
		map_data["cells"], DEFAULT_MAP_SIZE, world_seed, DEFAULT_RESOURCE_DENSITY
	)
	current_cells = map_data["cells"]
	pathfinder.setup(current_cells, DEFAULT_MAP_SIZE)
	map_renderer.set_world(current_cells, DEFAULT_MAP_SIZE, generated_resources)
	game_camera.configure_map(map_renderer.get_half_extent())
	var spawn_cell := generator.find_mainland_spawn(current_cells, DEFAULT_MAP_SIZE)
	test_unit.place_on_cell(spawn_cell, map_renderer.cell_to_world(spawn_cell.x, spawn_cell.y))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		test_unit.cancel_movement(map_renderer)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var ground_position := game_camera.screen_to_ground(event.position, MapRenderer3D.LAND_Y)
		if not ground_position.is_finite():
			return
		var target := map_renderer.world_to_cell(ground_position)
		if not map_renderer.is_land(target):
			return
		var current_cell := test_unit.nearest_route_cell(map_renderer)
		var path := pathfinder.find_path(current_cell, target)
		if not path.is_empty():
			test_unit.follow_path(path, map_renderer)
			get_viewport().set_input_as_handled()
