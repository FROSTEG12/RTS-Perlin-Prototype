extends Node3D
## Server-confirmed route, rendered independently from the local movement executor.
var route: Array = []
var dots := MultiMeshInstance3D.new()
var elapsed := 0.0
var renderer: Node3D

func _ready() -> void:
	add_child(dots)
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.73, 0.08, 0.92)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	dots.multimesh = MultiMesh.new()
	dots.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	dots.multimesh.mesh = mesh
	dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_route(value: Array) -> void:
	if route != value:
		route = value.duplicate()
		_rebuild()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.05 and not route.is_empty():
		elapsed = 0.0
		_rebuild()

func _rebuild() -> void:
	if not is_node_ready():
		return
	var points: Array[Vector3] = []
	var start := Vector3.ZERO
	for cell in route:
		var target: Vector3 = renderer.cell_to_world(cell.x, cell.y) - global_position
		var distance := start.distance_to(target)
		var cursor := 0.20
		while cursor < distance:
			var point := start.move_toward(target, cursor)
			point.y = 0.035
			points.append(point)
			cursor += 0.28
		start = target
	dots.multimesh.instance_count = points.size()
	for i in points.size():
		dots.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
