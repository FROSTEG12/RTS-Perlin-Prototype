extends RefCounted
## Logical sight/history and two GPU masks; visual interpolation never grants sight.
const RESOLUTION := 256
const TRANSITION := 0.1
var extent := 52.0
var current := PackedByteArray()
var explored := PackedByteArray()
var image: Image
var previous_image: Image
var texture: ImageTexture
var previous: ImageTexture
var blend := 1.0
var revision := 0

func configure(half_extent: float) -> void:
	extent = half_extent
	current.resize(RESOLUTION * RESOLUTION)
	explored.resize(current.size())
	current.fill(0)
	explored.fill(0)
	image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RG8)
	image.fill(Color.BLACK)
	previous_image = image.duplicate()
	texture = ImageTexture.create_from_image(image)
	previous = ImageTexture.create_from_image(image)
	blend = 1.0
	revision += 1

func advance(delta: float) -> void:
	blend = minf(1.0, blend + delta / TRANSITION)

func update(sources: Array, immediate: bool = false) -> void:
	previous_image = image.duplicate()
	previous.update(previous_image)
	current.fill(0)
	var pixel := extent * 2.0 / RESOLUTION
	for source in sources:
		var center := Vector2(source.position.x, source.position.z)
		var radius: float = source.get("radius", 12.0)
		var outer: float = radius + source.get("feather", 3.0)
		if not center.is_finite() or radius <= 0: continue
		var low := ((center - Vector2.ONE * outer + Vector2.ONE * extent) / pixel).floor()
		var high := ((center + Vector2.ONE * outer + Vector2.ONE * extent) / pixel).ceil()
		for y in range(maxi(0,int(low.y)), mini(RESOLUTION,int(high.y))):
			for x in range(maxi(0,int(low.x)), mini(RESOLUTION,int(high.x))):
				var point := Vector2(x+0.5,y+0.5) * pixel - Vector2.ONE * extent
				var value := roundi((1.0-smoothstep(radius,outer,point.distance_to(center))) * 255)
				var index := y * RESOLUTION + x
				current[index] = maxi(current[index],value)
	var data := PackedByteArray()
	data.resize(current.size()*2)
	for i in current.size():
		explored[i] = maxi(explored[i],current[i])
		data[i*2] = current[i]
		data[i*2+1] = explored[i]
	image.set_data(RESOLUTION,RESOLUTION,false,Image.FORMAT_RG8,data)
	texture.update(image)
	blend = 0.0
	if immediate:
		previous_image = image.duplicate()
		previous.update(image)
		blend = 1.0
	revision += 1

func sample(point: Vector3, history: bool = false) -> float:
	if not point.is_finite() or absf(point.x) >= extent or absf(point.z) >= extent: return 0.0
	var cell := Vector2i((Vector2(point.x,point.z)+Vector2.ONE*extent)*RESOLUTION/(extent*2))
	var index := cell.y*RESOLUTION+cell.x
	return float(explored[index] if history else current[index])/255.0

func is_visible(point: Vector3) -> bool: return sample(point) >= 0.98
func is_explored(point: Vector3) -> bool: return sample(point,true) >= 0.98
