extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 14.0
@export var sprint_speed: float = 32.0
@export var ground_acceleration: float = 70.0
@export var air_acceleration: float = 22.0
@export var ground_deceleration: float = 55.0
@export var air_deceleration: float = 2.0
@export var jump_velocity: float = 18.0
@export var gravity_multiplier: float = 2.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var pitch_smoothing: float = 14.0
@export var min_pitch: float = -55.0
@export var max_pitch: float = 25.0

@onready var camera_pivot: Node3D = $CameraPivot

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pitch: float = deg_to_rad(-12.0)
var target_pitch: float = pitch


func _ready() -> void:
	safe_margin = 0.001
	floor_snap_length = 0.3

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_pivot.rotation.x = pitch


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)

		target_pitch -= event.relative.y * mouse_sensitivity
		target_pitch = clamp(target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	var smoothing_weight := 1.0 - exp(-pitch_smoothing * delta)
	pitch = lerp_angle(pitch, target_pitch, smoothing_weight)
	camera_pivot.rotation.x = pitch


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
		velocity.y -= gravity * gravity_multiplier * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
