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
	var clip := "jog" if moving else "idle"
	if player.current_animation != clip:
		player.play(clip, 0.16)
	# Base gait at the prototype's 2.25 world units/s; visual playback only.
	player.speed_scale = clampf(velocity.length() / 2.25, 0.65, 1.35) if moving else 1.0
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-TURN_SPEED * delta))

func reset_pose() -> void:
	if not is_node_ready(): return
	player.speed_scale = 1.0
	player.play("idle", 0.0)
	player.advance(0.0)
