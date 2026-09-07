extends MeshInstance3D
## One optional draw, one R8 mask. Reads the SAME AStar solids as movement.
var world: Node3D
var mask: ImageTexture

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * world.DEFAULT_MAP_SIZE
	mesh = plane
	position.y = 0.045
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/walkability_grid.gdshader")
	material.set_shader_parameter("map_size", float(world.DEFAULT_MAP_SIZE))
	material_override = material

func refresh() -> void:
	var size: int = world.DEFAULT_MAP_SIZE
	var bytes := PackedByteArray()
	bytes.resize(size * size)
	for y in size:
		for x in size:
			bytes[y * size + x] = 255 if world.pathfinder.astar_grid.is_point_solid(Vector2i(x, y)) else 0
	var image := Image.create_from_data(size, size, false, Image.FORMAT_R8, bytes)
	if mask == null:
		mask = ImageTexture.create_from_image(image)
	else:
		mask.update(image)
	(material_override as ShaderMaterial).set_shader_parameter("walkability", mask)
