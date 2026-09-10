extends SubViewport
## One shared portrait rendered from our knight, not ten live 3D previews.
func _ready() -> void:
	size = Vector2i(192, 192)
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var model: Node3D = preload("res://assets/units/low_poly_knight/blue.scn").instantiate()
	model.scale = Vector3.ONE * 0.55
	add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name.begins_with("Sword") or mesh.name.begins_with("Shield"):
			mesh.visible = false
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null:
		player.play("idle")
		player.advance(0)
		player.pause()
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.43
	camera.position = Vector3(0.05, 1.15, 2.4)
	camera.look_at(Vector3(-0.09, 1.07, 0.08))
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.5
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#c6d5ed")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	for frame in 3: await get_tree().process_frame
	render_target_update_mode = SubViewport.UPDATE_ONCE
