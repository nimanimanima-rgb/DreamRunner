extends Node3D

@export_group("Chunk Streaming")
@export var player_path: NodePath
@export var chunk_size: float = 160.0
@export_range(8, 40, 1) var grid_resolution: int = 20
@export_range(1, 4, 1) var active_radius: int = 2

@export_group("Rolling Hills")
@export var height_amplitude: float = 8.0
@export var terrain_scale: float = 0.004
@export var terrain_seed: int = 1337

@export_group("Nature Props")
@export_range(0, 8, 1) var trees_per_chunk: int = 2
@export_range(0, 8, 1) var rocks_per_chunk: int = 1
@export_range(0.0, 1.0, 0.01) var landmark_chance: float = 0.1
@export_range(0.0, 0.5, 0.01) var tree_cluster_chance: float = 0.18
@export var prop_seed: int = 4242
@export var prop_border_margin: float = 14.0
@export var minimum_prop_spacing: float = 12.0
@export var spawn_clear_radius: float = 45.0

@export_group("Placeholder Colors")
@export var grass_color_a := Color(0.31, 0.48, 0.25)
@export var grass_color_b := Color(0.28, 0.44, 0.23)
@export var trunk_color := Color(0.35, 0.22, 0.13)
@export var foliage_color := Color(0.24, 0.43, 0.25)
@export var rock_color := Color(0.48, 0.46, 0.42)
@export var landmark_color := Color(0.48, 0.36, 0.62)

@onready var player: CharacterBody3D = get_node(player_path)

var active_chunks: Dictionary = {}
var current_chunk := Vector2i.ZERO

var terrain_noise: FastNoiseLite
var terrain_zero_offset: float = 0.0
var material_a: StandardMaterial3D
var material_b: StandardMaterial3D
var trunk_material: StandardMaterial3D
var foliage_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var landmark_material: StandardMaterial3D
var foliage_materials: Array[StandardMaterial3D] = []
var rock_materials: Array[StandardMaterial3D] = []
var landmark_materials: Array[StandardMaterial3D] = []

var trunk_mesh: CylinderMesh
var foliage_mesh: SphereMesh
var rock_mesh: SphereMesh
var landmark_mesh: BoxMesh
var trunk_shape: CylinderShape3D
var rock_shape: BoxShape3D
var landmark_shape: BoxShape3D

var chunk_prop_counts: Dictionary = {}
var active_prop_count: int = 0
var animated_foliage: Array[Dictionary] = []
var animated_landmarks: Array[Dictionary] = []
var animation_time: float = 0.0


func _ready() -> void:
	create_shared_resources()
	current_chunk = world_to_chunk(player.global_position)
	update_chunks()


func _process(delta: float) -> void:
	var player_chunk := world_to_chunk(player.global_position)
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		update_chunks()

	animation_time += delta
	animate_world_life()


func create_shared_resources() -> void:
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = terrain_seed
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = terrain_scale
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 3
	terrain_noise.fractal_gain = 0.45
	terrain_noise.fractal_lacunarity = 2.0
	terrain_zero_offset = terrain_noise.get_noise_2d(0.0, 0.0) * height_amplitude

	material_a = create_grass_material(grass_color_a)
	material_b = create_grass_material(grass_color_b)
	trunk_material = create_grass_material(trunk_color)
	foliage_material = create_grass_material(foliage_color)
	rock_material = create_grass_material(rock_color)
	landmark_material = create_grass_material(landmark_color)
	foliage_materials = [
		foliage_material,
		create_grass_material(foliage_color.lightened(0.08)),
		create_grass_material(foliage_color.darkened(0.07)),
	]
	rock_materials = [
		rock_material,
		create_grass_material(rock_color.lightened(0.07)),
		create_grass_material(rock_color.lerp(Color(0.42, 0.39, 0.48), 0.35)),
	]
	landmark_materials = [
		create_landmark_material(landmark_color),
		create_landmark_material(Color(0.38, 0.52, 0.7)),
		create_landmark_material(Color(0.63, 0.4, 0.58)),
	]

	trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.35
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = 3.5
	trunk_mesh.radial_segments = 8

	foliage_mesh = SphereMesh.new()
	foliage_mesh.radius = 1.6
	foliage_mesh.height = 3.2
	foliage_mesh.radial_segments = 10
	foliage_mesh.rings = 5

	rock_mesh = SphereMesh.new()
	rock_mesh.radius = 1.1
	rock_mesh.height = 1.4
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 4

	landmark_mesh = BoxMesh.new()
	landmark_mesh.size = Vector3(2.5, 9.0, 2.5)

	trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 3.2

	rock_shape = BoxShape3D.new()
	rock_shape.size = Vector3(1.8, 1.0, 1.8)

	landmark_shape = BoxShape3D.new()
	landmark_shape.size = Vector3(2.5, 9.0, 2.5)


