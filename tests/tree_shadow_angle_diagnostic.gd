extends SceneTree
const CYCLE = preload("res://scripts/day_night_lighting.gd")
func _initialize() -> void:
	var tree_plane_normal := Vector3(10.5, 18.0, 10.5).normalized()
	var minimum := 1.0
	var closest_minute := 0
	for minute in range(7 * 60, 8 * 60 + 1):
		var hour := minute / 60.0
		var sun_basis := Basis.from_euler(CYCLE.sample(hour).rotation)
		var sun_direction := -sun_basis.z
		var projected_area := absf(tree_plane_normal.dot(sun_direction))
		if projected_area < minimum:
			minimum = projected_area
			closest_minute = minute
		if minute in [420, 447, 458, 460, 470, 480]:
			print("TREE_SHADOW ", minute / 60, ":", minute % 60, " projected card area fraction=", projected_area)
	print("MINIMUM projected card area=", minimum, " at ", closest_minute / 60, ":", closest_minute % 60)
	quit()
