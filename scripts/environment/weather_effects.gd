extends Node3D
const MODEL := preload("res://scripts/environment/weather_model.gd")
var climate := MODEL.new()
var fog_material := ShaderMaterial.new()
var rain_material := ShaderMaterial.new()
var fog_quad := MeshInstance3D.new()
var rain_particles := GPUParticles3D.new()
var rain_process := ParticleProcessMaterial.new()
var collision := GPUParticlesCollisionHeightField3D.new()
var camera: Camera3D
var unit: Node3D

func setup(view_camera: Camera3D, player_unit: Node3D, seed_value: int) -> void:
	camera = view_camera
	unit = player_unit
	climate.reset(seed_value)
	var noise := FastNoiseLite.new()
	noise.seed = 73519
	noise.frequency = 0.017
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	fog_material.shader = preload("res://shaders/weather_fog.gdshader")
	fog_material.render_priority = 100
	fog_material.set_shader_parameter("billow_noise", texture)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	fog_quad.mesh = quad
	fog_quad.material_override = fog_material
	fog_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog_quad.layers = 2 # Do not enter the rain collision heightmap.
	fog_quad.extra_cull_margin = 16384.0
	camera.add_child(fog_quad)
	fog_quad.position.z = -1.0
	fog_quad.name = "GroundWeatherFog"
	rain_material.shader = preload("res://shaders/rain.gdshader")
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.38)
	drop.material = rain_material
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(25.0, 0.2, 25.0)
	rain_process.direction = Vector3(0.065, -1.0, 0.025)
	rain_process.spread = 1.5
	rain_process.initial_velocity_min = 10.0
	rain_process.initial_velocity_max = 13.0
	rain_process.gravity = Vector3(0.0, -2.0, 0.0)
	rain_process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rain_particles.name = "Rain"
	rain_particles.amount = 32000
	rain_particles.amount_ratio = 0.0
	rain_particles.lifetime = 1.8
	rain_particles.local_coords = false
	rain_particles.process_material = rain_process
	rain_particles.draw_pass_1 = drop
	rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_particles.layers = 2
	rain_particles.visibility_aabb = AABB(Vector3(-150, -20, -150), Vector3(300, 40, 300))
	add_child(rain_particles)
	collision.name = "RainRoofCollision"
	collision.position.y = 5.0
	collision.size = Vector3(106, 24, 106)
	collision.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_1024
	collision.heightfield_mask = 1
	add_child(collision)

func refresh_world(half_extent: float) -> void:
	fog_material.set_shader_parameter("map_half_extent", half_extent)
	rain_material.set_shader_parameter("map_half_extent", half_extent)
	collision.size = Vector3(half_extent * 2.0 + 2.0, 24.0, half_extent * 2.0 + 2.0)
	# Static heightfield refreshed for new terrain/buildings, not every frame.
	collision.position.y = 5.001 if collision.position.y == 5.0 else 5.0

func update_visuals(hour: float, key: DirectionalLight3D, environment: Environment) -> void:
	# Caller first restores the base day/night state; these factors never compound.
	var overcast: float = climate.cloud
	key.light_energy *= lerpf(1.0, 0.30, overcast)
	key.shadow_opacity *= lerpf(1.0, 0.20, overcast)
	key.light_color = key.light_color.lerp(Color(0.73, 0.79, 0.87), overcast * 0.80)
	environment.ambient_light_energy *= lerpf(1.0, 0.92, overcast)
	environment.ambient_light_color = environment.ambient_light_color.lerp(Color(0.48, 0.55, 0.66), overcast * 0.35)
	environment.background_color = environment.background_color.lerp(environment.background_color * Color(0.82, 0.87, 0.96), overcast)
	var daylight := smoothstep(5.5, 8.0, hour) * (1.0 - smoothstep(17.0, 20.5, hour))
	var fog_color := Color(0.12, 0.16, 0.24).lerp(Color(0.51, 0.54, 0.58), daylight)
	fog_material.set_shader_parameter("fog_color", Vector3(fog_color.srgb_to_linear().r, fog_color.srgb_to_linear().g, fog_color.srgb_to_linear().b))
	fog_material.set_shader_parameter("intensity", climate.fog)
	fog_material.set_shader_parameter("unit_position", unit.global_position)
	fog_quad.visible = climate.fog > 0.001
	rain_material.set_shader_parameter("strength", minf(climate.rain * 2.0, 1.0))
	rain_material.set_shader_parameter("brightness", lerpf(0.18, 0.75, daylight))
	_update_rain_area()

func _update_rain_area() -> void:
	var rect := camera.get_viewport().get_visible_rect().size
	var bounds := Rect2()
	var initialized := false
	for height in [0.0, 12.0]:
		for corner in [Vector2.ZERO, Vector2(rect.x, 0.0), rect, Vector2(0.0, rect.y)]:
			var origin := camera.project_ray_origin(corner)
			var direction := camera.project_ray_normal(corner)
			var p: Vector3 = origin + direction * ((height - origin.y) / direction.y)
			var point := Vector2(p.x, p.z)
			bounds = bounds.expand(point) if initialized else Rect2(point, Vector2.ZERO)
			initialized = true
	bounds = bounds.grow(4.0)
	var center := bounds.get_center()
	rain_particles.global_position = Vector3(center.x, 12.0, center.y)
	rain_process.emission_box_extents = Vector3(bounds.size.x * 0.5, 0.15, bounds.size.y * 0.5)
	rain_particles.amount_ratio = clampf(bounds.get_area() / 6000.0, 0.02, 1.0) * climate.rain
	rain_particles.emitting = climate.rain > 0.002
