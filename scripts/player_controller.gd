extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 13.0
@export var sprint_speed: float = 34.0
@export var ground_acceleration: float = 58.0
@export var air_acceleration: float = 10.0
@export var ground_deceleration: float = 38.0
@export var air_deceleration: float = 0.5
@export var jump_velocity: float = 17.5
@export var gravity_multiplier: float = 1.35
@export var maximum_fall_speed: float = 42.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var rotation_smoothing: float = 12.0
@export var min_pitch: float = -55.0
@export var max_pitch: float = 25.0
@export var normal_fov: float = 78.0
@export var sprint_fov: float = 84.0
@export var fov_smoothing: float = 5.0
@export var camera_follow_smoothing: float = 18.0
@export var camera_vertical_smoothing: float = 7.0
@export var camera_height: float = 1.4

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pitch: float = deg_to_rad(-12.0)
var target_pitch: float = pitch
var yaw: float = 0.0
var target_yaw: float = 0.0


func _ready() -> void:
	safe_margin = 0.001
	floor_snap_length = 0.45

	var initial_camera_position := camera_pivot.global_position
	camera_pivot.top_level = true
	camera_pivot.global_position = initial_camera_position

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	yaw = rotation.y
	target_yaw = yaw
	camera_pivot.global_rotation = Vector3(pitch, yaw, 0.0)
	camera.fov = normal_fov


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_pitch -= event.relative.y * mouse_sensitivity
		target_pitch = clamp(target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	var smoothing_weight := 1.0 - exp(-rotation_smoothing * delta)
	yaw = lerp_angle(yaw, target_yaw, smoothing_weight)
	pitch = lerp_angle(pitch, target_pitch, smoothing_weight)
	rotation.y = yaw
	camera_pivot.global_rotation = Vector3(pitch, yaw, 0.0)

	var camera_target := global_position + Vector3.UP * camera_height
	var follow_weight := 1.0 - exp(-camera_follow_smoothing * delta)
	var vertical_weight := 1.0 - exp(-camera_vertical_smoothing * delta)
	var camera_position := camera_pivot.global_position
	camera_position.x = lerpf(camera_position.x, camera_target.x, follow_weight)
	camera_position.z = lerpf(camera_position.z, camera_target.z, follow_weight)
	camera_position.y = lerpf(camera_position.y, camera_target.y, vertical_weight)
	camera_pivot.global_position = camera_position

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_sprinting := Input.is_action_pressed("sprint") and horizontal_speed > walk_speed
	var target_fov := sprint_fov if is_sprinting else normal_fov
	var fov_weight := 1.0 - exp(-fov_smoothing * delta)
	camera.fov = lerpf(camera.fov, target_fov, fov_weight)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var desired_speed := target_speed
	if not is_on_floor():
		desired_speed = maxf(desired_speed, horizontal_velocity.length())
	var target_velocity := move_dir * desired_speed

	if move_dir != Vector3.ZERO:
		var accel := ground_acceleration if is_on_floor() else air_acceleration
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)
	else:
		var decel := ground_deceleration if is_on_floor() else air_deceleration
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, decel * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if not is_on_floor():
		velocity.y = maxf(
			velocity.y - gravity * gravity_multiplier * delta,
			-maximum_fall_speed
		)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
