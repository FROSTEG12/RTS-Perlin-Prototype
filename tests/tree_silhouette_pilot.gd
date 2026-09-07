extends SceneTree
const TREES = preload("res://scripts/tree_resources.gd")
const CYCLE = preload("res://scripts/day_night_lighting.gd")
const OUT := "C:/Users/FROSTEG/Documents/Codex/2026-09-06/new-chat/work/"
var scene := Node3D.new()
var camera := Camera3D.new()
var light := DirectionalLight3D.new()
var environment := Environment.new()
var visible_tree := MultiMeshInstance3D.new()
var silhouette := MultiMeshInstance3D.new()
var volume := MeshInstance3D.new()
var shadow_material := ShaderMaterial.new()
var visible_material := ShaderMaterial.new()
var time_slider := HSlider.new()
var status := Label.new()
var play := CheckButton.new()
var receive := CheckButton.new()
var mode_picker := OptionButton.new()
var variant_picker := OptionButton.new()
var hour := 7.733333
var variant := 0
var mode := 0
var running := false
var ground_material := StandardMaterial3D.new()

func dark_pixels(base: Image, shaded: Image) -> int:
	var count := 0
	# Exclude the controls, which change with time and comparison mode.
	for y in range(0, base.get_height(), 2):
		for x in range(360, base.get_width(), 2):
			var a := base.get_pixel(x, y)
			var b := shaded.get_pixel(x, y)
			if maxf(a.r - b.r, maxf(a.g - b.g, a.b - b.b)) > 0.01:
				count += 1
	return count

func _initialize() -> void:
	call_deferred("run")

func _process(delta: float) -> bool:
	if running and play.button_pressed:
		set_hour(fposmod(hour + delta / 30.0, 24.0))
	return false

func single_instance(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_custom_data(0, Color(0.23, 1.0, 0, 0))
	return mm

func rebuild_tree() -> void:
	var texture: Texture2D = TREES.TREE_SHEETS[variant]
	var pivot: Vector2 = TREES.ROOT_PIXELS[variant] / (Vector2(texture.get_size()) / 4.0)
	var h: float = TREES.HEIGHTS[variant]
	var quad := QuadMesh.new()
	quad.size = Vector2(h, h)
	quad.center_offset = Vector3((0.5 - pivot.x) * h, (pivot.y - 0.5) * h, 0)
	visible_material.set_shader_parameter("tree_atlas", texture)
	quad.material = visible_material
	visible_tree.multimesh = single_instance(quad)
	visible_tree.multimesh.set_instance_transform(0, Transform3D(camera.global_basis, Vector3(0,.015,0)))
	var upright := QuadMesh.new()
	upright.size = Vector2(h, h / camera.global_basis.y.y)
	upright.center_offset = Vector3((0.5 - pivot.x) * upright.size.x, (pivot.y - 0.5) * upright.size.y, 0)
	shadow_material.set_shader_parameter("tree_atlas", texture)
	upright.material = shadow_material
	silhouette.multimesh = single_instance(upright)
	silhouette.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0,.015,0)))
	volume.mesh = TREES.shadow_mesh(variant, h * pivot.y / camera.global_basis.y.y)
	volume.position.y = .015

func set_hour(value: float) -> void:
	hour = value
	CYCLE.apply(hour, light, environment)
	shadow_material.set_shader_parameter("sun_direction", -light.global_basis.z)
	time_slider.set_value_no_signal(hour)
	status.text = "Время: %02d:%02d" % [floori(hour), floori(fposmod(hour, 1.0) * 60.0 + 0.001)]

func set_mode(value: int) -> void:
	mode = value
	silhouette.visible = mode == 0
	volume.visible = mode == 1

func set_receive(enabled: bool) -> void:
	receive.set_pressed_no_signal(enabled)
	# Isolated comparison: existing baked tree shading remains. With receive
	# off, external objects' shadows also won't shade this test sprite.
	var shader := Shader.new()
	shader.code = TREES.TREE_SHADER.code if enabled else TREES.TREE_SHADER.code.replace("render_mode cull_disabled", "render_mode shadows_disabled, cull_disabled")
	visible_material.shader = shader

func shot(label: String) -> Image:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not label.is_empty(): image.save_png(OUT + "silhouette_" + label + ".png")
	return image

