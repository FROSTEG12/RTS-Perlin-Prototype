extends RefCounted

# Art-directed orthographic lighting with one continuous 24-hour orbit.
# The night arc represents moonlight without switching shadow sources.
# Keep the elevation above the horizon to bound ground-shadow lengths.
static func sample(hour: float) -> Dictionary:
	var t := fposmod(hour, 24.0)
	var day := smoothstep(5.5, 8.0, t) * (1.0 - smoothstep(17.0, 20.5, t))
	var dawn := exp(-pow((t - 6.5) / 1.15, 2.0))
	var dusk := exp(-pow((t - 18.5) / 1.25, 2.0))
	var warmth := maxf(dawn, dusk)
	var phase := t * TAU / 24.0
	var elevation := 28.0 + 30.0 * pow(cos(phase), 2.0)
	var azimuth := -35.0 + (t - 12.0) * 15.0
	var key := Color(0.40, 0.57, 1.0).lerp(Color(1.0, 0.96, 0.87), day)
	key = key.lerp(Color(1.0, 0.64, 0.40), warmth * 0.72)
	var ambient := Color(0.24, 0.36, 0.62).lerp(Color(0.66, 0.72, 0.77), day)
	ambient = ambient.lerp(Color(0.53, 0.43, 0.48), warmth * 0.35)
	return {
		"rotation": Vector3(deg_to_rad(-elevation), deg_to_rad(azimuth), 0.0),
		"key_color": key,
		"key_energy": lerpf(0.48, 1.22, day),
		"ambient_color": ambient,
		"ambient_energy": lerpf(0.62, 0.48, day),
		"shadow_opacity": lerpf(0.30, 0.82, day),
	}


static func apply(hour: float, key: DirectionalLight3D, environment: Environment) -> void:
	var state := sample(hour)
	key.rotation = state.rotation
	key.light_color = state.key_color
	key.light_energy = state.key_energy
	key.shadow_opacity = state.shadow_opacity
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = state.ambient_color
	environment.ambient_light_energy = state.ambient_energy
