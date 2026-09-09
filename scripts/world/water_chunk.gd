extends Node2D

const TILE_WIDTH := 32.0
const TILE_HEIGHT := 16.0
const WATER_SHADER := preload("res://shaders/water.gdshader")

var cells := PackedByteArray()
var map_size := 0
var start_x := 0
var start_y := 0
var end_x := 0
var end_y := 0


func setup(
	new_cells: PackedByteArray,
	new_map_size: int,
	chunk_start_x: int,
	chunk_start_y: int,
	chunk_end_x: int,
	chunk_end_y: int,
	water_depth_texture: Texture2D,
	tile_dimensions: Vector2
) -> void:
	cells = new_cells
	map_size = new_map_size
	start_x = chunk_start_x
	start_y = chunk_start_y
	end_x = chunk_end_x
	end_y = chunk_end_y
	var shader_material := ShaderMaterial.new()
	shader_material.shader = WATER_SHADER
	shader_material.set_shader_parameter("depth_texture", water_depth_texture)
	shader_material.set_shader_parameter("map_grid_size", Vector2(map_size, map_size))
	shader_material.set_shader_parameter("iso_half_size", tile_dimensions * 0.5)
	material = shader_material
	queue_redraw()


func cell_to_world(cell_x: int, cell_y: int) -> Vector2:
	var map_center := (map_size - 1) / 2.0
	var grid_x := cell_x - map_center
	var grid_y := cell_y - map_center
	return Vector2(
		(grid_x - grid_y) * TILE_WIDTH * 0.5,
		(grid_x + grid_y) * TILE_HEIGHT * 0.5
	)


func _draw() -> void:
	var half_width := TILE_WIDTH * 0.5
	var half_height := TILE_HEIGHT * 0.5
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			if cells[y * map_size + x] == 0:
				continue
			var center := cell_to_world(x, y)
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -half_height),
				center + Vector2(half_width, 0.0),
				center + Vector2(0.0, half_height),
				center + Vector2(-half_width, 0.0),
			])
			draw_colored_polygon(diamond, Color.WHITE)
