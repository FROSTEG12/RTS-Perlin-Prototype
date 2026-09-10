extends RefCounted
## R = current sight, G = explored history. Independent of rendering/weather.
const RESOLUTION := 256
var extent := 52.0
var resolution := RESOLUTION
var current := PackedByteArray()
var explored := PackedByteArray()
var image: Image
var texture: ImageTexture
var revision := 0

func configure(half_extent: float, pixels: int = RESOLUTION) -> void:
	extent = half_extent
	resolution = pixels
	current.resize(pixels * pixels)
	explored.resize(pixels * pixels)
	current.fill(0)
	explored.fill(0)
	image = Image.create(pixels, pixels, false, Image.FORMAT_RG8)
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)
	revision += 1

func update(sources: Array) -> void:
	current.fill(0)
	var pixel := extent * 2.0 / resolution
	for source in sources:
		var center := Vector2(source.position.x, source.position.z)
		var radius: float = source.get("radius", 12.0)
		var feather: float = source.get("feather", 4.0)
		if not center.is_finite() or radius <= 0: continue
		var outer := radius + maxf(feather, 0.01)
		var low := ((center - Vector2.ONE * outer + Vector2.ONE * extent) / pixel).floor()
		var high := ((center + Vector2.ONE * outer + Vector2.ONE * extent) / pixel).ceil()
		for y in range(maxi(0, int(low.y)), mini(resolution, int(high.y))):
			for x in range(maxi(0, int(low.x)), mini(resolution, int(high.x))):
				var point := Vector2(x + 0.5, y + 0.5) * pixel - Vector2.ONE * extent
				var value := roundi((1.0 - smoothstep(radius, outer, point.distance_to(center))) * 255.0)
				var index := y * resolution + x
				current[index] = maxi(current[index], value)
	var data := PackedByteArray()
	data.resize(resolution * resolution * 2)
	for i in current.size():
		explored[i] = maxi(explored[i], current[i])
		data[i*2] = current[i]
		data[i*2+1] = explored[i]
	image.set_data(resolution, resolution, false, Image.FORMAT_RG8, data)
	texture.update(image)
	revision += 1

func sample(point: Vector3, history: bool = false) -> float:
	if not point.is_finite() or absf(point.x) >= extent or absf(point.z) >= extent: return 0.0
	var cell := Vector2i((Vector2(point.x, point.z) + Vector2.ONE * extent) * resolution / (extent * 2))
	var index := cell.y * resolution + cell.x
	return float(explored[index] if history else current[index]) / 255.0

func is_visible(point: Vector3) -> bool: return sample(point) >= 0.6
func is_explored(point: Vector3) -> bool: return sample(point, true) >= 0.6
