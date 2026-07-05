extends CharacterBody3D

signal dream_entered

@export_group("Movement")
@export var run_speed: float = 34.0
@export var ground_acceleration: float = 58.0
@export var air_acceleration: float = 10.0
@export var ground_deceleration: float = 38.0
@export var air_deceleration: float = 0.5
@export_range(0.2, 3.0, 0.1) var air_turn_rate: float = 1.25
@export var jump_velocity: float = 17.5
@export var gravity_multiplier: float = 1.35
@export var maximum_fall_speed: float = 42.0

@export_group("Slope Influence")
@export_range(0.0, 1.0, 0.01) var uphill_speed_penalty: float = 0.18
@export_range(0.0, 1.0, 0.01) var downhill_speed_boost: float = 0.25
@export_range(0.0, 4.0, 0.1) var slope_influence_strength: float = 2.0
@export var max_slope_speed_bonus: float = 6.0
@export var max_slope_speed_penalty: float = 4.0

@export_group("Glide")
@export var glide_gravity_multiplier: float = 0.18
@export var glide_fall_speed: float = 5.0
@export var glide_deceleration: float = 18.0

@export_group("Visual Pose")
@export_range(20.0, 85.0, 1.0) var glide_pose_degrees: float = 68.0
@export_range(0.0, 25.0, 1.0) var low_air_lean_degrees: float = 10.0
@export var full_glide_pose_height: float = 6.0
@export var pose_smoothing: float = 5.5

@export_group("Procedural Visual Motion")
@export_range(0.0, 0.6, 0.01) var bound_hop_height: float = 0.3
@export_range(1.5, 4.0, 0.05) var bound_full_speed_footfalls_per_second: float = 2.9
@export_range(0.2, 1.0, 0.05) var bound_min_cadence_factor: float = 0.45
@export_range(0.0, 20.0, 1.0) var bound_body_pitch_degrees: float = 9.0
@export_range(0.0, 18.0, 1.0) var bound_side_sway_degrees: float = 4.0
@export_range(10.0, 65.0, 1.0) var bound_leg_drive_degrees: float = 46.0
@export_range(5.0, 45.0, 1.0) var bound_trailing_leg_degrees: float = 24.0
@export_range(5.0, 50.0, 1.0) var bound_arm_counter_degrees: float = 26.0
@export_range(0.0, 0.25, 0.01) var bound_landing_squash: float = 0.08
@export_range(20.0, 80.0, 1.0) var glide_arm_lift_degrees: float = 64.0
@export_range(5.0, 45.0, 1.0) var glide_arm_open_degrees: float = 28.0
@export_range(0.0, 25.0, 1.0) var glide_leg_trail_degrees: float = 14.0
@export_range(2.0, 10.0, 0.25) var motion_smoothing: float = 7.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var rotation_smoothing: float = 12.0
@export_range(-80.0, 0.0, 1.0) var min_pitch_degrees: float = -35.0
@export_range(0.0, 30.0, 1.0) var max_pitch_degrees: float = 4.0
@export var normal_fov: float = 78.0
@export var run_fov: float = 84.0
@export var glide_fov: float = 86.0
@export var fov_smoothing: float = 5.0
@export var camera_vertical_smoothing: float = 7.0
@export var camera_height: float = 1.4

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var visual_pivot: Node3D = $VisualPivot
@onready var pose_pivot: Node3D = $VisualPivot/PosePivot
@onready var motion_pivot: Node3D = $VisualPivot/PosePivot/MotionPivot
@onready var left_arm_pivot: Node3D = $VisualPivot/PosePivot/MotionPivot/LeftArmPivot
@onready var right_arm_pivot: Node3D = $VisualPivot/PosePivot/MotionPivot/RightArmPivot
@onready var left_leg_pivot: Node3D = $VisualPivot/PosePivot/MotionPivot/LeftLegPivot
@onready var right_leg_pivot: Node3D = $VisualPivot/PosePivot/MotionPivot/RightLegPivot
@onready var ground_distance_ray: RayCast3D = $GroundDistanceRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pitch: float = deg_to_rad(-12.0)
var target_pitch: float = pitch
var yaw: float = 0.0
var target_yaw: float = 0.0
var starting_transform: Transform3D
var starting_pitch: float
var glide_pose_blend: float = 0.0
var ground_clearance: float = 0.0
var motion_phase: float = 0.0


