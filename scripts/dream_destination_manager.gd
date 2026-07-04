extends Node3D

@export var player_path: NodePath
@export var camera_path: NodePath
@export var terrain_manager_path: NodePath
@export_range(200.0, 500.0, 10.0) var minimum_distance: float = 320.0
@export_range(300.0, 800.0, 10.0) var preferred_distance_min: float = 520.0
@export_range(500.0, 1000.0, 10.0) var preferred_distance_max: float = 850.0
@export_range(700.0, 1200.0, 25.0) var far_distance_min: float = 1000.0
@export_range(900.0, 1400.0, 25.0) var far_distance_max: float = 1200.0
@export_range(0.0, 0.3, 0.01) var far_destination_chance: float = 0.1
@export_range(45.0, 90.0, 5.0) var preferred_forward_cone_degrees: float = 70.0
@export_range(90.0, 130.0, 5.0) var fallback_forward_cone_degrees: float = 110.0
@export var lateral_offset_min_degrees: float = 18.0
@export var lateral_offset_max_degrees: float = 55.0
@export var wide_lateral_offset_degrees: float = 80.0
@export var wide_lateral_chance: float = 0.18
@export_range(200.0, 500.0, 10.0) var previous_destination_clearance: float = 350.0
@export_range(2.0, 12.0, 0.5) var reach_radius: float = 6.0
@export_range(1.0, 8.0, 0.5) var height_above_ground: float = 4.0
@export_range(0.0, 1.0, 0.05) var revelation_composition_chance: float = 0.3

@onready var player: CharacterBody3D = get_node(player_path)
@onready var camera: Camera3D = get_node(camera_path)
@onready var terrain_manager: Node3D = get_node(terrain_manager_path)

var random := RandomNumberGenerator.new()
var marker: Node3D
var marker_material: StandardMaterial3D
var destination_ground_height: float = 0.0
var animation_time: float = 0.0
var response_time: float = 0.0
var is_resolving: bool = false
var destinations_reached: int = 0
var previous_player_position := Vector3.ZERO
var current_composition_name: String = "Quiet Passage"
var previous_composition_name: String = ""
var composition_giant_position := Vector3.INF
var last_destination_position := Vector3.INF
var last_travel_direction := Vector3.FORWARD
var has_travel_direction: bool = false
var has_active_destination: bool = false
var current_destination_is_far: bool = false
var placement_mode: String = "Forward"
var journey_heading := Vector3.FORWARD
var current_direction_offset_degrees: float = 0.0
var straight_destination_streak: int = 0
var last_lateral_sign: float = 1.0


func _ready() -> void:
	random.seed = 91027
	create_destination_visual()
	previous_player_position = player.global_position
	journey_heading = get_preferred_direction()
	place_new_destination()


func _process(delta: float) -> void:
	animation_time += delta
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal_velocity.length_squared() > 16.0:
		last_travel_direction = horizontal_velocity.normalized()
		has_travel_direction = true
	var player_movement: float = player.global_position.distance_to(previous_player_position)
	previous_player_position = player.global_position

	# A large one-frame move indicates the player used the reset/recenter action.
	if player_movement > 60.0:
		place_new_destination()
		return

	if is_resolving:
		update_destination_response(delta)
		return

	update_destination_motion(delta)
	if get_destination_distance() <= reach_radius:
		begin_destination_response()


func create_destination_visual() -> void:
	marker = Node3D.new()
	marker.name = "ActiveDestination"
	add_child(marker)

	marker_material = StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(0.57, 0.78, 1.0, 0.82)
	marker_material.emission_enabled = true
	marker_material.emission = Color(0.48, 0.67, 1.0)
	marker_material.emission_energy_multiplier = 1.8

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.45
	ring_mesh.outer_radius = 2.8
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 8

	var front_ring := MeshInstance3D.new()
	front_ring.name = "FrontRing"
	front_ring.mesh = ring_mesh
	front_ring.material_override = marker_material
	front_ring.rotation.x = PI * 0.5
	marker.add_child(front_ring)

	var cross_ring := MeshInstance3D.new()
	cross_ring.name = "CrossRing"
	cross_ring.mesh = ring_mesh
	cross_ring.material_override = marker_material
	cross_ring.rotation.z = PI * 0.5
	marker.add_child(cross_ring)

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.55
	orb_mesh.height = 1.1
	orb_mesh.radial_segments = 10
	orb_mesh.rings = 6

	var orb := MeshInstance3D.new()
	orb.name = "DreamOrb"
	orb.mesh = orb_mesh
	orb.material_override = marker_material
	marker.add_child(orb)

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.14
	pillar_mesh.bottom_radius = 0.42
	pillar_mesh.height = 40.0
	pillar_mesh.radial_segments = 8

	var pillar := MeshInstance3D.new()
	pillar.name = "SignalPillar"
	pillar.position.y = 16.0
	pillar.mesh = pillar_mesh
	pillar.material_override = marker_material
	marker.add_child(pillar)


