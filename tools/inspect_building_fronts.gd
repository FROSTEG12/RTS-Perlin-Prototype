extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(600,450)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("#263039")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("#ccd7e0")
	environment.environment.ambient_light_energy=.85
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-35,0)
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	var label := Label.new()
	label.add_theme_font_size_override("font_size",25)
	viewport.add_child(label)
	for id in ["sawmill","gate","square_tower","round_tower","round_tower_alt"]:
		var model := preload("res://scripts/buildings/building_model.gd").create(id)
		viewport.add_child(model)
		var bounds := preload("res://scripts/buildings/building_model.gd").bounds(model)
		camera.size=maxf(bounds.size.y*1.3,6)
		var target:=Vector3(0,bounds.size.y*.5,0)
		var sheet := Image.create(1200,900,false,Image.FORMAT_RGBA8)
		var directions := [Vector3(0,2,15),Vector3(0,2,-15),Vector3(15,2,0),Vector3(-15,2,0)]
		for i in 4:
			label.text=id+" "+["+Z","-Z","+X","-X"][i]
			camera.position=target+directions[i]
			camera.look_at(target)
			for frame in 4: await process_frame
			await RenderingServer.frame_post_draw
			var frame_image := viewport.get_texture().get_image()
			frame_image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(frame_image,Rect2i(0,0,600,450),Vector2i((i%2)*600,(i/2)*450))
		sheet.save_png(OUT+"fronts-"+id+".png")
		model.free()
	quit()