func _ready() -> void:
	safe_margin = 0.001
	floor_snap_length = 0.45
	starting_transform = global_transform
	starting_pitch = pitch

	var initial_camera_position := camera_pivot.global_position
	camera_pivot.top_level = true
	camera_pivot.global_position = initial_camera_position
	camera_pivot.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)

	# Web browsers only allow pointer lock after a user gesture, so the player
	# clicks the game to capture the mouse instead of doing it automatically.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	yaw = rotation.y
	target_yaw = yaw
	camera_pivot.global_rotation = Vector3(pitch, yaw, 0.0)
	camera.fov = normal_fov
	# Never let the spring arm mistake the player capsule for scenery and
	# collapse the camera during a fast orbit.
	spring_arm.add_excluded_object(get_rid())
	reset_physics_interpolation()
	camera_pivot.reset_physics_interpolation()
	visual_pivot.rotation = Vector3.ZERO
	pose_pivot.rotation = Vector3.ZERO
	motion_pivot.position = Vector3.ZERO
	motion_pivot.rotation = Vector3.ZERO


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_player"):
		reset_to_start()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		release_mouse_and_pause()
		get_viewport().set_input_as_handled()
		return

	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	):
		capture_mouse()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_yaw = wrapf(target_yaw, -PI, PI)
		target_pitch -= event.relative.y * mouse_sensitivity
		target_pitch = clamp(
			target_pitch,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	dream_entered.emit()


func release_mouse_and_pause() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func reset_to_start() -> void:
	global_transform = starting_transform
	velocity = Vector3.ZERO
	yaw = starting_transform.basis.get_euler().y
	target_yaw = yaw
	pitch = starting_pitch
	target_pitch = pitch
	camera_pivot.global_position = global_position + Vector3.UP * camera_height
	camera_pivot.global_rotation = Vector3(pitch, yaw, 0.0)
	glide_pose_blend = 0.0
	ground_clearance = 0.0
	visual_pivot.rotation = Vector3.ZERO
	pose_pivot.rotation = Vector3.ZERO
	motion_phase = 0.0
	motion_pivot.position = Vector3.ZERO
	motion_pivot.rotation = Vector3.ZERO
	motion_pivot.scale = Vector3.ONE
	left_arm_pivot.rotation.x = 0.0
	right_arm_pivot.rotation.x = 0.0
	left_arm_pivot.rotation.z = deg_to_rad(-8.0)
	right_arm_pivot.rotation.z = deg_to_rad(8.0)
	left_leg_pivot.rotation.x = 0.0
	right_leg_pivot.rotation.x = 0.0
	reset_physics_interpolation()
	camera_pivot.reset_physics_interpolation()


func _process(delta: float) -> void:
	var smoothing_weight := 1.0 - exp(-rotation_smoothing * delta)
	yaw = lerp_angle(yaw, target_yaw, smoothing_weight)
	yaw = wrapf(yaw, -PI, PI)
	pitch = lerp_angle(pitch, target_pitch, smoothing_weight)
	camera_pivot.global_rotation = Vector3(pitch, yaw, 0.0)

	# Follow the position rendered between physics ticks, not the latest raw
	# physics position. This prevents fixed-tick stepping from shaking the camera.
	var interpolated_player_position := get_global_transform_interpolated().origin
	var camera_target := interpolated_player_position + Vector3.UP * camera_height
	var vertical_weight := 1.0 - exp(-camera_vertical_smoothing * delta)
	var camera_position := camera_pivot.global_position
	# The interpolated target is already smooth. Exact horizontal tracking keeps
	# the orbit centered during fast turns instead of sweeping through the player.
	camera_position.x = camera_target.x
	camera_position.z = camera_target.z
	camera_position.y = lerpf(camera_position.y, camera_target.y, vertical_weight)
	camera_pivot.global_position = camera_position

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var run_blend := clampf(horizontal_speed / maxf(run_speed, 0.1), 0.0, 1.0)
	var target_fov := glide_fov if is_gliding() else lerpf(normal_fov, run_fov, run_blend)
	var fov_weight := 1.0 - exp(-fov_smoothing * delta)
	camera.fov = lerpf(camera.fov, target_fov, fov_weight)
	update_visual_pose(delta)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement_basis := Basis(Vector3.UP, yaw)
	var move_dir := (movement_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_speed := run_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var desired_speed := target_speed
	if is_on_floor():
		desired_speed += get_slope_speed_adjustment(move_dir, target_speed)
	else:
		desired_speed = maxf(desired_speed, horizontal_velocity.length())
	var target_velocity := move_dir * desired_speed

	if move_dir != Vector3.ZERO and not is_on_floor():
		var momentum_direction: Vector3 = (
			horizontal_velocity.normalized()
			if horizontal_velocity.length_squared() > 0.01
			else move_dir
		)
		var steering_weight: float = clampf(air_turn_rate * delta, 0.0, 1.0)
		var steered_direction: Vector3 = momentum_direction.slerp(move_dir, steering_weight)
		target_velocity = steered_direction.normalized() * desired_speed
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			air_acceleration * delta
		)
	elif move_dir != Vector3.ZERO:
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			ground_acceleration * delta
		)
	else:
		var decel := ground_deceleration if is_on_floor() else air_deceleration
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, decel * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if not is_on_floor():
		if is_gliding():
			apply_glide(delta)
		else:
			velocity.y = maxf(
				velocity.y - gravity * gravity_multiplier * delta,
				-maximum_fall_speed
			)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()


