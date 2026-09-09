extends Node3D
## Visual-only locomotion; the RTS controller owns position and path following.
const TURN_SPEED := 12.0
var animation_phase := 0.0
var animation_lod_enabled := true
var pose_updates := 0 # Diagnostic counter, never used by simulation.
var pose_interval := 0.0
var pose_elapsed := 0.0
var pose_schedule := 0.0
var visibility_clock := 0.0
var camera_transform := Transform3D.IDENTITY
var camera_size := -1.0
var camera_viewport := Vector2.ZERO
static var next_phase_index := 0
@onready var player: AnimationPlayer = $Model/AnimationPlayer

func _ready() -> void:
	# Golden-ratio sequence spreads phases even in small squads. No per-frame RNG,
	# no movement-speed jitter, and no edits to shared Animation resources.
	animation_phase = fposmod(next_phase_index * 0.61803398875, 1.0)
	next_phase_index += 1
	_configure_player()
	pose_schedule = animation_phase / 20.0
	visibility_clock = animation_phase * 0.12

func _configure_player() -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.current_animation_changed.connect(_clip_changed)

func _clip_changed(_clip: StringName) -> void:
	# Elapsed time belongs to the previous clip, not to a newly issued action.
	pose_elapsed = 0.0

func _process(delta: float) -> void:
	if not player.active or not player.is_playing(): return
	pose_elapsed += delta * player.speed_scale
	pose_schedule += delta
	var camera := get_viewport().get_camera_3d()
	visibility_clock -= delta
	if camera == null or not animation_lod_enabled:
		pose_interval = 0.0
	elif visibility_clock <= 0 or camera_transform != camera.global_transform or camera_size != camera.size or camera_viewport != get_viewport().get_visible_rect().size:
		visibility_clock = 0.12
		camera_transform = camera.global_transform
		camera_size = camera.size
		camera_viewport = get_viewport().get_visible_rect().size
		var point := global_position + Vector3.UP * 0.7
		# Conservative overscan preserves casters whose shadows enter the view.
		var bounds := get_viewport().get_visible_rect().grow(maxf(256, camera_viewport.y * 0.4))
		if (camera.is_position_behind(point) or not bounds.has_point(camera.unproject_position(point))) and not _shadow_reaches_view(camera, bounds):
			pose_interval = INF
		else:
			var pixels := camera.unproject_position(point).distance_to(camera.unproject_position(point + Vector3.UP * 1.4))
			pose_interval = 0.0 if pixels >= 80 else (1.0 / 30 if pixels >= 40 else 1.0 / 20)
	if pose_schedule >= pose_interval:
		pose_schedule = fmod(pose_schedule, pose_interval) if pose_interval > 0 else 0.0
		sample_pose()

func _shadow_reaches_view(camera: Camera3D, bounds: Rect2) -> bool:
	# Main-world directional light. A caster outside overscan can still project
	# a long dawn/dusk shadow into view; keep its pose updates in that case.
	var light := camera.get_parent().get_node_or_null("KeyLight") as DirectionalLight3D
	if light == null or not light.shadow_enabled or light.shadow_opacity <= 0: return false
	var ray := -light.global_basis.z
	if ray.y >= -0.001: return true # Near-horizontal light: prefer extra work to a frozen shadow.
	var tip := global_position + ray * (2.5 / -ray.y)
	var start := camera.unproject_position(global_position)
	var finish := camera.unproject_position(tip)
	return Rect2(start.min(finish), (finish-start).abs()).grow(32).intersects(bounds)

func sample_pose() -> void:
	# Also called at sparse combat contacts, so blood sockets are never stale.
	# Advance once by real elapsed time: no offscreen loop of missed frames.
	var elapsed := pose_elapsed
	pose_elapsed = 0.0
	if player.active:
		var speed := player.speed_scale
		player.speed_scale = 1.0
		player.advance(elapsed)
		player.speed_scale = speed
		pose_updates += 1

func set_model(scene: PackedScene) -> void:
	var old := $Model
	remove_child(old)
	old.free()
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * 0.55
	add_child(model)
	player = model.get_node("AnimationPlayer")
	_configure_player()
	reset_pose()

func set_motion(velocity: Vector3, delta: float) -> void:
	var moving := velocity.length_squared() > 0.0001
	var clip := ("walk" if velocity.length() < 1.6 and player.has_animation("walk") else "jog") if moving else "idle"
	if player.current_animation != clip:
		player.play(clip, 0.16)
		player.seek(animation_phase * player.get_animation(clip).length, false)
	# Base gait at the prototype's 2.25 world units/s; visual playback only.
	var gait_speed := 2.25
	if $Model.has_meta("knight_gait"):
		gait_speed = 0.977 if clip == "walk" else 2.697
	player.speed_scale = clampf(velocity.length() / gait_speed, 0.5, 1.5) if moving else 1.0
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-TURN_SPEED * delta))

func reset_pose() -> void:
	if not is_node_ready(): return
	pose_elapsed = 0.0
	visibility_clock = 0.0
	player.speed_scale = 1.0
	player.play("idle", 0.0)
	player.seek(animation_phase * player.get_animation("idle").length, false)
	player.advance(0.0)
