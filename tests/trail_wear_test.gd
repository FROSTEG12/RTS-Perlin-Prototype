extends SceneTree
const WEAR = preload("res://scripts/effects/trail_wear.gd")

func field(size: float = 104.0, water: bool = false) -> Node:
	var result := WEAR.new()
	var cells := PackedByteArray()
	cells.resize(104 * 104)
	cells.fill(1 if water else 0)
	result.configure(size, cells, 104)
	return result

func traverse(wear: Node, id: int, steps: int, reverse: bool = false) -> void:
	wear.forget_unit(id)
	var a := Vector3(-1.8, 0.1, 0)
	var b := Vector3(1.8, 0.1, 0)
	if reverse:
		var temp := a
		a = b
		b = temp
	for index in steps:
		wear.record_movement(id, a.lerp(b, float(index) / steps), a.lerp(b, float(index + 1) / steps))
	wear.process_pending(8192)

func _initialize() -> void:
	var wear := field()
	for tick in 100: wear.record_movement(1, Vector3.ZERO, Vector3.ZERO)
	assert(wear.pending.is_empty() and wear.wear_at(Vector3.ZERO) == 0)
	wear.record_movement(1, Vector3(-20, 0, 0), Vector3(20, 0, 0))
	assert(wear.pending.is_empty(), "Teleport drew a trail")
	traverse(wear, 1, 120)
	var first: float = wear.wear_at(Vector3.ZERO)
	assert(first > 0.0 and first < 0.2)
	for pass_index in 30: traverse(wear, 1, 120, pass_index % 2 == 0)
	assert(wear.wear_at(Vector3.ZERO) == 1.0)
	for value in wear.field: assert(value >= 0.0 and value <= 1.0)
	var coarse := field()
	var fine := field()
	traverse(coarse, 1, 12)
	traverse(fine, 1, 360)
	for index in coarse.field.size():
		assert(absf(coarse.field[index] - fine.field[index]) < 0.00002, "Wear depends on frame rate")
	var crowd := field()
	traverse(crowd, 1, 120)
	traverse(crowd, 2, 120)
	assert(absf(crowd.wear_at(Vector3.ZERO) - first * 2.0) < 0.00001)
	crowd.forget_unit(1)
	assert(not crowd.distance_carry.has(1))
	var ocean := field(104.0, true)
	traverse(ocean, 1, 120)
	assert(ocean.wear_at(Vector3.ZERO) == 0)
	assert(not ocean.dirty)
	traverse(ocean, 1, 120)
	ocean.flush_texture()
	assert(ocean.upload_count == 0)
	wear.flush_texture()
	var uploads: int = wear.upload_count
	for tick in 60: wear._process(1.0 / 60.0)
	assert(wear.upload_count == uploads, "Idle field uploads every frame")
	var texture_before = wear.texture
	traverse(wear, 3, 120)
	wear.flush_texture()
	assert(wear.texture == texture_before, "Reallocated texture during painting")
	var bounded := field()
	bounded.record_movement(9, Vector3(51.5,0,0), Vector3(51.95,0,0))
	bounded.process_pending(256)
	assert(bounded.wear_at(Vector3(51.9,0,0)) > 0.0)
	assert(bounded.wear_at(Vector3(-51.9,0,0)) == 0.0, "Brush wrapped across map")
	for id in 500:
		bounded.record_movement(id, Vector3(-1.8,0,0), Vector3(1.8,0,0))
	assert(bounded.pending.size() - bounded.read_index <= WEAR.MAX_PENDING)
	assert(bounded.dropped_samples > 0)
	var applied: int = bounded.applied_samples
	bounded.process_pending(WEAR.STAMPS_PER_FRAME)
	assert(bounded.applied_samples - applied == WEAR.STAMPS_PER_FRAME)
	# 1000 independent moving agents, without their unrelated rendering/AI.
	var load_test := field()
	var costs: Array[float] = []
	for frame in 180:
		var begin := Time.get_ticks_usec()
		for id in 1000:
			var start := Vector3(-45 + (id % 32) * 2.5, 0, -45 + (id / 32) * 2.5 + frame * 0.0375)
			load_test.record_movement(id, start, start + Vector3(0,0,0.0375))
		load_test._process(1.0 / 60.0)
		costs.append((Time.get_ticks_usec() - begin) / 1000.0)
	assert(load_test.dropped_samples == 0)
	assert(load_test.upload_count <= 30)
	assert(load_test.pending.size() - load_test.read_index < 1000)
	costs.sort()
	print("TRAIL PASS: movement-only, teleport rejection, saturation, FPS-independent, additive units, no water, no idle uploads")
	print("TRAIL LOAD: 1000 moving-agent reports at 60 Hz for 3 simulated seconds; CPU median ms=", costs[90],
		" p95=", costs[171], "; applied=", load_test.applied_samples, "; uploads=", load_test.upload_count,
		"; mask bytes=", load_test.image.get_data_size())
	var cells := PackedByteArray()
	cells.resize(104 * 104)
	cells.fill(0)
	wear.configure(104, cells, 104)
	assert(wear.wear_at(Vector3.ZERO) == 0.0 and wear.distance_carry.is_empty())
	for item in [wear, coarse, fine, crowd, ocean, bounded, load_test]: item.free()
	quit()
