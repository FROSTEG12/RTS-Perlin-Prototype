extends Node3D
## Visual-only locomotion; the RTS controller owns position and path following.
const TURN_SPEED := 12.0
@onready var player: AnimationPlayer = $Model/AnimationPlayer

func set_model(scene: PackedScene) -> void:
	var old := $Model
	remove_child(old)
	old.free()
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * 0.55
	add_child(model)
	player = model.get_node("AnimationPlayer")
	reset_pose()

func set_motion(velocity: Vector3, delta: float) -> void:
	var moving := velocity.length_squared() > 0.0001
	var clip := ("walk" if velocity.length() < 1.6 and player.has_animation("walk") else "jog") if moving else "idle"
	if player.current_animation != clip:
		player.play(clip, 0.16)
	# Base gait at the prototype's 2.25 world units/s; visual playback only.
	var gait_speed := 2.25
	if $Model.has_meta("knight_gait"):
		gait_speed = 0.977 if clip == "walk" else 2.697
	player.speed_scale = clampf(velocity.length() / gait_speed, 0.5, 1.5) if moving else 1.0
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-TURN_SPEED * delta))

func reset_pose() -> void:
	if not is_node_ready(): return
	player.speed_scale = 1.0
	player.play("idle", 0.0)
	player.advance(0.0)