func place_new_destination() -> void:
	if has_active_destination:
		last_destination_position = marker.global_position
	is_resolving = false
	response_time = 0.0
	marker.visible = true
	marker.scale = Vector3.ONE
	marker_material.albedo_color.a = 0.82
	marker_material.emission_energy_multiplier = 1.8
	select_composition()

	var chosen_position: Vector3 = find_destination_position()
	destination_ground_height = chosen_position.y
	marker.global_position = chosen_position + Vector3.UP * height_above_ground
	has_active_destination = true


func find_destination_position() -> Vector3:
	var forward: Vector3 = journey_heading
	current_destination_is_far = random.randf() < far_destination_chance
	if current_composition_name == "Horizon Call":
		current_destination_is_far = random.randf() < 0.35

	var preferred_position: Vector3 = find_best_forward_candidate(
		forward,
		deg_to_rad(preferred_forward_cone_degrees),
		32
	)
	if preferred_position != Vector3.INF:
		set_selected_path_debug(forward, preferred_position, false)
		return preferred_position

	var fallback_position: Vector3 = find_best_forward_candidate(
		forward,
		deg_to_rad(fallback_forward_cone_degrees),
		20
	)
	if fallback_position != Vector3.INF:
		set_selected_path_debug(forward, fallback_position, true)
		return fallback_position

	placement_mode = "Direct Fallback"
	var direct_distance: float = preferred_distance_min
	var direct_position := player.global_position + forward * direct_distance
	if (
		last_destination_position != Vector3.INF
		and horizontal_distance(direct_position, last_destination_position)
		< previous_destination_clearance
	):
		direct_position = (
			player.global_position
			+ forward.rotated(Vector3.UP, deg_to_rad(45.0)) * direct_distance
		)
	direct_position.y = get_terrain_height(direct_position.x, direct_position.z)
	return direct_position


func find_best_forward_candidate(
	forward: Vector3,
	half_angle_radians: float,
	attempt_count: int
) -> Vector3:
	var best_position := Vector3.INF
	var best_score: float = -INF
	var minimum_forward_dot: float = cos(half_angle_radians)
	for _attempt in range(attempt_count):
		var candidate: Vector3 = create_forward_candidate(forward, half_angle_radians)
		candidate.y = get_terrain_height(candidate.x, candidate.z)
		var candidate_direction := candidate - player.global_position
		candidate_direction.y = 0.0
		var candidate_distance: float = candidate_direction.length()
		if candidate_distance < minimum_distance:
			continue
		candidate_direction = candidate_direction.normalized()
		var forward_alignment: float = forward.dot(candidate_direction)
		if forward_alignment < minimum_forward_dot:
			continue
		if has_travel_direction and last_travel_direction.dot(candidate_direction) < cos(deg_to_rad(85.0)):
			continue
		if (
			last_destination_position != Vector3.INF
			and horizontal_distance(candidate, last_destination_position)
			< previous_destination_clearance
		):
			continue
		if not is_slope_suitable(candidate):
			continue
		var clearance: float = 45.0 if current_composition_name == "Liminal Clearing" else 24.0
		if not bool(terrain_manager.call("is_world_position_open", candidate, clearance)):
			continue
		if composition_giant_position != Vector3.INF:
			var giant_distance: float = horizontal_distance(candidate, composition_giant_position)
			if giant_distance < 55.0:
				continue

		var score: float = get_flow_score(
			candidate,
			forward_alignment,
			candidate_distance
		) + get_composition_score(candidate)
		if score > best_score:
			best_score = score
			best_position = candidate
	return best_position


func select_composition() -> void:
	previous_composition_name = current_composition_name
	composition_giant_position = Vector3.INF
	if random.randf() > revelation_composition_chance:
		current_composition_name = "Quiet Passage"
		return

	var composition_roll: float = random.randf()
	if composition_roll < 0.45:
		current_composition_name = "Ridge Reveal"
	elif composition_roll < 0.8:
		current_composition_name = "Liminal Clearing"
	elif composition_roll < 0.9:
		current_composition_name = "Solitary Giant"
	else:
		current_composition_name = "Horizon Call"

	if current_composition_name == previous_composition_name:
		current_composition_name = "Quiet Passage"
		return
	if current_composition_name in ["Solitary Giant", "Horizon Call"]:
		composition_giant_position = Vector3(
			terrain_manager.call(
				"get_nearest_giant_landmark_position",
				player.global_position,
				900.0
			)
		)
		if not is_giant_ahead(get_preferred_direction()):
			current_composition_name = "Quiet Passage"
			composition_giant_position = Vector3.INF


