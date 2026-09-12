extends SceneTree
const M = preload("res://scripts/buildings/building_model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.placement.set_process(false)
	for id in [&"sawmill",&"house"]:
		world.placement.begin(id)
		var origin := Vector2i(-1,-1)
		for y in range(10,90,3):
			for x in range(10,90,3):
				if world.placement.validate(Vector2i(x,y)).is_empty(): origin=Vector2i(x,y); break
			if origin.x>=0: break
		assert(origin.x>=0)
		world.placement.origin_cell=origin
		world.placement.refresh_preview()
		assert(M.meshes(world.placement.preview_model).filter(func(m): return m.visible).size()==1)
		assert(world.placement.commit())
		var site = world.placement.sites.back()
		var box := M.bounds(site.model_anchor)
		print(id," BOUNDS ",box)
		assert(box.size.x<=site.footprint.x and box.size.z<=site.footprint.y)
		var poses := []
		for mesh in M.meshes(site.model_anchor): poses.append(mesh.global_transform)
		assert(poses.size()==5)
		for step in range(1,6):
			site.set_construction_stage(step)
			var visible_meshes := M.meshes(site.model_anchor).filter(func(m): return m.visible)
			assert(visible_meshes.size()==1)
			assert(str(visible_meshes[0].name).begins_with("Stage_%02d_"%step))
			var index := 0
			for mesh in M.meshes(site.model_anchor):
				assert(mesh.global_transform==poses[index])
				index+=1
		assert(site.stage==&"completed")
		if DisplayServer.get_name()!="headless":
			world.game_camera.focus_on(site.position)
			world.game_camera.set_process(false)
			for frame in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/new-"+str(id)+".png")
	print("CONSTRUCTION_MODELS_PASS placement footprints five_stages stable_transforms complete_default")
	world.queue_free()
	await process_frame
	quit()
