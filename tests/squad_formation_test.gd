extends SceneTree
const FORMATION := preload("res://scripts/units/squad_formation.gd")

class Land extends Node:
	var bounds := Rect2i(0, 0, 20, 20)
	var blocked := {}
	func is_land(cell: Vector2i) -> bool:
		return bounds.has_point(cell) and not blocked.has(cell)

func _initialize() -> void:
	var land := Land.new()
	assert(FORMATION.SIZE == 15 and FORMATION.COLUMNS == 5)
	for count in range(1, 16):
		var cells := FORMATION.find_cells(land, Vector2i(10,10), count)
		assert(cells.size() == count)
		var used := {}
		for cell in cells:
			assert(land.is_land(cell) and not used.has(cell))
			used[cell] = true
	var full := FORMATION.find_cells(land, Vector2i(10,10), 15)
	for i in 15: assert(full[i] == Vector2i(8 + i % 5, 9 + i / 5))
	# Shore/edge: relocate the complete rectangle, keeping every adjacent cell.
	land.blocked[Vector2i(8,9)] = true
	var shifted := FORMATION.find_cells(land, Vector2i(10,10), 15)
	assert(shifted.size() == 15 and shifted != full)
	for i in 15: assert(shifted[i] == shifted[0] + Vector2i(i % 5, i / 5))
	assert(FORMATION.find_cells(land, Vector2i(0,0), 15).size() == 15)
	land.bounds = Rect2i(0,0,4,2)
	assert(FORMATION.find_cells(land, Vector2i(1,1), 15).is_empty())
	land.free()
	print("SQUAD_FORMATION_PASS 15_units 5x3 adjacent_cells shoreline partial_selection no_space")
	quit()