func is_giant_ahead(forward: Vector3) -> bool:
	if composition_giant_position == Vector3.INF:
		return false
	var giant_direction := composition_giant_position - player.global_position
	giant_direction.y = 0.0
	if giant_direction.length_squared() < 0.001:
		return false
	return forward.dot(giant_direction.normalized()) >= cos(
		deg_to_rad(preferred_forward_cone_degrees)
	)


func create_forward_candidate(forward: Vector3, half_angle_radians: float) -> Vector3:
	var minimum_candidate_distance: float = preferred_distance_min
	var maximum_candidate_distance: float = preferred_distance_max
	if current_destination_is_far:
		minimum_candidate_distance = far_distance_min
		maximum_candidate_distance = far_distance_max
	elif current_composition_name == "Ridge Reveal":
		minimum_candidate_distance = 520.0
		maximum_candidate_distance = 820.0
	elif current_composition_name == "Liminal Clearing":
		minimum_candidate_distance = 500.0
		maximum_candidate_distance = 780.0
	elif current_composition_name == "Horizon Call":
		minimum_candidate_distance = 650.0
		maximum_candidate_distance = 900.0

	var maximum_offset: float = minf(half_angle_radians, deg_to_rad(lateral_offset_max_degrees))
	if random.randf() < wide_lateral_chance:
		maximum_offset = minf(half_angle_radians, deg_to_rad(wide_lateral_offset_degrees))
	var minimum_offset: float = deg_to_rad(32.0 if straight_destination_streak >= 2 else lateral_offset_min_degrees)
	minimum_offset = minf(minimum_offset, maximum_offset)
	var lateral_sign: float = -1.0 if random.randf() < 0.5 else 1.0
	if random.randf() < 0.65:
		lateral_sign = -last_lateral_sign
	var angle: float = random.randf_range(minimum_offset, maximum_offset) * lateral_sign
	var direction: Vector3 = forward.rotated(Vector3.UP, angle).normalized()
	var distance: float = random.randf_range(
		minimum_candidate_distance,
		maximum_candidate_distance
	)
	return player.global_position + direction * distance


func get_flow_score(
	candidate: Vector3,
	forward_alignment: float,
	candidate_distance: float
) -> float:
	var preferred_center: float = (
		(far_distance_min + far_distance_max) * 0.5
		if current_destination_is_far
		else (preferred_distance_min + preferred_distance_max) * 0.5
	)
	var distance_score: float = -absf(candidate_distance - preferred_center) * 0.025
	var offset_degrees: float = rad_to_deg(acos(clampf(forward_alignment, -1.0, 1.0)))
	var lateral_center: float = (lateral_offset_min_degrees + lateral_offset_max_degrees) * 0.5
	return forward_alignment * 22.0 - absf(offset_degrees - lateral_center) * 0.7 + distance_score


func set_selected_path_debug(forward: Vector3, position: Vector3, fallback: bool) -> void:
	var direction: Vector3 = position - player.global_position
	direction.y = 0.0
	direction = direction.normalized()
	current_direction_offset_degrees = rad_to_deg(forward.signed_angle_to(direction, Vector3.UP))
	var absolute_offset: float = absf(current_direction_offset_degrees)
	placement_mode = "Fallback Arc" if fallback else ("Wide Lateral Arc" if absolute_offset > lateral_offset_max_degrees else "Lateral Arc")
	straight_destination_streak = straight_destination_streak + 1 if absolute_offset < 12.0 else 0
	if absolute_offset > 0.1:
		last_lateral_sign = signf(current_direction_offset_degrees)


func advance_journey_heading() -> void:
	var base_heading: Vector3 = journey_heading
	if has_travel_direction:
		base_heading = base_heading.slerp(last_travel_direction, 0.35).normalized()
	var turn_sign: float = -last_lateral_sign if random.randf() < 0.65 else last_lateral_sign
	journey_heading = base_heading.rotated(Vector3.UP, deg_to_rad(random.randf_range(10.0, 28.0) * turn_sign)).normalized()


func get_composition_score(candidate: Vector3) -> float:
	match current_composition_name:
		"Ridge Reveal":
			return get_ridge_reveal_score(candidate)
		"Solitary Giant":
			var giant_distance: float = horizontal_distance(candidate, composition_giant_position)
			return -absf(giant_distance - 180.0) * 0.035 + candidate.y * 0.05
		"Horizon Call":
			return horizontal_distance(candidate, player.global_position) * 0.008 + candidate.y * 0.08
		"Liminal Clearing":
			return -get_local_height_variation(candidate, 12.0) * 3.0
		_:
			return -get_local_height_variation(candidate, 8.0) + random.randf() * 0.25


