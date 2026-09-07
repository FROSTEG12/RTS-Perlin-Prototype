class_name TrailWear
extends Node
## Shared world-space traffic field. All walkers report actual movement here;
## the renderer samples one R8 texture, regardless of the number of units.
const RESOLUTION := 512
const SAMPLE_DISTANCE := 0.18
const BRUSH_RADIUS := 0.34
const WEAR_PER_SAMPLE := 0.045
const MAX_SEGMENT := 4.0 # Teleports/spawn jumps are not walked routes.
const STAMPS_PER_FRAME := 256
const MAX_PENDING := 8192
const UPLOAD_INTERVAL := 0.1

var world_size := 104.0
var field := PackedFloat32Array()
var image: Image
var texture: ImageTexture
var land_cells := PackedByteArray()
var cell_count := 0
var distance_carry: Dictionary = {}
var pending := PackedVector4Array()
var read_index := 0
var dirty := false
var upload_clock := 0.0
var upload_count := 0
var dropped_samples := 0
var applied_samples := 0

func configure(size: float, cells: PackedByteArray, map_cells: int) -> void:
	world_size = size
	land_cells = cells.duplicate()
	cell_count = map_cells
	field.resize(RESOLUTION * RESOLUTION)
	field.fill(0.0)
	image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)
	distance_carry.clear()
	pending.clear()
	read_index = 0
	dirty = false
	upload_clock = 0.0
	upload_count = 0
	dropped_samples = 0
	applied_samples = 0

func forget_unit(unit_id: int) -> void:
	distance_carry.erase(unit_id)

func record_movement(unit_id: int, from: Vector3, to: Vector3, weight: float = 1.0) -> void:
	if image == null or not from.is_finite() or not to.is_finite() or not is_finite(weight):
		return
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var distance := a.distance_to(b)
	if distance > MAX_SEGMENT:
		forget_unit(unit_id)
		return
	if distance < 0.000001 or weight <= 0.0:
		return
	var carry: float = distance_carry.get(unit_id, 0.0)
	var cursor := SAMPLE_DISTANCE - carry
	while cursor <= distance + 0.000001:
		var point := a.lerp(b, clampf(cursor / distance, 0.0, 1.0))
		if pending.size() - read_index < MAX_PENDING:
			pending.append(Vector4(point.x, point.y, BRUSH_RADIUS, WEAR_PER_SAMPLE * minf(weight, 4.0)))
		else:
			dropped_samples += 1
		cursor += SAMPLE_DISTANCE
	distance_carry[unit_id] = clampf(distance - (cursor - SAMPLE_DISTANCE), 0.0, SAMPLE_DISTANCE - 0.000001)

func _process(delta: float) -> void:
	process_pending(STAMPS_PER_FRAME)
	upload_clock += maxf(delta, 0.0)
	if upload_clock >= UPLOAD_INTERVAL:
		upload_clock = fmod(upload_clock, UPLOAD_INTERVAL)
		flush_texture()

func process_pending(budget: int = STAMPS_PER_FRAME) -> void:
	var finish := mini(pending.size(), read_index + maxi(0, budget))
	while read_index < finish:
		_stamp(pending[read_index])
		read_index += 1
	if read_index == pending.size():
		pending.clear()
		read_index = 0
	elif read_index >= MAX_PENDING:
		pending = pending.slice(read_index)
		read_index = 0

func flush_texture() -> void:
	if dirty:
		# Reuse the GPU allocation, no new ImageTexture and no GPU readback.
		texture.update(image)
		upload_count += 1
		dirty = false

func _stamp(sample: Vector4) -> void:
	var pixel_size := world_size / RESOLUTION
	var center := Vector2(sample.x, sample.y)
	var radius := sample.z
	var minimum := ((center - Vector2.ONE * radius) / pixel_size + Vector2.ONE * RESOLUTION * 0.5).floor()
	var maximum := ((center + Vector2.ONE * radius) / pixel_size + Vector2.ONE * RESOLUTION * 0.5).floor()
	for y in range(maxi(0, int(minimum.y)), mini(RESOLUTION - 1, int(maximum.y)) + 1):
		for x in range(maxi(0, int(minimum.x)), mini(RESOLUTION - 1, int(maximum.x)) + 1):
			var cell_x := mini(cell_count - 1, x * cell_count / RESOLUTION)
			var cell_y := mini(cell_count - 1, y * cell_count / RESOLUTION)
			if cell_count <= 0 or land_cells[cell_y * cell_count + cell_x] != 0:
				continue
			var index := y * RESOLUTION + x
			var previous := field[index]
			if previous >= 1.0: continue
			var position := (Vector2(x + 0.5, y + 0.5) - Vector2.ONE * RESOLUTION * 0.5) * pixel_size
			var radial := center.distance_to(position) / radius
			if radial >= 1.0: continue
			# Flat center and softer shoulders; ~15-25 repeat passes to bare dirt.
			var falloff := 1.0 - smoothstep(0.35, 1.0, radial)
			var value := minf(1.0, previous + sample.w * falloff)
			field[index] = value
			if roundi(previous * 255.0) != roundi(value * 255.0):
				image.set_pixel(x, y, Color(value, 0, 0))
				dirty = true
	applied_samples += 1

func wear_at(position: Vector3) -> float:
	var uv := Vector2(position.x, position.z) / world_size + Vector2.ONE * 0.5
	if image == null or uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1:
		return 0.0
	return field[int(uv.y * RESOLUTION) * RESOLUTION + int(uv.x * RESOLUTION)]
