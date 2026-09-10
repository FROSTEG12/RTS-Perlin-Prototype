extends SceneTree
const RANGE := preload("res://scripts/world/vision_range.gd")
func _initialize() -> void:
	assert(RANGE.radius(0) == 7 and RANGE.radius(5) == 7)
	assert(RANGE.radius(8) == 10 and RANGE.radius(12) == 10 and RANGE.radius(18) == 10)
	assert(RANGE.radius(20) == 7 and RANGE.radius(24) == RANGE.radius(0))
	assert(RANGE.radius(-1) == RANGE.radius(23))
	assert(is_equal_approx(RANGE.radius(7),8.5) and is_equal_approx(RANGE.radius(19),8.5))
	for i in 2400:
		var hour := i*0.01
		var value := RANGE.radius(hour)
		assert(value >= 7 and value <= 10)
		assert(absf(value-RANGE.radius(hour+0.01)) < 0.03)
	print("VISION_RANGE_PASS day10 night7 smooth_dawn_dusk midnight")
	quit()