func create_grass_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func create_landmark_material(color: Color) -> StandardMaterial3D:
	var material := create_grass_material(color)
	material.emission_enabled = true
	material.emission = color * 0.55
	material.emission_energy_multiplier = 0.65
	return material


func sample_height(world_x: float, world_z: float) -> float:
	# Every chunk samples the same world-space function. Shared border vertices
	# therefore receive the same height instead of creating cracks.
	return terrain_noise.get_noise_2d(world_x, world_z) * height_amplitude - terrain_zero_offset


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori((world_position.x + chunk_size * 0.5) / chunk_size),
		floori((world_position.z + chunk_size * 0.5) / chunk_size)
	)


func update_chunks() -> void:
	var needed_chunks: Dictionary = {}

	for x in range(current_chunk.x - active_radius, current_chunk.x + active_radius + 1):
		for z in range(current_chunk.y - active_radius, current_chunk.y + active_radius + 1):
			var coordinate := Vector2i(x, z)
			needed_chunks[coordinate] = true
			if not active_chunks.has(coordinate):
				create_chunk(coordinate)

	for coordinate in active_chunks.keys():
		if not needed_chunks.has(coordinate):
			remove_chunk(coordinate)


func create_chunk(coordinate: Vector2i) -> void:
	var chunk := StaticBody3D.new()
	chunk.name = "Chunk_%d_%d" % [coordinate.x, coordinate.y]
	chunk.position = Vector3(
		coordinate.x * chunk_size,
		0.0,
		coordinate.y * chunk_size
	)

	var terrain_mesh := generate_chunk_mesh(coordinate)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = terrain_mesh
	mesh_instance.material_override = material_a if (coordinate.x + coordinate.y) % 2 == 0 else material_b
	chunk.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = terrain_mesh.create_trimesh_shape()
	chunk.add_child(collision)

	var prop_count := create_chunk_props(chunk, coordinate)

	add_child(chunk)
	active_chunks[coordinate] = chunk
	chunk_prop_counts[coordinate] = prop_count
	active_prop_count += prop_count