func run() -> void:
	root.add_child(scene)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_title("Тест силуэтной тени — одно дерево")
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.far = 180.0
	camera.position = Vector3(10.5,18,10.5)
	camera.look_at(Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40,40)
	plane.subdivide_width = 31
	plane.subdivide_depth = 31
	ground.mesh = plane
	var material := ground_material
	material.albedo_texture = preload("res://assets/tiles/grass_surface.png")
	material.uv1_scale = Vector3(4,4,1)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = .94
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(ground)
	scene.add_child(light)
	light.shadow_enabled = true
	light.shadow_bias = .025
	light.shadow_normal_bias = .2
	light.shadow_blur = 1.2
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_split_1 = .5
	light.directional_shadow_blend_splits = true
	light.directional_shadow_max_distance = 80.0
	var env := WorldEnvironment.new()
	env.environment = environment
	scene.add_child(env)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	visible_tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	silhouette.extra_cull_margin = 6.0
	volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow_material.shader = preload("res://shaders/tree_shadow_silhouette.gdshader")
	set_receive(true)
	scene.add_child(visible_tree)
	scene.add_child(silhouette)
	scene.add_child(volume)
	build_ui()
	rebuild_tree()
	Engine.time_scale = 0.0
	# Flat receiver isolates actual shadow coverage from the grass pattern.
	ground_material.albedo_texture = null
	ground_material.albedo_color = Color(0.35, 0.35, 0.35)
	visible_tree.visible = false
	set_receive(false)
	var minimum := 1000000
	for tree_variant in 6:
		variant = tree_variant
		rebuild_tree()
		for test_hour in [7.45, 7.666667, 7.733333, 7.833333, 8.0, 12.0, 18.5, 0.0]:
			set_hour(test_hour)
			set_mode(2)
			var baseline := await shot("")
			set_mode(0)
			var shaded := await shot("")
			var pixels := dark_pixels(baseline, shaded)
			minimum = mini(minimum, pixels)
			if pixels <= 30:
				baseline.save_png(OUT + "silhouette_failure_base.png")
				shaded.save_png(OUT + "silhouette_failure_shadow.png")
				print("Direction ", -light.global_basis.z)
				push_error("Silhouette missing: variant %d hour %s pixels %d" % [variant, test_hour, pixels])
				quit(1)
				return
	light.shadow_enabled = false
	set_mode(2)
	var hidden := await shot("")
	set_mode(0)
	var shown := await shot("")
	if hidden.get_data() != shown.get_data():
		push_error("Silhouette proxy is visible with shadows disabled")
		quit(1)
		return
	light.shadow_enabled = true
	visible_tree.visible = true
	print("SILHOUETTE RASTER PASS: 48 variant/time pairs; minimum shadow pixels=", minimum, "; hidden proxy verified")
	ground_material.albedo_texture = preload("res://assets/tiles/grass_surface.png")
	ground_material.albedo_color = Color.WHITE
	variant = 3
	variant_picker.select(variant)
	rebuild_tree()
	for test_hour in [7.45, 7.666667, 7.733333, 7.833333, 8.0, 12.0, 18.5, 0.0]:
		set_hour(test_hour)
		set_mode(0)
		set_receive(true)
		await shot("%s_receive" % str(test_hour))
		set_receive(false)
		await shot("%s_clean" % str(test_hour))
	set_hour(7.733333)
	set_mode(1)
	await shot("volume_comparison")
	set_mode(0)
	Engine.time_scale = 1.0
	receive.set_pressed_no_signal(false)
	running = true
	print("SILHOUETTE PILOT ready: one tree, 6 selectable variants; alpha/volume/no-shadow comparison; receive-shadows toggle")
	if "--quit-after-tests" in OS.get_cmdline_user_args(): quit()

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	scene.add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,16)
	canvas.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "Тест: одно дерево\nОсновной лес не изменён"
	rows.add_child(title)
	rows.add_child(status)
	time_slider.min_value = 0
	time_slider.max_value = 23.99
	time_slider.step = .01
	time_slider.custom_minimum_size = Vector2(255, 24)
	time_slider.value_changed.connect(set_hour)
	rows.add_child(time_slider)
	play.text = "Ход времени"
	rows.add_child(play)
	for text in ["Новая: силуэт", "Прежняя: объёмная", "Без тени"]: mode_picker.add_item(text)
	mode_picker.item_selected.connect(set_mode)
	rows.add_child(mode_picker)
	for texture in TREES.TREE_SHEETS: variant_picker.add_item(texture.resource_path.get_file().trim_suffix("_Body_000.png"))
	variant_picker.item_selected.connect(func(value: int): variant = value; rebuild_tree())
	rows.add_child(variant_picker)
	receive.text = "Приём теней деревом"
	receive.tooltip_text = "Выключение убирает самозатенение, но также исключает приём чужих теней этим спрайтом. Только в тесте."
	receive.toggled.connect(set_receive)
	rows.add_child(receive)
	var grass := CheckButton.new()
	grass.text = "Текстура травы"
	grass.button_pressed = true
	grass.toggled.connect(func(enabled: bool):
		ground_material.albedo_texture = preload("res://assets/tiles/grass_surface.png") if enabled else null
		ground_material.albedo_color = Color.WHITE if enabled else Color(0.35, 0.35, 0.35))
	rows.add_child(grass)
	var note := Label.new()
	note.text = "Проверь 07:40–08:00 и 12:00.\nПриём теней — отдельный компромисс."
	rows.add_child(note)
