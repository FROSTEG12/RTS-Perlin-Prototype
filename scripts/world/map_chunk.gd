extends Node2D

const TILE_WIDTH := 32.0
const TILE_HEIGHT := 16.0
const GRID_COLOR := Color(0.035, 0.12, 0.13, 0.14)

var cells := PackedByteArray()
var map_size := 0
var start_x := 0
var start_y := 0
var end_x := 0
var end_y := 0
var show_grid := false


func setup(
	new_cells: PackedByteArray,
	new_map_size: int,
	chunk_start_x: int,
	chunk_start_y: int,
	chunk_end_x: int,
	chunk_end_y: int,
	grid_enabled: bool
) -> void:
	cells = new_cells
	map_size = new_map_size
	start_x = chunk_start_x
	start_y = chunk_start_y
	end_x = chunk_end_x
	end_y = chunk_end_y
	show_grid = grid_enabled
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
			if cells[y * map_size + x] == 1:
				continue
			var center := cell_to_world(x, y)
			if show_grid:
				var outline := PackedVector2Array([
					center + Vector2(0.0, -half_height),
					center + Vector2(half_width, 0.0),
					center + Vector2(0.0, half_height),
					center + Vector2(-half_width, 0.0),
					center + Vector2(0.0, -half_height),
				])
				draw_polyline(outline, GRID_COLOR, 0.45, true)