func create_chunk_props(chunk: StaticBody3D, coordinate: Vector2i) -> int:
	var random := RandomNumberGenerator.new()
	random.seed = get_chunk_prop_seed(coordinate)
	var prop_count := 0
	var placed_positions: Array[Vector2] = []

	for tree_index in range(trees_per_chunk):
		var tree_position := get_random_prop_position(random, coordinate, placed_positions)
		if (
			is_spawn_area_clear(coordinate, tree_position)
			and is_prop_spacing_clear(tree_position, placed_positions)
		):
			create_tree(chunk, tree_position, tree_index, random)
			placed_positions.append(Vector2(tree_position.x, tree_position.z))
			prop_count += 1

			if random.randf() < tree_cluster_chance:
				var companion_position := get_tree_companion_position(
					random,
					coordinate,
					tree_position
				)
				if (
					is_spawn_area_clear(coordinate, companion_position)
					and is_prop_spacing_clear(companion_position, placed_positions, 4.5)
				):
					create_tree(chunk, companion_position, tree_index + 100, random, 0.72)
					placed_positions.append(Vector2(companion_position.x, companion_position.z))
					prop_count += 1

	for rock_index in range(rocks_per_chunk):
		var rock_position := get_random_prop_position(random, coordinate, placed_positions)
		if (
			is_spawn_area_clear(coordinate, rock_position)
			and is_prop_spacing_clear(rock_position, placed_positions)
		):
			create_rock(chunk, rock_position, rock_index, random)
			placed_positions.append(Vector2(rock_position.x, rock_position.z))
			prop_count += 1

	if random.randf() < landmark_chance:
		var landmark_position := get_random_prop_position(random, coordinate, placed_positions)
		if (
			is_spawn_area_clear(coordinate, landmark_position)
			and is_prop_spacing_clear(landmark_position, placed_positions)
		):
			create_landmark(chunk, landmark_position, random)
			placed_positions.append(Vector2(landmark_position.x, landmark_position.z))
			prop_count += 1

	return prop_count


func get_chunk_prop_seed(coordinate: Vector2i) -> int:
	var mixed_seed := prop_seed
	mixed_seed ^= coordinate.x * 73856093
	mixed_seed ^= coordinate.y * 19349663
	return mixed_seed & 0x7fffffff


func get_random_prop_position(
	random: RandomNumberGenerator,
	coordinate: Vector2i,
	placed_positions: Array[Vector2]
) -> Vector3:
	var half_size := chunk_size * 0.5
	var minimum := -half_size + prop_border_margin
	var maximum := half_size - prop_border_margin
	var candidate := Vector3.ZERO

	for _attempt in range(8):
		candidate.x = random.randf_range(minimum, maximum)
		candidate.z = random.randf_range(minimum, maximum)
		var world_x := coordinate.x * chunk_size + candidate.x
		var world_z := coordinate.y * chunk_size + candidate.z
		candidate.y = sample_height(world_x, world_z)
		if is_spawn_area_clear(coordinate, candidate) and is_prop_spacing_clear(candidate, placed_positions):
			return candidate

	return candidate


func get_tree_companion_position(
	random: RandomNumberGenerator,
	coordinate: Vector2i,
	main_position: Vector3
) -> Vector3:
	var angle := random.randf_range(0.0, TAU)
	var distance := random.randf_range(5.0, 8.5)
	var companion := main_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	var half_size := chunk_size * 0.5 - prop_border_margin
	companion.x = clampf(companion.x, -half_size, half_size)
	companion.z = clampf(companion.z, -half_size, half_size)
	companion.y = sample_height(
		coordinate.x * chunk_size + companion.x,
		coordinate.y * chunk_size + companion.z
	)
	return companion


func is_spawn_area_clear(coordinate: Vector2i, local_position: Vector3) -> bool:
	var world_x := coordinate.x * chunk_size + local_position.x
	var world_z := coordinate.y * chunk_size + local_position.z
	return Vector2(world_x, world_z).length() >= spawn_clear_radius


func is_prop_spacing_clear(
	local_position: Vector3,
	placed_positions: Array[Vector2],
	spacing: float = -1.0
) -> bool:
	var required_spacing := minimum_prop_spacing if spacing < 0.0 else spacing
	var candidate := Vector2(local_position.x, local_position.z)
	for placed_position in placed_positions:
		if candidate.distance_to(placed_position) < required_spacing:
			return false
	return true


