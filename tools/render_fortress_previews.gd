extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/ui/buildings/modules")
	var viewport := SubViewport.new()
	viewport.size=Vector2i(384,510)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("#172832")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("#c5dbea")
	environment.environment.ambient_light_energy=.65
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-35,0)
	light.light_energy=1.6
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	for id in ["wall","gate","round_tower","round_tower_alt","square_tower"]:
		var model = preload("res://scripts/buildings/building_model.gd").create(id)
		viewport.add_child(model)
		var bounds: AABB = preload("res://scripts/buildings/building_model.gd").bounds(model)
		var center := bounds.get_center()
		camera.position=center+Vector3(10,7,16)
		camera.look_at(center)
		camera.size=maxf(bounds.size.x*1.5,bounds.size.y*1.35)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://assets/ui/buildings/modules/"+id+".png")==OK)
		model.free()
	quit()
