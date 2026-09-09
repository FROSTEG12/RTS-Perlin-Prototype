extends Node3D
## One accumulated terrain field, not overlapping per-hit Decals.
const CAPACITY := 96
const RESOLUTION := 1024
const HOLD_SECONDS := 120.0
const FADE_SECONDS := 30.0
const UPDATE_INTERVAL := 0.1
var world: Node3D
var records: Array[Dictionary] = []
var image: Image
var texture: ImageTexture
var merged := {}
var dry_pixels := {}
var clock := 0.0
var update_clock := 0.0
var dirty := false
var rng := RandomNumberGenerator.new()
var spawned := 0
var upload_count := 0
var age_bucket := -1
var world_size := 104.0

func _ready() -> void:
	rng.randomize()
	image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RG8)
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)

func _bind() -> void:
	world_size = world.map_renderer.map_size * MapRenderer3D.CELL_SIZE
	var material: ShaderMaterial = world.map_renderer.terrain_material
	if material != null:
		material.set_shader_parameter("blood_field_texture", texture)
		material.set_shader_parameter("blood_enabled", not records.is_empty())

func spawn_hit(point: Vector3, direction: Vector3) -> bool:
	if not point.is_finite() or not direction.is_finite(): return false
	if not _dry_footprint(point, 0.08, 0): return false
	var pixels := {}
	var heading := atan2(direction.z, direction.x) + rng.randf_range(-1.1, 1.1)
	var axis := Vector3(cos(heading), 0, sin(heading))
	var center := point + axis * rng.randf_range(0.12, 0.48)
	# Broad smooth contributions merge before the shader's fixed noise threshold.
	for index in 3:
		var offset := Vector3(rng.randf_range(-0.24, 0.24), 0, rng.randf_range(-0.24, 0.24))
		_paint_blob(pixels, center + offset, rng.randf_range(0.28, 0.42), 0.40)
	for index in 8:
		var angle := heading + rng.randf_range(-2.2, 2.2)
		var offset := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.4, 1.15)
		_paint_blob(pixels, point + offset, rng.randf_range(0.075, 0.12), 0.85)
	return _record(pixels)

func spawn_death(point: Vector3) -> bool:
	if not point.is_finite() or not _dry_footprint(point, 0.08, 0): return false
	var pixels := {}
	for index in 5:
		var offset := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		_paint_blob(pixels, point + offset, rng.randf_range(0.38, 0.55), 0.60)
	return _record(pixels)

func _dry_footprint(center: Vector3, width: float, angle: float) -> bool:
	var basis := Basis(Vector3.UP, angle)
	var steps := maxi(2, ceili(width / 0.08))
	for y in range(steps + 1):
		for x in range(steps + 1):
			var offset := Vector3(float(x) / steps - 0.5, 0, float(y) / steps - 0.5) * (width + 0.08)
			var point := center + basis * offset
			if not world.map_renderer.is_land(world.map_renderer.world_to_cell(point)): return false
			if world.map_renderer._ground_surface_y(point.x, point.z) < MapRenderer3D.WATER_Y + 0.055: return false
	return true

func _paint_blob(pixels: Dictionary, point: Vector3, radius: float, strength: float) -> void:
	var pixel_size := world_size / RESOLUTION
	var first := Vector2i((Vector2(point.x - radius, point.z - radius) / pixel_size + Vector2.ONE * RESOLUTION * 0.5).floor())
	var last := Vector2i((Vector2(point.x + radius, point.z + radius) / pixel_size + Vector2.ONE * RESOLUTION * 0.5).floor())
	for y in range(maxi(0, first.y), mini(RESOLUTION - 1, last.y) + 1):
		for x in range(maxi(0, first.x), mini(RESOLUTION - 1, last.x) + 1):
			var p := Vector3((x + 0.5 - RESOLUTION * 0.5) * pixel_size, 0, (y + 0.5 - RESOLUTION * 0.5) * pixel_size)
			var distance := Vector2(p.x - point.x, p.z - point.z).length() / radius
			if distance >= 1.0: continue
			# Protect the full texel + interpolation margin at shore and map edges.
			var cell := Vector2i(x, y)
			if not dry_pixels.has(cell):
				if dry_pixels.size() >= 65536: dry_pixels.clear()
				dry_pixels[cell] = _dry_footprint(p, pixel_size * 2.0, 0)
			if not dry_pixels[cell]: continue
			var weight := strength * (1.0 - smoothstep(0.05, 1.0, distance))
			pixels[cell] = minf(1.0, pixels.get(cell, 0.0) + weight)

func _record(pixels: Dictionary) -> bool:
	if pixels.is_empty(): return false
	records.append({"pixels": pixels, "born": clock})
	if records.size() > CAPACITY: records.pop_front()
	spawned += 1
	dirty = true
	return true

func flush() -> void:
	if not dirty: return
	merged.clear()
	# Add amounts, then clamp once. No per-stamp color/alpha edges survive.
	# G carries pigment-weighted freshness, so dying records cannot cut holes.
	for record in records:
		var age: float = maxf(0, clock - record.born)
		var fade := 1.0 - smoothstep(HOLD_SECONDS, HOLD_SECONDS + FADE_SECONDS, age)
		var freshness := 1.0 - clampf(age / 45.0, 0, 1)
		for pixel: Vector2i in record.pixels:
			var amount: float = record.pixels[pixel] * fade
			var values: Vector2 = merged.get(pixel, Vector2.ZERO)
			merged[pixel] = values + Vector2(amount, amount * freshness)
	image.fill(Color.BLACK)
	for pixel: Vector2i in merged:
		var values: Vector2 = merged[pixel]
		image.set_pixel(pixel.x, pixel.y, Color(minf(values.x, 1.0), values.y / maxf(values.x, 0.00001), 0))
	texture.update(image)
	upload_count += 1
	_bind()
	dirty = false

func clear() -> void:
	records.clear()
	merged.clear()
	dry_pixels.clear()
	image.fill(Color.BLACK)
	texture.update(image)
	spawned = 0
	dirty = false
	_bind() # Terrain material is recreated when generating a new map.

func active_count() -> int:
	return records.size()

func _process(delta: float) -> void:
	clock += maxf(delta, 0)
	update_clock += maxf(delta, 0)
	var bucket := floori(clock * 2.0)
	if bucket != age_bucket:
		age_bucket = bucket
		for index in range(records.size() - 1, -1, -1):
			var age: float = clock - records[index].born
			if age < 46.0 or age > HOLD_SECONDS: dirty = true
			if age >= HOLD_SECONDS + FADE_SECONDS:
				records.remove_at(index)
				dirty = true
	if update_clock < UPDATE_INTERVAL: return
	update_clock = fmod(update_clock, UPDATE_INTERVAL)
	flush()
