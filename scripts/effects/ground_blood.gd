extends Node3D
## One accumulated terrain field, not overlapping per-hit Decals.
const CAPACITY := 96
const RESOLUTION := 1024
const HOLD_SECONDS := 120.0
const FADE_SECONDS := 30.0
const UPDATE_INTERVAL := 0.1
const PAINT_BUDGET_US := 1500
const MAX_PENDING := 512
var world: Node3D
var records: Array[Dictionary] = []
var image: Image
var texture: ImageTexture
var merged := {}
var dry_pixels := PackedByteArray() # 0 unknown, 1 wet, 2 dry; 1 MiB, no cache churn.
var pending: Array[Dictionary] = []
var interior := PackedByteArray()
var coalesced := 0
var rejected := 0
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
	dry_pixels.resize(RESOLUTION * RESOLUTION)
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
	var blobs: Array[Dictionary] = []
	var heading := atan2(direction.z, direction.x) + rng.randf_range(-1.1, 1.1)
	var axis := Vector3(cos(heading), 0, sin(heading))
	var center := point + axis * rng.randf_range(0.12, 0.48)
	# Broad smooth contributions merge before the shader's fixed noise threshold.
	for index in 3:
		var offset := Vector3(rng.randf_range(-0.24, 0.24), 0, rng.randf_range(-0.24, 0.24))
		blobs.append(_blob(center + offset, rng.randf_range(0.28, 0.42), 0.40))
	for index in 8:
		var angle := heading + rng.randf_range(-2.2, 2.2)
		var offset := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.4, 1.15)
		blobs.append(_blob(point + offset, rng.randf_range(0.075, 0.12), 0.85))
	return _enqueue(point, blobs, false)

func spawn_death(point: Vector3) -> bool:
	if not point.is_finite() or not _dry_footprint(point, 0.08, 0): return false
	var blobs: Array[Dictionary] = []
	for index in 5:
		var offset := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		blobs.append(_blob(point + offset, rng.randf_range(0.38, 0.55), 0.60))
	return _enqueue(point, blobs, true)

func _enqueue(point: Vector3, blobs: Array[Dictionary], death: bool) -> bool:
	var cell: Vector2i = world.map_renderer.world_to_cell(point)
	# Cosmetic overload only: nearby pending hits share a stamp, never damage.
	if pending.size() > 48 and not death:
		for index in range(pending.size() - 1, -1, -1):
			var job := pending[index]
			if job.cell == cell and not job.death:
				job.strength = minf(1.5, job.strength + 0.1)
				coalesced += 1
				spawned += 1
				return true
	if pending.size() >= MAX_PENDING:
		rejected += 1
		return false
	pending.append({"cell": cell, "death": death, "blobs": blobs, "pixels": {}, "born": clock, "strength": 1.0})
	spawned += 1
	return true

func _blob(point: Vector3, radius: float, strength: float) -> Dictionary:
	var pixel_size := world_size / RESOLUTION
	var first := Vector2i((Vector2(point.x-radius, point.z-radius) / pixel_size + Vector2.ONE * RESOLUTION * 0.5).floor()).max(Vector2i.ZERO)
	var last := Vector2i((Vector2(point.x+radius, point.z+radius) / pixel_size + Vector2.ONE * RESOLUTION * 0.5).floor()).min(Vector2i.ONE * (RESOLUTION-1))
	if first.x > last.x: last.y = -1
	return {"point": point, "radius": radius, "strength": strength, "first": first, "last": last, "x": first.x, "y": first.y}