func create_tree(
	chunk: StaticBody3D,
	base_position: Vector3,
	index: int,
	random: RandomNumberGenerator,
	scale_multiplier: float = 1.0
) -> void:
	var tree_scale := random.randf_range(0.82, 1.28) * scale_multiplier
	var tree := Node3D.new()
	tree.name = "Tree_%d" % index
	tree.position = base_position
	tree.rotation.y = random.randf_range(-PI, PI)
	tree.scale = Vector3.ONE * tree_scale

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.position = Vector3(0.0, 1.75, 0.0)
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_material
	tree.add_child(trunk)

	var foliage := MeshInstance3D.new()
	foliage.name = "Foliage"
	foliage.position = Vector3(0.0, 4.1, 0.0)
	foliage.mesh = foliage_mesh
	foliage.material_override = foliage_materials[random.randi_range(0, foliage_materials.size() - 1)]
	tree.add_child(foliage)
	chunk.add_child(tree)
	animated_foliage.append({
		"node": foliage,
		"phase": random.randf_range(0.0, TAU),
		"strength": random.randf_range(0.018, 0.045),
	})

	var collision := CollisionShape3D.new()
	collision.name = "TreeCollision_%d" % index
	collision.position = base_position + Vector3(0.0, 1.6 * tree_scale, 0.0)
	collision.shape = trunk_shape
	collision.scale = Vector3.ONE * tree_scale
	chunk.add_child(collision)


func create_rock(
	chunk: StaticBody3D,
	base_position: Vector3,
	index: int,
	random: RandomNumberGenerator
) -> void:
	var rock := MeshInstance3D.new()
	var rock_scale := Vector3(
		random.randf_range(0.72, 1.35),
		random.randf_range(0.65, 1.2),
		random.randf_range(0.72, 1.35)
	)
	rock.name = "Rock_%d" % index
	rock.position = base_position + Vector3(0.0, 0.7 * rock_scale.y, 0.0)
	rock.rotation.y = random.randf_range(-PI, PI)
	rock.rotation.z = random.randf_range(-0.12, 0.12)
	rock.scale = rock_scale
	rock.mesh = rock_mesh
	rock.material_override = rock_materials[random.randi_range(0, rock_materials.size() - 1)]
	chunk.add_child(rock)

	var collision := CollisionShape3D.new()
	collision.name = "RockCollision_%d" % index
	collision.position = base_position + Vector3(0.0, 0.5 * rock_scale.y, 0.0)
	collision.shape = rock_shape
	collision.scale = rock_scale
	chunk.add_child(collision)


func create_landmark(
	chunk: StaticBody3D,
	base_position: Vector3,
	random: RandomNumberGenerator
) -> void:
	var landmark_scale := Vector3(
		random.randf_range(0.65, 1.25),
		random.randf_range(1.25, 2.25),
		random.randf_range(0.65, 1.25)
	)
	var landmark := MeshInstance3D.new()
	landmark.name = "Landmark"
	landmark.position = base_position + Vector3(0.0, 4.5 * landmark_scale.y, 0.0)
	landmark.rotation.y = random.randf_range(-PI, PI)
	landmark.scale = landmark_scale
	landmark.mesh = landmark_mesh
	landmark.material_override = landmark_materials[
		random.randi_range(0, landmark_materials.size() - 1)
	]
	chunk.add_child(landmark)
	animated_landmarks.append({
		"node": landmark,
		"phase": random.randf_range(0.0, TAU),
		"base_scale": landmark_scale,
	})

	var collision := CollisionShape3D.new()
	collision.name = "LandmarkCollision"
	collision.position = base_position + Vector3(0.0, 4.5 * landmark_scale.y, 0.0)
	collision.shape = landmark_shape
	collision.scale = landmark_scale
	chunk.add_child(collision)


func animate_world_life() -> void:
	for entry in animated_foliage:
		var foliage: MeshInstance3D = entry["node"] as MeshInstance3D
		var phase: float = float(entry["phase"])
		var strength: float = float(entry["strength"])
		var sway: float = sin(animation_time * 0.7 + phase) * strength
		foliage.rotation = Vector3(sway * 0.55, 0.0, sway)

	for entry in animated_landmarks:
		var landmark: MeshInstance3D = entry["node"] as MeshInstance3D
		var phase: float = float(entry["phase"])
		var pulse: float = 1.0 + sin(animation_time * 0.55 + phase) * 0.035
		var base_scale: Vector3 = entry["base_scale"]
		landmark.scale = Vector3(base_scale.x * pulse, base_scale.y, base_scale.z * pulse)


