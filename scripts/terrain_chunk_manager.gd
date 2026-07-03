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

@export_group("Placeholder Colors")
@export var grass_color_a := Color(0.31, 0.48, 0.25)
@export var grass_color_b := Color(0.28, 0.44, 0.23)

@onready var player: CharacterBody3D = get_node(player_path)

var active_chunks: Dictionary = {}
var current_chunk := Vector2i.ZERO

var terrain_noise: FastNoiseLite
var terrain_zero_offset: float = 0.0
var material_a: StandardMaterial3D
var material_b: StandardMaterial3D


func _ready() -> void:
	create_shared_resources()
	current_chunk = world_to_chunk(player.global_position)
	update_chunks()


func _process(_delta: float) -> void:
	var player_chunk := world_to_chunk(player.global_position)
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		update_chunks()


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


func create_grass_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
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

	add_child(chunk)
	active_chunks[coordinate] = chunk


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
	active_chunks.erase(coordinate)
	chunk.queue_free()


func get_current_chunk_coordinate() -> Vector2i:
	return current_chunk


func get_active_chunk_count() -> int:
	return active_chunks.size()
