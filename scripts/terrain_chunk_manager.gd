extends Node3D

@export_group("Chunk Streaming")
@export var player_path: NodePath
@export var chunk_size: float = 160.0
@export_range(1, 4, 1) var active_radius: int = 2
@export var chunk_thickness: float = 2.0

@export_group("Placeholder Colors")
@export var grass_color_a := Color(0.31, 0.48, 0.25)
@export var grass_color_b := Color(0.28, 0.44, 0.23)

@onready var player: CharacterBody3D = get_node(player_path)

var active_chunks: Dictionary = {}
var current_chunk := Vector2i.ZERO

var chunk_mesh: BoxMesh
var chunk_shape: BoxShape3D
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
	chunk_mesh = BoxMesh.new()
	chunk_mesh.size = Vector3(chunk_size, chunk_thickness, chunk_size)

	chunk_shape = BoxShape3D.new()
	chunk_shape.size = Vector3(chunk_size, chunk_thickness, chunk_size)

	material_a = create_grass_material(grass_color_a)
	material_b = create_grass_material(grass_color_b)


func create_grass_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


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
		-chunk_thickness * 0.5,
		coordinate.y * chunk_size
	)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = chunk_mesh
	mesh_instance.material_override = material_a if (coordinate.x + coordinate.y) % 2 == 0 else material_b
	chunk.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = chunk_shape
	chunk.add_child(collision)

	add_child(chunk)
	active_chunks[coordinate] = chunk


func remove_chunk(coordinate: Vector2i) -> void:
	var chunk: StaticBody3D = active_chunks[coordinate]
	active_chunks.erase(coordinate)
	chunk.queue_free()


func get_current_chunk_coordinate() -> Vector2i:
	return current_chunk


func get_active_chunk_count() -> int:
	return active_chunks.size()