func generate_chunk_mesh(coordinate: Vector2i) -> ArrayMesh:
	var vertex_count := (grid_resolution + 1) * (grid_resolution + 1)
	var triangle_index_count := grid_resolution * grid_resolution * 6
	var grid_step := chunk_size / float(grid_resolution)
	var half_size := chunk_size * 0.5

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	indices.resize(triangle_index_count)

	# Include one extra sample around the chunk so border normals are calculated
	# from the same neighboring heights as the adjacent chunk.
	var height_field_size := grid_resolution + 3
	var height_field := PackedFloat32Array()
	height_field.resize(height_field_size * height_field_size)

	for sample_z in range(-1, grid_resolution + 2):
		for sample_x in range(-1, grid_resolution + 2):
			var local_x := -half_size + sample_x * grid_step
			var local_z := -half_size + sample_z * grid_step
			var world_x := coordinate.x * chunk_size + local_x
			var world_z := coordinate.y * chunk_size + local_z
			var field_index := (sample_z + 1) * height_field_size + sample_x + 1
			height_field[field_index] = sample_height(world_x, world_z)

	for z in range(grid_resolution + 1):
		for x in range(grid_resolution + 1):
			var vertex_index := z * (grid_resolution + 1) + x
			var field_index := (z + 1) * height_field_size + x + 1
			var local_x := -half_size + x * grid_step
			var local_z := -half_size + z * grid_step
			var height := height_field[field_index]

			vertices[vertex_index] = Vector3(local_x, height, local_z)
			uvs[vertex_index] = Vector2(
				float(x) / grid_resolution,
				float(z) / grid_resolution
			)

			var height_left := height_field[field_index - 1]
			var height_right := height_field[field_index + 1]
			var height_back := height_field[field_index - height_field_size]
			var height_forward := height_field[field_index + height_field_size]
			normals[vertex_index] = Vector3(
				height_left - height_right,
				2.0 * grid_step,
				height_back - height_forward
			).normalized()

	var write_index := 0
	for z in range(grid_resolution):
		for x in range(grid_resolution):
			var top_left := z * (grid_resolution + 1) + x
			var top_right := top_left + 1
			var bottom_left := top_left + grid_resolution + 1
			var bottom_right := bottom_left + 1

			# Godot uses clockwise winding for front faces. This order keeps both
			# the rendered surface and one-sided trimesh collision facing upward.
			indices[write_index] = top_left
			indices[write_index + 1] = top_right
			indices[write_index + 2] = bottom_left
			indices[write_index + 3] = top_right
			indices[write_index + 4] = bottom_right
			indices[write_index + 5] = bottom_left
			write_index += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func remove_chunk(coordinate: Vector2i) -> void:
	var chunk: StaticBody3D = active_chunks[coordinate]
	remove_chunk_animation_entries(chunk)
	active_prop_count -= chunk_prop_counts.get(coordinate, 0)
	chunk_prop_counts.erase(coordinate)
	active_chunks.erase(coordinate)
	chunk.queue_free()


func remove_chunk_animation_entries(chunk: StaticBody3D) -> void:
	for index in range(animated_foliage.size() - 1, -1, -1):
		var foliage: Node = animated_foliage[index]["node"]
		if chunk.is_ancestor_of(foliage):
			animated_foliage.remove_at(index)

	for index in range(animated_landmarks.size() - 1, -1, -1):
		var landmark: Node = animated_landmarks[index]["node"]
		if chunk.is_ancestor_of(landmark):
			animated_landmarks.remove_at(index)


func get_current_chunk_coordinate() -> Vector2i:
	return current_chunk


func get_active_chunk_count() -> int:
	return active_chunks.size()


func get_active_prop_count() -> int:
	return active_prop_count
