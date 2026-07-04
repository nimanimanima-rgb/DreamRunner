extends Node3D

@export var player_path: NodePath
@export var camera_path: NodePath
@export var terrain_manager_path: NodePath
@export_range(60.0, 220.0, 5.0) var minimum_distance: float = 105.0
@export_range(80.0, 260.0, 5.0) var maximum_distance: float = 165.0
@export_range(2.0, 12.0, 0.5) var reach_radius: float = 6.0
@export_range(1.0, 8.0, 0.5) var height_above_ground: float = 4.0

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


func _ready() -> void:
	random.seed = 91027
	create_destination_visual()
	previous_player_position = player.global_position
	place_new_destination()


func _process(delta: float) -> void:
	animation_time += delta
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
	is_resolving = false
	response_time = 0.0
	marker.visible = true
	marker.scale = Vector3.ONE
	marker_material.albedo_color.a = 0.82
	marker_material.emission_energy_multiplier = 1.8

	var chosen_position: Vector3 = find_destination_position()
	destination_ground_height = chosen_position.y
	marker.global_position = chosen_position + Vector3.UP * height_above_ground


func find_destination_position() -> Vector3:
	var forward: Vector3 = get_preferred_direction()
	var extra_distance: float = 20.0 if destinations_reached > 0 else 0.0
	var fallback_position := player.global_position + forward * (minimum_distance + extra_distance)
	fallback_position.y = get_terrain_height(fallback_position.x, fallback_position.z)

	for _attempt in range(12):
		var angle: float = random.randf_range(-0.7, 0.7)
		var direction: Vector3 = forward.rotated(Vector3.UP, angle).normalized()
		var distance: float = random.randf_range(
			minimum_distance + extra_distance,
			maximum_distance + extra_distance
		)
		var candidate := player.global_position + direction * distance
		candidate.y = get_terrain_height(candidate.x, candidate.z)
		if is_slope_suitable(candidate):
			return candidate

	return fallback_position


func get_preferred_direction() -> Vector3:
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal_velocity.length_squared() > 9.0:
		return horizontal_velocity.normalized()

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
