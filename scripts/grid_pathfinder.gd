class_name GridPathfinder
extends RefCounted

var astar_grid := AStarGrid2D.new()
var map_size := 0


func setup(cells: PackedByteArray, new_map_size: int) -> void:
	map_size = new_map_size
	astar_grid = AStarGrid2D.new()
	astar_grid.region = Rect2i(0, 0, map_size, map_size)
	astar_grid.cell_size = Vector2.ONE
	astar_grid.cell_shape = AStarGrid2D.CELL_SHAPE_SQUARE
	# Кратчайший 8-направленный путь: можно огибать одиночный угол,
	# но нельзя протискиваться по диагонали между двумя препятствиями.
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_grid.update()
	for y in range(map_size):
		for x in range(map_size):
			if cells[y * map_size + x] == 1:
				astar_grid.set_point_solid(Vector2i(x, y), true)


func find_path(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if not astar_grid.is_in_boundsv(start) or not astar_grid.is_in_boundsv(finish):
		return empty_path
	if astar_grid.is_point_solid(start) or astar_grid.is_point_solid(finish):
		return empty_path
	return astar_grid.get_id_path(start, finish, false)