func get_slope_speed_adjustment(move_direction: Vector3, base_speed: float) -> float:
	if not is_on_floor() or move_direction == Vector3.ZERO:
		return 0.0

	var floor_normal := get_floor_normal()
	var downhill_vector := Vector3(floor_normal.x, 0.0, floor_normal.z)
	var slope_steepness := downhill_vector.length()
	if slope_steepness < 0.001:
		return 0.0

	var downhill_direction := downhill_vector / slope_steepness
	var travel_alignment := move_direction.dot(downhill_direction)
	var influence := clampf(
		travel_alignment * slope_steepness * slope_influence_strength,
		-1.0,
		1.0
	)

	if influence > 0.0:
		return minf(
			base_speed * downhill_speed_boost * influence,
			max_slope_speed_bonus
		)

	return -minf(
		base_speed * uphill_speed_penalty * absf(influence),
		max_slope_speed_penalty
	)


func is_gliding() -> bool:
	return (
		not is_on_floor()
		and velocity.y < 0.0
		and Input.is_action_pressed("jump")
	)


func apply_glide(delta: float) -> void:
	if velocity.y < -glide_fall_speed:
		velocity.y = move_toward(
			velocity.y,
			-glide_fall_speed,
			glide_deceleration * delta
		)
	else:
		velocity.y = maxf(
			velocity.y - gravity * glide_gravity_multiplier * delta,
			-glide_fall_speed
		)


func update_visual_pose(delta: float) -> void:
	ground_clearance = 0.0
	if ground_distance_ray.is_colliding():
		ground_clearance = global_position.y - ground_distance_ray.get_collision_point().y
	elif not is_on_floor():
		ground_clearance = ground_distance_ray.target_position.length()

	var height_blend: float = clampf(
		inverse_lerp(1.5, full_glide_pose_height, ground_clearance),
		0.0,
		1.0
	)
	var target_blend: float = height_blend if is_gliding() else 0.0
	var blend_weight: float = 1.0 - exp(-pose_smoothing * delta)
	glide_pose_blend = lerpf(glide_pose_blend, target_blend, blend_weight)
	var low_air_lean: float = 0.0 if is_on_floor() else low_air_lean_degrees
	var target_pitch_degrees: float = lerpf(
		low_air_lean,
		glide_pose_degrees,
		glide_pose_blend
	)
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length_squared() > 0.25:
		var target_heading: float = atan2(-horizontal_velocity.x, -horizontal_velocity.y)
		visual_pivot.rotation.y = lerp_angle(
			visual_pivot.rotation.y,
			target_heading,
			blend_weight
		)
	visual_pivot.rotation.x = 0.0
	visual_pivot.rotation.z = 0.0
	pose_pivot.rotation.x = lerp_angle(
		pose_pivot.rotation.x,
		deg_to_rad(-target_pitch_degrees),
		blend_weight
	)
	pose_pivot.rotation.y = 0.0
	pose_pivot.rotation.z = 0.0
	update_character_motion(delta)