func get_ridge_reveal_score(candidate: Vector3) -> float:
	var highest_occlusion: float = -INF
	for fraction in [0.3, 0.45, 0.6]:
		var sample_position: Vector3 = player.global_position.lerp(candidate, fraction)
		var terrain_height: float = get_terrain_height(sample_position.x, sample_position.z)
		var sightline_height: float = lerpf(
			player.global_position.y,
			candidate.y,
			fraction
		)
		highest_occlusion = maxf(highest_occlusion, terrain_height - sightline_height)
	return highest_occlusion * 2.5 + candidate.y * 0.08


func get_local_height_variation(candidate: Vector3, sample_offset: float) -> float:
	var maximum_difference: float = 0.0
	var sample_offsets: Array[Vector2] = [
		Vector2(sample_offset, 0.0),
		Vector2(-sample_offset, 0.0),
		Vector2(0.0, sample_offset),
		Vector2(0.0, -sample_offset),
	]
	for offset in sample_offsets:
		var nearby_height: float = get_terrain_height(candidate.x + offset.x, candidate.z + offset.y)
		maximum_difference = maxf(maximum_difference, absf(nearby_height - candidate.y))
	return maximum_difference


func horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()


func get_preferred_direction() -> Vector3:
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal_velocity.length_squared() > 9.0:
		return horizontal_velocity.normalized()
	if has_travel_direction:
		return last_travel_direction

	var camera_forward := camera.global_basis * Vector3.FORWARD
	camera_forward.y = 0.0
	if camera_forward.length_squared() < 0.001:
		return Vector3.FORWARD
	return camera_forward.normalized()


func is_slope_suitable(candidate: Vector3) -> bool:
	var sample_offset: float = 5.0
	var maximum_height_change: float = 3.5
	var center_height: float = candidate.y
	var sample_directions: Array[Vector2] = [
		Vector2(sample_offset, 0.0),
		Vector2(-sample_offset, 0.0),
		Vector2(0.0, sample_offset),
		Vector2(0.0, -sample_offset),
	]

	for offset in sample_directions:
		var nearby_height: float = get_terrain_height(
			candidate.x + offset.x,
			candidate.z + offset.y
		)
		if absf(nearby_height - center_height) > maximum_height_change:
			return false
	return true


func get_terrain_height(world_x: float, world_z: float) -> float:
	return float(terrain_manager.call("sample_height", world_x, world_z))


func update_destination_motion(delta: float) -> void:
	marker.rotation.y += delta * 0.32
	marker.position.y = destination_ground_height + height_above_ground + sin(animation_time * 1.25) * 0.45
	var pulse: float = 1.0 + sin(animation_time * 1.8) * 0.06
	marker.scale = Vector3.ONE * pulse
	var distance: float = get_destination_distance()
	var lost_boost: float = clampf((distance - 220.0) / 500.0, 0.0, 1.0)
	marker_material.emission_energy_multiplier = (
		1.8 + lost_boost * 2.2 + sin(animation_time * 1.8) * 0.18
	)


func begin_destination_response() -> void:
	is_resolving = true
	response_time = 0.0
	destinations_reached += 1
	advance_journey_heading()


func update_destination_response(delta: float) -> void:
	response_time += delta
	var progress: float = clampf(response_time / 0.7, 0.0, 1.0)
	var flash_scale: float = 1.0 + sin(progress * PI) * 0.75
	marker.scale = Vector3.ONE * flash_scale
	marker.rotation.y += delta * 1.8
	marker_material.albedo_color.a = 0.82 * (1.0 - progress)
	marker_material.emission_energy_multiplier = 1.8 + sin(progress * PI) * 2.2

	if progress >= 1.0:
		place_new_destination()


func get_destination_distance() -> float:
	if marker == null or not marker.visible:
		return -1.0
	var player_position_2d := Vector2(player.global_position.x, player.global_position.z)
	var destination_position_2d := Vector2(marker.global_position.x, marker.global_position.z)
	return player_position_2d.distance_to(destination_position_2d)


func get_destination_position() -> Vector3:
	if marker == null:
		return Vector3.ZERO
	return marker.global_position


func get_current_composition_name() -> String:
	return current_composition_name


func get_placement_mode() -> String:
	return placement_mode


func get_direction_offset_degrees() -> float:
	return current_direction_offset_degrees
