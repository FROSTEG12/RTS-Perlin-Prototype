extends SceneTree
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.game_camera.set_process(false)
	world.vision.set_process(false)
	for unit in world.player_units: unit.set_process(false)
	var vision = world.vision
	var minimap = world.hud.minimap
	var toggle = world.developer_tools.fog_of_war_toggle
	var history: PackedByteArray = vision.state.explored.duplicate()
	var current: PackedByteArray = vision.state.current.duplicate()
	var away := Vector3(40,0,40)
	if vision.state.is_explored(away): away = Vector3(-40,0,-40)
	var enemy := MeshInstance3D.new()
	enemy.mesh = BoxMesh.new()
	world.add_child(enemy)
	enemy.position = away
	enemy.add_to_group("vision_dynamic")
	var building := MeshInstance3D.new()
	building.mesh = BoxMesh.new()
	world.add_child(building)
	building.position = away
	building.add_to_group("vision_static")
	minimap.set_landmark(876,away,"building",1,[])
	vision.objects.refresh()
	assert(toggle.button_pressed and vision.overlay.visible)
	assert(not enemy.visible and not building.visible and minimap.visible_landmarks().is_empty())
	world.developer_tools.set_open(true)
	toggle.button_pressed = false
	assert(not vision.enabled and not vision.overlay.visible)
	assert(not minimap.terrain_material.get_shader_parameter("visibility_enabled"))
	assert(enemy.visible and building.visible and vision.can_observe(enemy))
	assert(minimap.is_contact_visible(1,[],away) and minimap.visible_landmarks().size() == 1)
	assert(vision.state.explored == history and vision.state.current == current)
	assert(minimap.landmarks[876].remembered.is_empty())
	assert(vision.objects.records[building.get_instance_id()].snapshot == null)
	# Binding/rebuilding minimap must respect the disabled state too.
	minimap.bind_visibility()
	assert(not minimap.terrain_material.get_shader_parameter("visibility_enabled"))
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"fog-toggle-f1.png")
	toggle.button_pressed = true
	assert(vision.enabled and vision.overlay.visible)
	assert(minimap.terrain_material.get_shader_parameter("visibility_enabled"))
	assert(not enemy.visible and not building.visible and not vision.can_observe(enemy))
	assert(not minimap.is_contact_visible(1,[],away) and minimap.visible_landmarks().is_empty())
	assert(vision.state.explored == history and vision.state.current == current)
	vision.set_enabled(false)
	assert(not toggle.button_pressed)
	vision.reset_world()
	assert(not vision.overlay.visible and not toggle.button_pressed)
	vision.set_enabled(true)
	assert(toggle.button_pressed and vision.overlay.visible)
	print("FOG_TOGGLE_PASS F1 world minimap objects no_memory_leak restore reset")
	quit()