func update_character_motion(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving_on_ground: bool = is_on_floor() and horizontal_speed > 0.5
	var gliding: bool = is_gliding()
	var run_blend: float = clampf(horizontal_speed / maxf(run_speed, 0.1), 0.0, 1.0)
	if moving_on_ground:
		var cadence: float = lerpf(
			bound_full_speed_footfalls_per_second * bound_min_cadence_factor,
			bound_full_speed_footfalls_per_second,
			run_blend
		)
		motion_phase = fmod(motion_phase + delta * cadence * TAU, TAU)

	var motion_weight: float = run_blend if moving_on_ground else 0.0
	var hop_arc: float = absf(sin(motion_phase)) if moving_on_ground else 0.0
	var contact_selector: float = signf(cos(motion_phase))
	var leg_drive: float = deg_to_rad(bound_leg_drive_degrees) * motion_weight
	var trailing_leg: float = deg_to_rad(bound_trailing_leg_degrees) * motion_weight
	var left_leg_target: float = 0.0
	var right_leg_target: float = 0.0
	if moving_on_ground and contact_selector >= 0.0:
		# Right support, left leg reaching into the next long dream-bound.
		right_leg_target = trailing_leg * 0.25
		left_leg_target = -leg_drive * hop_arc
	elif moving_on_ground:
		left_leg_target = trailing_leg * 0.25
		right_leg_target = -leg_drive * hop_arc

	var arm_counter_scale: float = (
		deg_to_rad(bound_arm_counter_degrees)
		/ maxf(deg_to_rad(bound_leg_drive_degrees), 0.001)
	)
	var left_arm_target: float = -right_leg_target * arm_counter_scale
	var right_arm_target: float = -left_leg_target * arm_counter_scale
	var left_arm_open_target: float = deg_to_rad(-8.0)
	var right_arm_open_target: float = deg_to_rad(8.0)

	var target_bob: float = hop_arc * bound_hop_height * motion_weight
	var target_lean: float = (
		-deg_to_rad(bound_body_pitch_degrees) * run_blend
		if moving_on_ground
		else 0.0
	)
	var target_side_sway: float = (
		sin(motion_phase) * deg_to_rad(bound_side_sway_degrees) * motion_weight
		if moving_on_ground
		else 0.0
	)
	var contact_strength: float = 1.0 - hop_arc if moving_on_ground else 0.0
	var target_stretch: float = 1.0
	var target_width: float = 1.0
	if moving_on_ground:
		target_stretch -= contact_strength * bound_landing_squash * motion_weight
		target_width += contact_strength * 0.025 * motion_weight
	if not is_on_floor() and not gliding:
		target_lean = -deg_to_rad(4.0)
		target_stretch = 1.025 if velocity.y > 0.0 else 1.0
	elif gliding:
		target_lean = 0.0
		target_bob = 0.0
		left_arm_target = deg_to_rad(glide_arm_lift_degrees)
		right_arm_target = deg_to_rad(glide_arm_lift_degrees)
		left_arm_open_target = -deg_to_rad(glide_arm_open_degrees)
		right_arm_open_target = deg_to_rad(glide_arm_open_degrees)
		left_leg_target = -deg_to_rad(glide_leg_trail_degrees)
		right_leg_target = -deg_to_rad(glide_leg_trail_degrees)

	var weight: float = 1.0 - exp(-motion_smoothing * delta)
	motion_pivot.position.y = lerpf(motion_pivot.position.y, target_bob, weight)
	motion_pivot.rotation.x = lerp_angle(motion_pivot.rotation.x, target_lean, weight)
	motion_pivot.rotation.y = 0.0
	motion_pivot.rotation.z = lerp_angle(
		motion_pivot.rotation.z, target_side_sway, weight
	)
	motion_pivot.scale = motion_pivot.scale.lerp(
		Vector3(target_width, target_stretch, target_width), weight
	)
	left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, left_arm_target, weight)
	right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, right_arm_target, weight)
	left_arm_pivot.rotation.z = lerp_angle(left_arm_pivot.rotation.z, left_arm_open_target, weight)
	right_arm_pivot.rotation.z = lerp_angle(right_arm_pivot.rotation.z, right_arm_open_target, weight)
	left_leg_pivot.rotation.x = lerp_angle(left_leg_pivot.rotation.x, left_leg_target, weight)
	right_leg_pivot.rotation.x = lerp_angle(right_leg_pivot.rotation.x, right_leg_target, weight)


func get_ground_clearance() -> float:
	return ground_clearance


func get_glide_pose_blend() -> float:
	return glide_pose_blend
