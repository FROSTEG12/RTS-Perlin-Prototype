extends Node3D
## Temporary ground-only blood. Bounded decal pool; no physics or frame texture uploads.
const CAPACITY := 96
const GROUND_LAYER := 1 << 5
const HOLD_SECONDS := 120.0
const FADE_SECONDS := 30.0
const UPDATE_INTERVAL := 0.1
var world: Node3D
var pool: Array[Decal] = []
var born := PackedFloat32Array()
var variants: Array[Texture2D] = []
var cursor := 0
var clock := 0.0
var update_clock := 0.0
var rng := RandomNumberGenerator.new()
var spawned := 0

func _ready() -> void:
	rng.randomize()
	# Preserve all existing visibility/shadow layers. Only the ground receives blood.
	world.map_renderer.terrain.layers |= GROUND_LAYER
	for index in 6: variants.append(_make_mask(917 + index * 137, index >= 4))
	born.resize(CAPACITY)
	born.fill(-1000.0)
	for index in CAPACITY:
		var decal := Decal.new()
		decal.name = "Blood_%02d" % index
		decal.cull_mask = GROUND_LAYER
		decal.upper_fade = 0.0
		decal.lower_fade = 0.0
		decal.albedo_mix = 0.92
		decal.visible = false
		add_child(decal)
		pool.append(decal)

func _make_mask(seed_value: int, puddle: bool) -> Texture2D:
	# Tiny code-generated pixel clusters, not photoreal photos or large textures.
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var blobs: Array[Vector4] = []
	for index in (7 if puddle else 4):
		blobs.append(Vector4(random.randf_range(-0.18, 0.18), random.randf_range(-0.15, 0.15),
			random.randf_range(0.14, 0.24), random.randf_range(0.09, 0.18)))
	for index in (4 if puddle else 10):
		var radius := random.randf_range(0.016, 0.045)
		blobs.append(Vector4(random.randf_range(-0.42, 0.42), random.randf_range(-0.42, 0.42), radius, radius))
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 24:
		for x in 24:
			var point := (Vector2(x, y) + Vector2(0.5, 0.5)) / 24.0 - Vector2(0.5, 0.5)
			var inside := false
			for blob in blobs:
				if Vector2((point.x - blob.x) / blob.z, (point.y - blob.y) / blob.w).length_squared() < 1.0:
					inside = true
					break
			if not inside: continue
			var color := Color("68171c") if random.randf() > 0.22 else Color("85262a")
			if point.length() < 0.12: color = Color("4d1017")
			image.fill_rect(Rect2i(x * 2, y * 2, 2, 2), color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func spawn_hit(point: Vector3, direction: Vector3) -> bool:
	if not point.is_finite() or not direction.is_finite(): return false
	var away := Vector3(direction.x, 0, direction.z).normalized()
	var center := point + away * rng.randf_range(0.12, 0.3)
	center += Vector3(rng.randf_range(-0.17, 0.17), 0, rng.randf_range(-0.17, 0.17))
	return _stamp(center, rng.randf_range(0.60, 0.85), false)

func spawn_death(point: Vector3) -> bool:
	if not point.is_finite(): return false
	return _stamp(point, rng.randf_range(1.10, 1.4), true)

func _dry_footprint(center: Vector3, width: float, angle: float) -> bool:
	# Sample the full rotated projection box, including a small safety margin.
	# Refuse submerged/edge samples so the continuous terrain seabed cannot receive it.
	var basis := Basis(Vector3.UP, angle)
	var steps := maxi(2, ceili(width / 0.08))
	for y in range(steps + 1):
		for x in range(steps + 1):
			var offset := Vector3(float(x) / steps - 0.5, 0, float(y) / steps - 0.5) * (width + 0.08)
			var point := center + basis * offset
			if not world.map_renderer.is_land(world.map_renderer.world_to_cell(point)): return false
			if world.map_renderer._ground_surface_y(point.x, point.z) < MapRenderer3D.WATER_Y + 0.055: return false
	return true

func _stamp(center: Vector3, width: float, puddle: bool) -> bool:
	var angle := rng.randf_range(0.0, TAU)
	var fits := false
	for attempt in 3:
		if _dry_footprint(center, width, angle):
			fits = true
			break
		width *= 0.72
	if not fits: return false
	var decal := pool[cursor]
	decal.texture_albedo = variants[rng.randi_range(4, 5) if puddle else rng.randi_range(0, 3)]
	decal.size = Vector3(width, 0.24, width)
	decal.rotation.y = angle
	decal.global_position = Vector3(center.x, world.map_renderer._ground_surface_y(center.x, center.z) + 0.035, center.z)
	decal.modulate = Color.WHITE
	decal.visible = true
	born[cursor] = clock
	cursor = (cursor + 1) % CAPACITY
	spawned += 1
	return true

func clear() -> void:
	for decal in pool: decal.visible = false
	born.fill(-1000.0)
	cursor = 0
	spawned = 0

func active_count() -> int:
	var count := 0
	for decal in pool:
		if decal.visible: count += 1
	return count

func _process(delta: float) -> void:
	clock += maxf(delta, 0.0)
	update_clock += maxf(delta, 0.0)
	if update_clock < UPDATE_INTERVAL: return
	update_clock = fmod(update_clock, UPDATE_INTERVAL)
	for index in CAPACITY:
		var decal := pool[index]
		if not decal.visible: continue
		var age := clock - born[index]
		if age >= HOLD_SECONDS + FADE_SECONDS:
			decal.visible = false
			continue
		var tint := Color.WHITE.lerp(Color(0.67, 0.57, 0.55), clampf(age / 45.0, 0.0, 1.0))
		tint.a = 1.0 - smoothstep(HOLD_SECONDS, HOLD_SECONDS + FADE_SECONDS, age)
		decal.modulate = tint