func _drain(budget_us: int = 0) -> void:
	var started := Time.get_ticks_usec()
	var visited := 0
	var pixel_size := world_size / RESOLUTION
	while not pending.is_empty():
		var job := pending[0]
		if job.blobs.is_empty():
			_record(job.pixels, job.born)
			pending.pop_front()
			continue
		var blob: Dictionary = job.blobs[0]
		if blob.y > blob.last.y:
			job.blobs.pop_front()
			continue
		var cell := Vector2i(blob.x, blob.y)
		blob.x += 1
		if blob.x > blob.last.x:
			blob.x = blob.first.x
			blob.y += 1
		var p := Vector3((cell.x + 0.5 - RESOLUTION * 0.5) * pixel_size, 0, (cell.y + 0.5 - RESOLUTION * 0.5) * pixel_size)
		var distance := Vector2(p.x-blob.point.x, p.z-blob.point.z).length() / float(blob.radius)
		if distance < 1.0:
			var index := cell.y * RESOLUTION + cell.x
			if dry_pixels[index] == 0:
				dry_pixels[index] = 2 if _dry_footprint(p, pixel_size * 2, 0) else 1
			if dry_pixels[index] == 2:
				var weight: float = blob.strength * job.strength * (1.0 - smoothstep(0.05, 1.0, distance))
				job.pixels[cell] = minf(1.0, job.pixels.get(cell, 0.0) + weight)
		visited += 1
		if budget_us > 0 and visited % 8 == 0 and Time.get_ticks_usec() - started >= budget_us: return

func _dry_footprint(center: Vector3, width: float, angle: float) -> bool:
	var renderer: MapRenderer3D = world.map_renderer
	var cell := renderer.world_to_cell(center)
	# For a <=0.4 footprint, the warped 4x4 B-spline support lies entirely
	# inside this conservative 7x7 dry neighborhood: density is exactly 1.
	# Shore/edge cells ALWAYS retain the original detailed height checks.
	if width <= 0.4 and angle == 0 and cell.x >= 0 and cell.y >= 0 and cell.x < renderer.map_size and cell.y < renderer.map_size:
		var index := cell.y * renderer.map_size + cell.x
		if index < interior.size() and interior[index] == 1: return true
	var basis := Basis(Vector3.UP, angle)
	var steps := maxi(2, ceili(width / 0.08))
	for y in range(steps + 1):
		for x in range(steps + 1):
			var offset := Vector3(float(x) / steps - 0.5, 0, float(y) / steps - 0.5) * (width + 0.08)
			var point := center + basis * offset
			if not world.map_renderer.is_land(world.map_renderer.world_to_cell(point)): return false
			if world.map_renderer._ground_surface_y(point.x, point.z) < MapRenderer3D.WATER_Y + 0.055: return false
	return true

func _record(pixels: Dictionary, born: float) -> bool:
	if pixels.is_empty(): return false
	records.append({"pixels": pixels, "born": born})
	if records.size() > CAPACITY: records.pop_front()
	dirty = true
	return true

func flush(finish_pending: bool = true) -> void:
	# Explicit flush is for tests/capture. Runtime must use the budgeted path.
	if finish_pending: _drain()
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
	dry_pixels.fill(0)
	pending.clear()
	coalesced = 0
	rejected = 0
	_build_interior_cache()
	image.fill(Color.BLACK)
	texture.update(image)
	spawned = 0
	dirty = false
	_bind() # Terrain material is recreated when generating a new map.

func _build_interior_cache() -> void:
	var renderer: MapRenderer3D = world.map_renderer
	interior.resize(renderer.map_size * renderer.map_size)
	interior.fill(0)
	for y in range(3, renderer.map_size - 3):
		for x in range(3, renderer.map_size - 3):
			var safe := true
			for oy in range(-3, 4):
				for ox in range(-3, 4):
					if not renderer.is_land(Vector2i(x+ox, y+oy)):
						safe = false
						break
				if not safe: break
			if safe: interior[y * renderer.map_size + x] = 1

func active_count() -> int:
	return records.size()

func _process(delta: float) -> void:
	clock += maxf(delta, 0)
	update_clock += maxf(delta, 0)
	_drain(PAINT_BUDGET_US)
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
	flush(false)
