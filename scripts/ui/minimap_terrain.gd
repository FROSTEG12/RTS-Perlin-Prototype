extends RefCounted
## Cartographic raster from real land, bathymetry and tree positions.
## Generated once per world, not per frame or resize. No fictional terrain.
const PIXELS_PER_CELL := 10

static func build(renderer: MapRenderer3D, seed_value: int) -> Image:
	var side := renderer.map_size
	var resolution := side * PIXELS_PER_CELL
	var land := Image.create(side, side, false, Image.FORMAT_RF)
	for y in side:
		for x in side:
			land.set_pixel(x, y, Color(1,0,0) if renderer.is_land(Vector2i(x,y)) else Color.BLACK)
	land.resize(resolution, resolution, Image.INTERPOLATE_CUBIC)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	var map := Image.create(resolution, resolution, false, Image.FORMAT_RGB8)
	var sea := Color("#193d51")
	var shallows := Color("#4b7980")
	var meadow := Color("#788253")
	var shore := Color("#a7a17a")
	var ds := renderer.depth_field_resolution
	for y in resolution:
		for x in resolution:
			var density := clampf(land.get_pixel(x,y).r, 0, 1)
			var coverage := smoothstep(0.38, 0.62, density)
			var fleck := noise.get_noise_2d(x,y)
			var grain := float(posmod(x * 73 + y * 137 + x * y * 19, 101)) / 100.0 - 0.5
			var dx := mini(ds - 1, x * ds / resolution)
			var dy := mini(ds - 1, y * ds / resolution)
			var depth: float = renderer.generated_seabed_depths[dy * ds + dx]
			var water := shallows.lerp(sea, smoothstep(0.05, 1.9, depth))
			water *= 1.0 + fleck * 0.09 + grain * 0.025
			var ground := meadow * (1.0 + fleck * 0.24 + grain * 0.07)
			ground = shore.lerp(ground, smoothstep(0.60, 0.94, density))
			map.set_pixel(x,y, water.lerp(ground, coverage))
	# Every crown corresponds to an actual tree, including its generation jitter.
	var trees: Array[Dictionary] = []
	for resource in renderer.resources:
		if resource.kind == "tree": trees.append(resource)
	trees.sort_custom(func(a: Dictionary, b: Dictionary): return a.y < b.y)
	for tree in trees:
		var center := Vector2(float(tree.x) + 0.5 + float(tree.get("offset_x", 0)), float(tree.y) + 0.5 + float(tree.get("offset_y", 0))) * PIXELS_PER_CELL
		var variation := float(posmod(int(tree.x) * 31 + int(tree.y) * 67, 29)) / 29.0
		var radius := (0.46 + variation * 0.20) * PIXELS_PER_CELL
		_stamp(map, land, center + Vector2(2.5, 3.8), radius * 1.16, Color("#142a22"), true)
		_stamp(map, land, center, radius, Color("#344c2b").lerp(Color("#596c38"), variation), false)
	map.generate_mipmaps()
	return map

static func _stamp(map: Image, land: Image, center: Vector2, radius: float, tint: Color, shadow: bool) -> void:
	for y in range(maxi(0, floori(center.y-radius-1)), mini(map.get_height(), ceili(center.y+radius+1))):
		for x in range(maxi(0, floori(center.x-radius-1)), mini(map.get_width(), ceili(center.x+radius+1))):
			if land.get_pixel(x,y).r < 0.55: continue
			var offset := (Vector2(x,y) - center) / radius
			var edge := 1.0 - offset.length()
			if edge <= 0: continue
			var opacity := smoothstep(0.0, 0.24, edge) * (0.36 if shadow else 0.96)
			var color := tint
			if not shadow:
				var light := clampf(0.72 + edge * 0.40 - (offset.x + offset.y) * 0.23, 0.55, 1.35)
				var leaf := 0.92 + float(posmod(x*17+y*43, 7)) * 0.025
				color *= light * leaf
			map.set_pixel(x,y, map.get_pixel(x,y).lerp(color, opacity))
