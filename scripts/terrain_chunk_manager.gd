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

@export_group("Natural Launch Terrain")
@export_range(0.0, 12.0, 0.5) var launch_height_amplitude: float = 6.5
@export_range(0.0005, 0.004, 0.0001) var launch_region_scale: float = 0.0013
@export_range(0.001, 0.008, 0.0001) var launch_shape_scale: float = 0.0032
@export_range(0.0, 0.8, 0.01) var launch_region_threshold: float = 0.34

@export_group("Nature Props")
@export_range(0, 8, 1) var trees_per_chunk: int = 2
@export_range(0, 8, 1) var rocks_per_chunk: int = 1
@export_range(0.0, 1.0, 0.01) var landmark_chance: float = 0.1
@export_range(0.0, 0.5, 0.01) var tree_cluster_chance: float = 0.22
@export var prop_seed: int = 4242
@export var prop_border_margin: float = 14.0
@export var minimum_prop_spacing: float = 12.0
@export var spawn_clear_radius: float = 55.0

@export_group("Passive Story Traces")
@export var atmosphere_path: NodePath
@export_range(0.0, 0.2, 0.005) var passive_trace_spawn_chance: float = 0.05
# Optional testing multiplier. Keep at 1.0 for normal sparse density;
# generation remains capped at one trace per chunk.
@export_range(1.0, 10.0, 0.5) var passive_trace_test_multiplier: float = 1.0
@export var passive_trace_min_distance: float = 28.0

@export_group("Giant Revelation Landmarks")
@export_range(2, 8, 1) var giant_region_size: int = 4
@export_range(0.0, 1.0, 0.05) var giant_region_chance: float = 0.5
@export var giant_start_clear_radius: float = 220.0
@export var giant_prop_clearance: float = 60.0
@export var guarantee_nearby_test_ring: bool = true
@export var guaranteed_ring_chunk: Vector2i = Vector2i(2, 0)
@export_range(3, 10, 1) var far_landmark_radius: int = 6

@export_group("Tree Scale Tuning")
@export_range(3.0, 15.0, 0.5) var min_tree_height: float = 5.0
@export_range(80.0, 200.0, 5.0) var max_giant_tree_height: float = 140.0
@export_range(0.25, 0.6, 0.01) var large_tree_height_ratio: float = 0.42
@export_range(0.05, 0.6, 0.01) var giant_tree_chance: float = 0.25
@export_range(0.0, 0.5, 0.01) var world_tree_chance: float = 0.18

@export_group("Stone Scale Tuning")
@export_range(40.0, 120.0, 5.0) var min_pillar_height: float = 80.0
@export_range(80.0, 180.0, 5.0) var max_pillar_height: float = 140.0
@export_range(80.0, 160.0, 5.0) var min_monolith_height: float = 110.0
@export_range(120.0, 220.0, 5.0) var max_monolith_height: float = 180.0
@export_range(0.0, 0.2, 0.01) var large_boulder_chance: float = 0.06
@export_range(0.0, 0.1, 0.005) var monumental_boulder_chance: float = 0.01
@export_range(25.0, 80.0, 5.0) var max_monumental_boulder_height: float = 55.0

@export_group("World Material Palette")
@export var grass_color_a := Color(0.3, 0.39, 0.27)
@export var grass_color_b := Color(0.27, 0.36, 0.25)
@export var trunk_color := Color(0.3, 0.24, 0.19)
@export var foliage_color := Color(0.29, 0.38, 0.28)
@export var rock_color := Color(0.45, 0.43, 0.4)
@export var landmark_color := Color(0.4, 0.43, 0.49)

@onready var player: CharacterBody3D = get_node(player_path)
@onready var atmosphere: Node = get_node_or_null(atmosphere_path)

var active_chunks: Dictionary = {}
var far_landmark_proxies: Dictionary = {}
var current_chunk := Vector2i.ZERO

var terrain_noise: FastNoiseLite
var terrain_zero_offset: float = 0.0
var launch_region_noise: FastNoiseLite
var launch_shape_noise: FastNoiseLite
var launch_zero_offset: float = 0.0
var material_a: StandardMaterial3D
var material_b: StandardMaterial3D
var trunk_material: StandardMaterial3D
var foliage_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var landmark_material: StandardMaterial3D
var pale_stone_material: StandardMaterial3D
var dark_stone_material: StandardMaterial3D
var faded_ring_material: StandardMaterial3D
var trace_material: StandardMaterial3D
var trace_dark_material: StandardMaterial3D
var trace_light_material: StandardMaterial3D
var trace_memory_material: StandardMaterial3D
var trace_dust_material: StandardMaterial3D
var trace_dead_material: StandardMaterial3D
var trace_liminal_material: StandardMaterial3D
var trace_liminal_light_material: StandardMaterial3D
var landmark_dimension_materials: Dictionary = {}
var foliage_materials: Array[StandardMaterial3D] = []
var rock_materials: Array[StandardMaterial3D] = []
var landmark_materials: Array[StandardMaterial3D] = []

var trunk_mesh: CylinderMesh
var foliage_mesh: SphereMesh
var rock_mesh: SphereMesh
var landmark_mesh: BoxMesh
var giant_trunk_mesh: CylinderMesh
var giant_canopy_mesh: SphereMesh
var giant_pillar_mesh: BoxMesh
var giant_monolith_mesh: BoxMesh
var giant_ring_mesh: TorusMesh
var giant_inner_ring_mesh: TorusMesh
var trace_box_mesh: BoxMesh
var trace_pole_mesh: CylinderMesh
var trace_light_mesh: SphereMesh
var trunk_shape: CylinderShape3D
var rock_shape: BoxShape3D
var landmark_shape: BoxShape3D
var giant_trunk_shape: CylinderShape3D
var giant_pillar_shape: BoxShape3D
var giant_monolith_shape: BoxShape3D

var chunk_prop_counts: Dictionary = {}
var chunk_giant_counts: Dictionary = {}
var active_prop_count: int = 0
var active_giant_landmark_count: int = 0
var animated_foliage: Array[Dictionary] = []
var animated_landmarks: Array[Dictionary] = []
var story_traces: Array[Node3D] = []
var dimension_landmarks: Array[Dictionary] = []
var current_dimension_id: StringName = &"pale_dawn"
var animation_time: float = 0.0


func _ready() -> void:
	create_shared_resources()
	if atmosphere != null:
		atmosphere.connect("dimension_changed", _on_dimension_changed)
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

	launch_region_noise = FastNoiseLite.new()
	launch_region_noise.seed = terrain_seed + 271
	launch_region_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	launch_region_noise.frequency = launch_region_scale
	launch_region_noise.fractal_octaves = 2
	launch_region_noise.fractal_gain = 0.4

	launch_shape_noise = FastNoiseLite.new()
	launch_shape_noise.seed = terrain_seed + 619
	launch_shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	launch_shape_noise.frequency = launch_shape_scale
	launch_shape_noise.fractal_octaves = 2
	launch_shape_noise.fractal_gain = 0.35
	launch_zero_offset = get_launch_height(0.0, 0.0)

	material_a = create_grass_material(grass_color_a)
	material_b = create_grass_material(grass_color_b)
	trunk_material = create_grass_material(trunk_color)
	foliage_material = create_grass_material(foliage_color)
	rock_material = create_grass_material(rock_color)
	landmark_material = create_grass_material(landmark_color)
	pale_stone_material = create_grass_material(Color(0.57, 0.55, 0.5))
	dark_stone_material = create_grass_material(Color(0.28, 0.3, 0.31))
	faded_ring_material = create_grass_material(Color(0.63, 0.62, 0.57))
	faded_ring_material.emission_enabled = true
	faded_ring_material.emission = Color(0.34, 0.32, 0.26)
	faded_ring_material.emission_energy_multiplier = 0.14
	trace_material = create_grass_material(Color(0.31, 0.29, 0.25))
	trace_dark_material = create_grass_material(Color(0.19, 0.19, 0.18))
	trace_light_material = create_landmark_material(Color(0.78, 0.58, 0.3))
	trace_light_material.emission_energy_multiplier = 0.75
	trace_memory_material = create_trace_material(Color(0.5, 0.39, 0.25), Color(0.34, 0.2, 0.08), 0.16)
	trace_dust_material = create_trace_material(Color(0.36, 0.31, 0.25), Color(0.18, 0.12, 0.07), 0.06)
	trace_dead_material = create_trace_material(Color(0.28, 0.33, 0.36), Color(0.1, 0.16, 0.2), 0.12)
	trace_liminal_material = create_trace_material(Color(0.075, 0.085, 0.12), Color(0.08, 0.12, 0.22), 0.2)
	trace_liminal_light_material = create_trace_material(Color(0.2, 0.3, 0.48), Color(0.24, 0.42, 0.8), 0.5)
	create_landmark_dimension_materials()
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
		create_landmark_material(Color(0.4, 0.49, 0.56)),
		create_landmark_material(Color(0.53, 0.46, 0.47)),
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

	giant_trunk_mesh = CylinderMesh.new()
	giant_trunk_mesh.top_radius = 2.4
	giant_trunk_mesh.bottom_radius = 3.8
	giant_trunk_mesh.height = 62.0
	giant_trunk_mesh.radial_segments = 10

	giant_canopy_mesh = SphereMesh.new()
	giant_canopy_mesh.radius = 18.0
	giant_canopy_mesh.height = 30.0
	giant_canopy_mesh.radial_segments = 12
	giant_canopy_mesh.rings = 6

	giant_pillar_mesh = BoxMesh.new()
	giant_pillar_mesh.size = Vector3(7.0, 120.0, 7.0)

	giant_monolith_mesh = BoxMesh.new()
	giant_monolith_mesh.size = Vector3(14.0, 90.0, 9.0)

	giant_ring_mesh = TorusMesh.new()
	giant_ring_mesh.inner_radius = 54.0
	giant_ring_mesh.outer_radius = 60.0
	giant_ring_mesh.rings = 48
	giant_ring_mesh.ring_segments = 10

	giant_inner_ring_mesh = TorusMesh.new()
	giant_inner_ring_mesh.inner_radius = 45.0
	giant_inner_ring_mesh.outer_radius = 48.0
	giant_inner_ring_mesh.rings = 40
	giant_inner_ring_mesh.ring_segments = 8

	trace_box_mesh = BoxMesh.new()
	trace_box_mesh.size = Vector3.ONE

	trace_pole_mesh = CylinderMesh.new()
	trace_pole_mesh.top_radius = 0.5
	trace_pole_mesh.bottom_radius = 0.65
	trace_pole_mesh.height = 1.0
	trace_pole_mesh.radial_segments = 6

	trace_light_mesh = SphereMesh.new()
	trace_light_mesh.radius = 0.5
	trace_light_mesh.height = 1.0
	trace_light_mesh.radial_segments = 8
	trace_light_mesh.rings = 4

	trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 3.2

	rock_shape = BoxShape3D.new()
	rock_shape.size = Vector3(1.8, 1.0, 1.8)

	landmark_shape = BoxShape3D.new()
	landmark_shape.size = Vector3(2.5, 9.0, 2.5)

	giant_trunk_shape = CylinderShape3D.new()
	giant_trunk_shape.radius = 3.4
	giant_trunk_shape.height = 62.0

	giant_pillar_shape = BoxShape3D.new()
	giant_pillar_shape.size = Vector3(7.0, 120.0, 7.0)

	giant_monolith_shape = BoxShape3D.new()
	giant_monolith_shape.size = Vector3(14.0, 90.0, 9.0)


func create_grass_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func create_landmark_material(color: Color) -> StandardMaterial3D:
	var material := create_grass_material(color)
	material.emission_enabled = true
	material.emission = color * 0.4
	material.emission_energy_multiplier = 0.38
	return material


func create_trace_material(
	albedo: Color,
	emission: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := create_grass_material(albedo)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	return material


func create_landmark_dimension_materials() -> void:
	landmark_dimension_materials = {
		&"pale_dawn": create_landmark_material_profile(
			Color(0.3, 0.24, 0.19), Color(0.29, 0.38, 0.28),
			Color(0.57, 0.55, 0.5), Color(0.28, 0.3, 0.31),
			Color(0.63, 0.62, 0.57), Color(0.34, 0.32, 0.26), 0.14
		),
		&"cold_overcast": create_landmark_material_profile(
			Color(0.17, 0.18, 0.19), Color(0.18, 0.22, 0.23),
			Color(0.38, 0.42, 0.45), Color(0.12, 0.15, 0.18),
			Color(0.48, 0.56, 0.66), Color(0.24, 0.4, 0.62), 0.32
		),
		&"golden_dissolve": create_landmark_material_profile(
			Color(0.38, 0.28, 0.18), Color(0.42, 0.43, 0.25),
			Color(0.65, 0.55, 0.4), Color(0.42, 0.34, 0.26),
			Color(0.76, 0.58, 0.3), Color(0.72, 0.42, 0.16), 0.38
		),
		&"blue_liminal_night": create_landmark_material_profile(
			Color(0.08, 0.1, 0.14), Color(0.1, 0.17, 0.22),
			Color(0.25, 0.32, 0.45), Color(0.1, 0.13, 0.22),
			Color(0.42, 0.62, 0.92), Color(0.3, 0.52, 1.0), 0.75
		),
		&"dust_haze_afternoon": create_landmark_material_profile(
			Color(0.29, 0.24, 0.18), Color(0.33, 0.31, 0.23),
			Color(0.48, 0.42, 0.34), Color(0.23, 0.21, 0.18),
			Color(0.58, 0.48, 0.36), Color(0.34, 0.25, 0.16), 0.18
		),
	}


func create_landmark_material_profile(
	trunk_color: Color,
	canopy_color: Color,
	pillar_color: Color,
	monolith_color: Color,
	ring_color: Color,
	ring_emission: Color,
	ring_energy: float
) -> Dictionary:
	var ring_material := create_grass_material(ring_color)
	ring_material.emission_enabled = true
	ring_material.emission = ring_emission
	ring_material.emission_energy_multiplier = ring_energy
	return {
		&"tree_trunk": create_grass_material(trunk_color),
		&"tree_canopy": create_grass_material(canopy_color),
		&"pillar": create_grass_material(pillar_color),
		&"monolith": create_grass_material(monolith_color),
		&"ring": ring_material,
	}


func sample_height(world_x: float, world_z: float) -> float:
	# Every chunk samples the same world-space function. Shared border vertices
	# therefore receive the same height instead of creating cracks.
	var rolling_height: float = (
		terrain_noise.get_noise_2d(world_x, world_z) * height_amplitude
		- terrain_zero_offset
	)
	return rolling_height + get_launch_height(world_x, world_z) - launch_zero_offset


func get_launch_height(world_x: float, world_z: float) -> float:
	# Low-frequency gating leaves long quiet passages between launch terrain.
	# A soft ridged field creates broad shelves, lips, and valley edges without
	# introducing geometric ramps or discontinuities at chunk borders.
	var region_value: float = launch_region_noise.get_noise_2d(world_x, world_z)
	var region_mask: float = smoothstep(
		launch_region_threshold,
		minf(launch_region_threshold + 0.36, 0.98),
		region_value
	)
	if region_mask <= 0.0:
		return 0.0
	var shape_value: float = launch_shape_noise.get_noise_2d(world_x, world_z)
	var ridge: float = 1.0 - absf(shape_value)
	var broad_rise: float = smoothstep(0.28, 0.92, ridge)
	var wind_lean: float = shape_value * 0.22 + 0.78
	return broad_rise * wind_lean * region_mask * launch_height_amplitude


func get_launch_terrain_influence(world_position: Vector3) -> float:
	if launch_height_amplitude <= 0.0:
		return 0.0
	return clampf(
		get_launch_height(world_position.x, world_position.z) / launch_height_amplitude,
		0.0,
		1.0
	)


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

	update_far_landmark_proxies()


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

	var generated_counts: Vector2i = create_chunk_props(chunk, coordinate)
	var prop_count: int = generated_counts.x
	var giant_count: int = generated_counts.y

	add_child(chunk)
	active_chunks[coordinate] = chunk
	chunk_prop_counts[coordinate] = prop_count
	chunk_giant_counts[coordinate] = giant_count
	active_prop_count += prop_count
	active_giant_landmark_count += giant_count


func create_chunk_props(chunk: StaticBody3D, coordinate: Vector2i) -> Vector2i:
	var random := RandomNumberGenerator.new()
	random.seed = get_chunk_prop_seed(coordinate)
	var prop_count := 0
	var giant_count := 0
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
					and is_prop_spacing_clear(companion_position, placed_positions, 5.0)
				):
					create_tree(chunk, companion_position, tree_index + 100, random, 0.72)
					placed_positions.append(Vector2(companion_position.x, companion_position.z))
					prop_count += 1

	for rock_index in range(rocks_per_chunk):
		var rock_size: float = get_rock_scale(random)
		var rock_height: float = rock_size * 1.4
		var rock_position: Vector3
		if rock_height >= 8.0:
			rock_position = get_large_rock_position(
				random,
				coordinate,
				placed_positions,
				rock_height
			)
		else:
			rock_position = get_random_prop_position(random, coordinate, placed_positions)

		if rock_position != Vector3.INF and (
			is_spawn_area_clear(coordinate, rock_position)
			and is_prop_spacing_clear(rock_position, placed_positions)
		):
			create_rock(chunk, rock_position, rock_index, random, rock_size)
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

	var passive_trace_chance := minf(
		passive_trace_spawn_chance * passive_trace_test_multiplier,
		1.0
	)
	if random.randf() < passive_trace_chance:
		var trace_position := get_random_prop_position(random, coordinate, placed_positions)
		if (
			is_spawn_area_clear(coordinate, trace_position)
			and is_prop_spacing_clear(trace_position, placed_positions, passive_trace_min_distance)
		):
			create_story_trace(chunk, trace_position, random)
			placed_positions.append(Vector2(trace_position.x, trace_position.z))
			prop_count += 1

	if is_giant_landmark_chunk(coordinate):
		var force_placement: bool = is_guaranteed_ring_chunk(coordinate)
		var giant_random: RandomNumberGenerator = create_giant_instance_random(coordinate)
		var no_reserved_positions: Array[Vector2] = []
		var giant_position: Vector3 = get_giant_landmark_position(
			giant_random,
			coordinate,
			no_reserved_positions,
			force_placement
		)
		if giant_position != Vector3.INF:
			create_giant_landmark(chunk, giant_position, giant_random, coordinate)
			prop_count += 1
			giant_count = 1

	return Vector2i(prop_count, giant_count)


func create_story_trace(
	chunk: StaticBody3D,
	base_position: Vector3,
	random: RandomNumberGenerator
) -> void:
	var trace := Node3D.new()
	trace.position = base_position
	trace.rotation.y = random.randf_range(-PI, PI)

	var trace_kind := random.randi_range(0, 2)
	match trace_kind:
		0:
			trace.name = "StoryTrace_RoadsideShelter"
			trace.set_meta("trace_kind", &"shelter")
			build_roadside_shelter(trace)
		1:
			trace.name = "StoryTrace_DeadUtilityPole"
			trace.set_meta("trace_kind", &"utility_pole")
			build_dead_utility_pole(trace)
		_:
			trace.name = "StoryTrace_RuinedFrame"
			trace.set_meta("trace_kind", &"ruined_frame")
			build_ruined_frame(trace)

	# These first traces are intentionally non-colliding. Their narrow pieces
	# would create high-speed snag points without adding useful traversal choices.
	chunk.add_child(trace)
	story_traces.append(trace)
	update_story_trace_visibility(trace)


func build_roadside_shelter(trace: Node3D) -> void:
	# A broad platform, open front, bench, and separate route marker make this
	# read as a forgotten travel stop rather than an abstract stack of slabs.
	add_trace_box(trace, Vector3(0.0, 0.12, 0.0), Vector3(8.4, 0.24, 3.1), trace_dark_material)
	add_trace_box(trace, Vector3(0.0, 2.25, 1.05), Vector3(7.2, 4.1, 0.3), trace_material)
	add_trace_box(trace, Vector3(0.0, 4.48, 0.0), Vector3(8.0, 0.34, 2.8), trace_dark_material)
	add_trace_box(trace, Vector3(-3.55, 2.2, 0.2), Vector3(0.32, 4.0, 1.9), trace_dark_material)
	add_trace_box(trace, Vector3(3.55, 2.2, 0.2), Vector3(0.32, 4.0, 1.9), trace_dark_material)
	add_trace_box(trace, Vector3(0.5, 0.68, 0.25), Vector3(4.4, 0.34, 0.78), trace_material)
	add_trace_box(trace, Vector3(-1.0, 0.38, 0.25), Vector3(0.22, 0.55, 0.55), trace_dark_material)
	add_trace_box(trace, Vector3(2.0, 0.38, 0.25), Vector3(0.22, 0.55, 0.55), trace_dark_material)
	add_trace_box(trace, Vector3(4.35, 1.6, 0.4), Vector3(0.22, 3.2, 0.22), trace_dark_material, 0.035)
	add_trace_box(trace, Vector3(4.25, 3.18, 0.4), Vector3(1.0, 0.72, 0.2), trace_material, -0.08)
	var light := MeshInstance3D.new()
	light.name = "MemoryLight"
	light.position = Vector3(2.45, 3.55, 0.78)
	light.scale = Vector3.ONE * 0.32
	light.mesh = trace_light_mesh
	light.material_override = trace_light_material
	light.set_meta("trace_light", true)
	trace.add_child(light)


func build_dead_utility_pole(trace: Node3D) -> void:
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	pole.position = Vector3(0.0, 4.8, 0.0)
	pole.rotation.z = 0.035
	pole.scale = Vector3(0.44, 9.6, 0.44)
	pole.mesh = trace_pole_mesh
	pole.material_override = trace_dark_material
	pole.set_meta("dark_part", true)
	trace.add_child(pole)
	# Twin crossarms, insulators, and short broken drops preserve the dead-line
	# silhouette without drawing long wires across streamed chunks.
	add_trace_box(trace, Vector3(0.0, 8.65, 0.0), Vector3(5.6, 0.3, 0.34), trace_dark_material)
	add_trace_box(trace, Vector3(0.0, 7.92, 0.0), Vector3(3.5, 0.24, 0.3), trace_dark_material)
	for insulator_x in [-2.05, 0.0, 2.05]:
		add_trace_box(
			trace, Vector3(insulator_x, 8.98, 0.0), Vector3(0.24, 0.65, 0.24), trace_material
		)
	add_trace_box(trace, Vector3(-2.15, 7.72, 0.0), Vector3(0.09, 1.35, 0.09), trace_dark_material, 0.12)
	add_trace_box(trace, Vector3(2.15, 7.78, 0.0), Vector3(0.09, 1.2, 0.09), trace_dark_material, -0.16)
	add_trace_box(trace, Vector3(2.15, 1.35, 0.35), Vector3(0.3, 2.7, 0.3), trace_material, -0.16)
	add_trace_box(trace, Vector3(1.95, 2.55, 0.35), Vector3(1.15, 0.78, 0.22), trace_material, -0.22)


func build_ruined_frame(trace: Node3D) -> void:
	# The platform and broken wall make this feel like a stripped roadside room
	# or station remnant, rather than a freestanding fantasy arch.
	add_trace_box(trace, Vector3(0.0, 0.13, 0.0), Vector3(7.4, 0.26, 2.4), trace_dark_material)
	add_trace_box(trace, Vector3(-2.8, 2.6, 0.0), Vector3(0.5, 5.2, 0.7), trace_material, -0.04)
	add_trace_box(trace, Vector3(2.8, 1.85, 0.0), Vector3(0.5, 3.7, 0.7), trace_material, 0.08)
	add_trace_box(trace, Vector3(-0.45, 5.05, 0.0), Vector3(5.2, 0.45, 0.7), trace_material, -0.06)
	add_trace_box(trace, Vector3(-1.85, 1.65, 0.0), Vector3(1.7, 2.7, 0.5), trace_material, -0.025)
	add_trace_box(trace, Vector3(1.1, 1.0, 0.0), Vector3(2.7, 0.32, 0.58), trace_material, 0.04)
	add_trace_box(trace, Vector3(-0.2, 4.45, 0.05), Vector3(1.5, 0.48, 0.22), trace_dark_material, -0.08)
	add_trace_box(trace, Vector3(1.75, 0.35, 0.0), Vector3(2.4, 0.7, 0.8), trace_dark_material, 0.12)


func add_trace_box(
	parent: Node3D,
	position: Vector3,
	size: Vector3,
	material: StandardMaterial3D,
	z_rotation: float = 0.0
) -> void:
	var part := MeshInstance3D.new()
	part.position = position
	part.rotation.z = z_rotation
	part.scale = size
	part.mesh = trace_box_mesh
	part.material_override = material
	part.set_meta("dark_part", material == trace_dark_material)
	parent.add_child(part)


func _on_dimension_changed(dimension_id: StringName, _display_name: String) -> void:
	current_dimension_id = dimension_id
	for trace in story_traces:
		if is_instance_valid(trace):
			update_story_trace_visibility(trace)
	update_dimension_landmarks()


func update_story_trace_visibility(trace: Node3D) -> void:
	var trace_kind: StringName = trace.get_meta("trace_kind", &"")
	trace.visible = true
	trace.scale = Vector3.ONE

	match current_dimension_id:
		&"pale_dawn":
			# Ordinary matter: present, restrained, and without a guiding light.
			trace.scale = Vector3.ONE * 0.96
			apply_story_trace_materials(trace, trace_material, trace_dark_material, null)
		&"golden_dissolve":
			trace.visible = trace_kind == &"shelter"
			trace.scale = Vector3.ONE * 1.03
			apply_story_trace_materials(
				trace, trace_memory_material, trace_memory_material, trace_light_material
			)
		&"dust_haze_afternoon":
			trace.visible = trace_kind == &"utility_pole"
			apply_story_trace_materials(trace, trace_dust_material, trace_dust_material, null)
		&"cold_overcast":
			trace.visible = trace_kind == &"ruined_frame"
			trace.scale = Vector3.ONE * 0.98
			apply_story_trace_materials(trace, trace_dead_material, trace_dead_material, null)
		&"blue_liminal_night":
			# Night reveals every trace as a near-silhouette; shelter lights become cold omens.
			trace.scale = Vector3.ONE * 1.02
			apply_story_trace_materials(
				trace, trace_liminal_material, trace_liminal_material, trace_liminal_light_material
			)


func apply_story_trace_materials(
	trace: Node3D,
	main_material: StandardMaterial3D,
	dark_material: StandardMaterial3D,
	light_material: StandardMaterial3D
) -> void:
	for child in trace.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		if bool(mesh.get_meta("trace_light", false)):
			mesh.visible = light_material != null
			if light_material != null:
				mesh.material_override = light_material
		elif bool(mesh.get_meta("dark_part", false)):
			mesh.visible = true
			mesh.material_override = dark_material
		else:
			mesh.visible = true
			mesh.material_override = main_material


func register_dimension_landmark(
	root: Node3D,
	landmark_type: StringName,
	meshes: Array
) -> void:
	dimension_landmarks.append({
		"root": root,
		"type": landmark_type,
		"meshes": meshes,
	})
	apply_dimension_landmark_materials(dimension_landmarks.back())


func update_dimension_landmarks() -> void:
	for index in range(dimension_landmarks.size() - 1, -1, -1):
		var entry: Dictionary = dimension_landmarks[index]
		if not is_instance_valid(entry["root"]):
			dimension_landmarks.remove_at(index)
			continue
		apply_dimension_landmark_materials(entry)


func apply_dimension_landmark_materials(entry: Dictionary) -> void:
	var profile: Dictionary = landmark_dimension_materials.get(
		current_dimension_id,
		landmark_dimension_materials[&"pale_dawn"]
	)
	var landmark_type: StringName = entry["type"]
	var meshes: Array = entry["meshes"]
	match landmark_type:
		&"giant_tree":
			for mesh_index in range(meshes.size()):
				var role: StringName = &"tree_trunk" if mesh_index == 0 else &"tree_canopy"
				(meshes[mesh_index] as MeshInstance3D).material_override = profile[role]
		&"pillar":
			for mesh in meshes:
				(mesh as MeshInstance3D).material_override = profile[&"pillar"]
		&"monolith":
			for mesh in meshes:
				(mesh as MeshInstance3D).material_override = profile[&"monolith"]
		&"ring":
			for mesh in meshes:
				(mesh as MeshInstance3D).material_override = profile[&"ring"]


func remove_dimension_landmarks_under(owner: Node) -> void:
	for index in range(dimension_landmarks.size() - 1, -1, -1):
		var root: Node = dimension_landmarks[index]["root"]
		if not is_instance_valid(root) or root == owner or owner.is_ancestor_of(root):
			dimension_landmarks.remove_at(index)


func get_chunk_prop_seed(coordinate: Vector2i) -> int:
	var mixed_seed := prop_seed
	mixed_seed ^= coordinate.x * 73856093
	mixed_seed ^= coordinate.y * 19349663
	return mixed_seed & 0x7fffffff


func create_giant_instance_random(coordinate: Vector2i) -> RandomNumberGenerator:
	var giant_random := RandomNumberGenerator.new()
	giant_random.seed = get_chunk_prop_seed(coordinate) ^ 0x6D2B79
	return giant_random


func is_giant_landmark_chunk(coordinate: Vector2i) -> bool:
	if is_guaranteed_ring_chunk(coordinate):
		return true

	var region := Vector2i(
		floori(float(coordinate.x) / giant_region_size),
		floori(float(coordinate.y) / giant_region_size)
	)
	var region_random := RandomNumberGenerator.new()
	region_random.seed = get_chunk_prop_seed(region) ^ 0x35A71C
	if region_random.randf() > giant_region_chance:
		return false

	var anchor := Vector2i(
		region.x * giant_region_size + region_random.randi_range(0, giant_region_size - 1),
		region.y * giant_region_size + region_random.randi_range(0, giant_region_size - 1)
	)
	return coordinate == anchor


func is_guaranteed_ring_chunk(coordinate: Vector2i) -> bool:
	return guarantee_nearby_test_ring and coordinate == guaranteed_ring_chunk


func update_far_landmark_proxies() -> void:
	var needed_proxies: Dictionary = {}
	for x in range(current_chunk.x - far_landmark_radius, current_chunk.x + far_landmark_radius + 1):
		for z in range(current_chunk.y - far_landmark_radius, current_chunk.y + far_landmark_radius + 1):
			var coordinate := Vector2i(x, z)
			if is_coordinate_in_active_radius(coordinate):
				continue
			if not is_giant_landmark_chunk(coordinate):
				continue
			needed_proxies[coordinate] = true
			if not far_landmark_proxies.has(coordinate):
				create_far_landmark_proxy(coordinate)

	for coordinate in far_landmark_proxies.keys():
		if not needed_proxies.has(coordinate):
			var proxy: Node3D = far_landmark_proxies[coordinate]
			remove_dimension_landmarks_under(proxy)
			far_landmark_proxies.erase(coordinate)
			proxy.queue_free()


func is_coordinate_in_active_radius(coordinate: Vector2i) -> bool:
	return (
		absi(coordinate.x - current_chunk.x) <= active_radius
		and absi(coordinate.y - current_chunk.y) <= active_radius
	)


func create_far_landmark_proxy(coordinate: Vector2i) -> void:
	var giant_random: RandomNumberGenerator = create_giant_instance_random(coordinate)
	var no_reserved_positions: Array[Vector2] = []
	var giant_position: Vector3 = get_giant_landmark_position(
		giant_random,
		coordinate,
		no_reserved_positions,
		is_guaranteed_ring_chunk(coordinate)
	)
	if giant_position == Vector3.INF:
		return

	var proxy := Node3D.new()
	proxy.name = "FarLandmark_%d_%d" % [coordinate.x, coordinate.y]
	proxy.position = Vector3(coordinate.x * chunk_size, 0.0, coordinate.y * chunk_size)
	add_child(proxy)
	create_giant_landmark(proxy, giant_position, giant_random, coordinate, false)
	far_landmark_proxies[coordinate] = proxy


func get_giant_landmark_position(
	random: RandomNumberGenerator,
	coordinate: Vector2i,
	placed_positions: Array[Vector2],
	force_placement: bool = false
) -> Vector3:
	var half_size: float = chunk_size * 0.5
	var placement_margin: float = 32.0
	var best_position := Vector3.INF
	var best_score: float = -INF

	for _attempt in range(18):
		var candidate := Vector3(
			random.randf_range(-half_size + placement_margin, half_size - placement_margin),
			0.0,
			random.randf_range(-half_size + placement_margin, half_size - placement_margin)
		)
		var world_x: float = coordinate.x * chunk_size + candidate.x
		var world_z: float = coordinate.y * chunk_size + candidate.z
		candidate.y = sample_height(world_x, world_z)

		if Vector2(world_x, world_z).length() < giant_start_clear_radius:
			continue
		if not is_prop_spacing_clear(candidate, placed_positions, giant_prop_clearance):
			continue
		if not is_giant_site_suitable(world_x, world_z, candidate.y):
			continue

		var ridge_score: float = get_ridge_score(world_x, world_z, candidate.y)
		if ridge_score > best_score:
			best_score = ridge_score
			best_position = candidate

	if best_position != Vector3.INF or not force_placement:
		return best_position

	# The guaranteed test ring has no collision. If the ridge search is rejected,
	# keep it visible by falling back to the center of its streamed chunk.
	var fallback := Vector3.ZERO
	var fallback_world_x: float = coordinate.x * chunk_size
	var fallback_world_z: float = coordinate.y * chunk_size
	fallback.y = sample_height(fallback_world_x, fallback_world_z)
	return fallback


func is_giant_site_suitable(world_x: float, world_z: float, center_height: float) -> bool:
	var sample_offset: float = 10.0
	var maximum_height_change: float = 5.0
	var offsets: Array[Vector2] = [
		Vector2(sample_offset, 0.0),
		Vector2(-sample_offset, 0.0),
		Vector2(0.0, sample_offset),
		Vector2(0.0, -sample_offset),
	]
	for offset in offsets:
		var nearby_height: float = sample_height(world_x + offset.x, world_z + offset.y)
		if absf(nearby_height - center_height) > maximum_height_change:
			return false
	return true


func get_ridge_score(world_x: float, world_z: float, center_height: float) -> float:
	var sample_offset: float = 24.0
	var surrounding_height: float = (
		sample_height(world_x + sample_offset, world_z)
		+ sample_height(world_x - sample_offset, world_z)
		+ sample_height(world_x, world_z + sample_offset)
		+ sample_height(world_x, world_z - sample_offset)
	) * 0.25
	return center_height - surrounding_height + center_height * 0.08


func get_large_rock_position(
	random: RandomNumberGenerator,
	coordinate: Vector2i,
	placed_positions: Array[Vector2],
	rock_height: float
) -> Vector3:
	var half_size: float = chunk_size * 0.5
	var placement_margin: float = 28.0
	var required_clearance: float = 60.0 if rock_height >= 25.0 else 28.0
	var start_clearance: float = giant_start_clear_radius if rock_height >= 25.0 else 120.0
	var best_position := Vector3.INF
	var best_score: float = -INF

	for _attempt in range(14):
		var candidate := Vector3(
			random.randf_range(-half_size + placement_margin, half_size - placement_margin),
			0.0,
			random.randf_range(-half_size + placement_margin, half_size - placement_margin)
		)
		var world_x: float = coordinate.x * chunk_size + candidate.x
		var world_z: float = coordinate.y * chunk_size + candidate.z
		candidate.y = sample_height(world_x, world_z)
		if Vector2(world_x, world_z).length() < start_clearance:
			continue
		if not is_prop_spacing_clear(candidate, placed_positions, required_clearance):
			continue
		if not is_giant_site_suitable(world_x, world_z, candidate.y):
			continue

		var score: float = get_ridge_score(world_x, world_z, candidate.y)
		if score > best_score:
			best_score = score
			best_position = candidate

	return best_position


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
	var distance := random.randf_range(6.0, 11.0)
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


func create_giant_landmark(
	chunk: Node3D,
	base_position: Vector3,
	random: RandomNumberGenerator,
	coordinate: Vector2i,
	add_collision: bool = true
) -> void:
	var form_type: int
	if is_guaranteed_ring_chunk(coordinate):
		form_type = 3
	elif random.randf() < giant_tree_chance:
		form_type = 0
	else:
		form_type = random.randi_range(1, 3)
	match form_type:
		0:
			create_solitary_giant_tree(chunk, base_position, random, add_collision)
		1:
			create_pale_stone_pillar(chunk, base_position, random, add_collision)
		2:
			create_tilted_monolith(chunk, base_position, random, add_collision)
		_:
			create_horizon_ring(chunk, base_position, random)


func create_solitary_giant_tree(
	chunk: Node3D,
	base_position: Vector3,
	random: RandomNumberGenerator,
	add_collision: bool = true
) -> void:
	var target_height: float = get_revelation_tree_height(random)
	var base_giant_tree_height: float = 88.0
	var giant_tree_scale: float = target_height / base_giant_tree_height
	var giant_tree := Node3D.new()
	giant_tree.name = "Revelation_GiantTree"
	giant_tree.position = base_position
	giant_tree.rotation.y = random.randf_range(-PI, PI)
	giant_tree.scale = Vector3.ONE * giant_tree_scale

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.position.y = 31.0
	trunk.mesh = giant_trunk_mesh
	trunk.material_override = trunk_material
	giant_tree.add_child(trunk)

	var main_canopy := create_giant_canopy(
		"MainCanopy",
		Vector3(0.0, 73.0, 0.0),
		Vector3(1.0, 1.0, 1.0),
		random
	)
	giant_tree.add_child(main_canopy)
	giant_tree.add_child(create_giant_canopy(
		"SideCanopyA",
		Vector3(-11.0, 67.0, 4.0),
		Vector3(0.72, 0.78, 0.72),
		random
	))
	giant_tree.add_child(create_giant_canopy(
		"SideCanopyB",
		Vector3(10.0, 69.0, -5.0),
		Vector3(0.65, 0.72, 0.65),
		random
	))
	giant_tree.add_child(create_giant_canopy(
		"HighCrown",
		Vector3(3.0, 82.0, -2.0),
		Vector3(0.52, 0.64, 0.48),
		random
	))
	giant_tree.add_child(create_giant_canopy(
		"LowerCrown",
		Vector3(-5.0, 58.0, 6.0),
		Vector3(0.58, 0.42, 0.68),
		random
	))
	chunk.add_child(giant_tree)
	var tree_meshes: Array[MeshInstance3D] = [trunk]
	for child in giant_tree.get_children():
		if child is MeshInstance3D and child != trunk:
			tree_meshes.append(child)
	register_dimension_landmark(giant_tree, &"giant_tree", tree_meshes)
	if add_collision:
		animated_foliage.append({
			"node": main_canopy,
			"phase": random.randf_range(0.0, TAU),
			"strength": 0.012,
		})
		var collision := CollisionShape3D.new()
		collision.name = "GiantTreeCollision"
		collision.position = base_position + Vector3.UP * 31.0 * giant_tree_scale
		collision.shape = giant_trunk_shape
		collision.scale = Vector3.ONE * giant_tree_scale
		chunk.add_child(collision)


func get_revelation_tree_height(random: RandomNumberGenerator) -> float:
	if random.randf() < world_tree_chance:
		return max_giant_tree_height
	return random.randf_range(
		max_giant_tree_height * 0.58,
		max_giant_tree_height * 0.85
	)


func create_giant_canopy(
	canopy_name: String,
	canopy_position: Vector3,
	canopy_scale: Vector3,
	random: RandomNumberGenerator
) -> MeshInstance3D:
	var canopy := MeshInstance3D.new()
	canopy.name = canopy_name
	canopy.position = canopy_position
	canopy.rotation.y = random.randf_range(-PI, PI)
	canopy.rotation.z = random.randf_range(-0.08, 0.08)
	canopy.scale = canopy_scale * Vector3(
		random.randf_range(0.88, 1.14),
		random.randf_range(0.9, 1.12),
		random.randf_range(0.86, 1.16)
	)
	canopy.mesh = giant_canopy_mesh
	canopy.material_override = foliage_materials[
		random.randi_range(0, foliage_materials.size() - 1)
	]
	return canopy


func create_pale_stone_pillar(
	chunk: Node3D,
	base_position: Vector3,
	random: RandomNumberGenerator,
	add_collision: bool = true
) -> void:
	var target_height: float = random.randf_range(min_pillar_height, max_pillar_height)
	var height_scale: float = target_height / 120.0
	var width_scale: float = random.randf_range(0.82, 1.2)
	var depth_scale: float = random.randf_range(0.82, 1.2)
	var pillar := MeshInstance3D.new()
	pillar.name = "Revelation_PalePillar"
	pillar.position = base_position + Vector3.UP * target_height * 0.5
	pillar.rotation.y = random.randf_range(-PI, PI)
	pillar.rotation.z = random.randf_range(-0.02, 0.02)
	pillar.scale = Vector3(width_scale, height_scale, depth_scale)
	pillar.mesh = giant_pillar_mesh
	pillar.material_override = pale_stone_material
	var pillar_crown := MeshInstance3D.new()
	pillar_crown.name = "WeatheredCrown"
	pillar_crown.position = Vector3(
		random.randf_range(-0.8, 0.8),
		44.0,
		random.randf_range(-0.5, 0.5)
	)
	pillar_crown.scale = Vector3(1.16, 0.13, 0.92)
	pillar_crown.mesh = giant_pillar_mesh
	pillar_crown.material_override = pale_stone_material
	pillar.add_child(pillar_crown)
	chunk.add_child(pillar)
	register_dimension_landmark(pillar, &"pillar", [pillar, pillar_crown])

	if add_collision:
		var collision := CollisionShape3D.new()
		collision.name = "PalePillarCollision"
		collision.position = pillar.position
		collision.rotation = pillar.rotation
		collision.shape = giant_pillar_shape
		collision.scale = Vector3(
			width_scale * 0.9,
			height_scale,
			depth_scale * 0.9
		)
		chunk.add_child(collision)


func create_tilted_monolith(
	chunk: Node3D,
	base_position: Vector3,
	random: RandomNumberGenerator,
	add_collision: bool = true
) -> void:
	var target_height: float = random.randf_range(min_monolith_height, max_monolith_height)
	var height_scale: float = target_height / 90.0
	var width_scale: float = random.randf_range(0.78, 1.28)
	var depth_scale: float = random.randf_range(0.82, 1.22)
	var monolith := MeshInstance3D.new()
	monolith.name = "Revelation_TiltedMonolith"
	monolith.position = base_position + Vector3.UP * target_height * 0.46
	monolith.rotation.y = random.randf_range(-PI, PI)
	monolith.rotation.z = random.randf_range(-0.12, 0.12)
	monolith.scale = Vector3(width_scale, height_scale, depth_scale)
	monolith.mesh = giant_monolith_mesh
	monolith.material_override = dark_stone_material
	var broken_crown := MeshInstance3D.new()
	broken_crown.name = "BrokenCrown"
	broken_crown.position = Vector3(
		random.randf_range(-1.2, 1.2),
		36.0,
		random.randf_range(-0.35, 0.35)
	)
	broken_crown.rotation.y = random.randf_range(-0.05, 0.05)
	broken_crown.scale = Vector3(0.76, 0.18, 1.01)
	broken_crown.mesh = giant_monolith_mesh
	broken_crown.material_override = rock_material
	monolith.add_child(broken_crown)
	chunk.add_child(monolith)
	register_dimension_landmark(monolith, &"monolith", [monolith, broken_crown])

	if add_collision:
		var collision := CollisionShape3D.new()
		collision.name = "TiltedMonolithCollision"
		collision.position = monolith.position
		collision.rotation = monolith.rotation
		collision.shape = giant_monolith_shape
		collision.scale = Vector3(
			width_scale * 0.9,
			height_scale,
			depth_scale * 0.9
		)
		chunk.add_child(collision)


func create_horizon_ring(
	chunk: Node3D,
	base_position: Vector3,
	_random: RandomNumberGenerator
) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Revelation_HorizonRing"
	ring.position = base_position + Vector3.UP * 62.0
	var ring_world_position: Vector3 = chunk.position + ring.position
	var facing_direction := Vector3(
		-ring_world_position.x,
		0.0,
		-ring_world_position.z
	).normalized()
	var facing_yaw: float = atan2(facing_direction.x, facing_direction.z)
	ring.rotation = Vector3(PI * 0.5, facing_yaw, 0.0)
	ring.mesh = giant_ring_mesh
	ring.material_override = faded_ring_material
	var inner_ring := MeshInstance3D.new()
	inner_ring.name = "InnerEcho"
	inner_ring.position.z = 0.35
	inner_ring.mesh = giant_inner_ring_mesh
	inner_ring.material_override = faded_ring_material
	ring.add_child(inner_ring)
	chunk.add_child(ring)
	register_dimension_landmark(ring, &"ring", [ring, inner_ring])


func create_tree(
	chunk: StaticBody3D,
	base_position: Vector3,
	index: int,
	random: RandomNumberGenerator,
	scale_multiplier: float = 1.0
) -> void:
	var tree_scale: float = get_tree_scale(random) * scale_multiplier
	var tree := Node3D.new()
	tree.name = "Tree_%d" % index
	tree.position = base_position
	tree.rotation.y = random.randf_range(-PI, PI)
	tree.scale = Vector3.ONE * tree_scale

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.position = Vector3(0.0, 1.75, 0.0)
	trunk.rotation = Vector3(
		random.randf_range(-0.045, 0.045),
		0.0,
		random.randf_range(-0.055, 0.055)
	)
	trunk.scale = Vector3(
		random.randf_range(0.82, 1.18),
		random.randf_range(0.94, 1.12),
		random.randf_range(0.82, 1.18)
	)
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_material
	tree.add_child(trunk)

	var foliage := MeshInstance3D.new()
	foliage.name = "Foliage"
	foliage.position = Vector3(
		random.randf_range(-0.22, 0.22),
		random.randf_range(3.95, 4.3),
		random.randf_range(-0.2, 0.2)
	)
	foliage.rotation.y = random.randf_range(-PI, PI)
	foliage.scale = Vector3(
		random.randf_range(0.82, 1.18),
		random.randf_range(0.78, 1.08),
		random.randf_range(0.84, 1.2)
	)
	foliage.mesh = foliage_mesh
	foliage.material_override = foliage_materials[random.randi_range(0, foliage_materials.size() - 1)]
	tree.add_child(foliage)
	var side_foliage := MeshInstance3D.new()
	side_foliage.name = "SideFoliage"
	side_foliage.position = Vector3(
		random.randf_range(-0.65, 0.65),
		random.randf_range(3.55, 4.05),
		random.randf_range(-0.5, 0.5)
	)
	side_foliage.rotation.y = random.randf_range(-PI, PI)
	side_foliage.scale = Vector3(
		random.randf_range(0.48, 0.7),
		random.randf_range(0.42, 0.66),
		random.randf_range(0.5, 0.74)
	)
	side_foliage.mesh = foliage_mesh
	side_foliage.material_override = foliage_materials[
		random.randi_range(0, foliage_materials.size() - 1)
	]
	tree.add_child(side_foliage)
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


func get_tree_scale(random: RandomNumberGenerator) -> float:
	var size_roll: float = random.randf()
	var target_height: float
	var ordinary_height_ceiling: float = maxf(min_tree_height, max_giant_tree_height * 0.1)
	var tall_height_ceiling: float = maxf(
		ordinary_height_ceiling,
		max_giant_tree_height * 0.22
	)
	var large_height_ceiling: float = maxf(
		tall_height_ceiling,
		max_giant_tree_height * large_tree_height_ratio
	)

	if size_roll < 0.58:
		target_height = random.randf_range(min_tree_height, ordinary_height_ceiling)
	elif size_roll < 0.9:
		target_height = random.randf_range(ordinary_height_ceiling, tall_height_ceiling)
	elif size_roll < 0.95:
		target_height = random.randf_range(tall_height_ceiling, large_height_ceiling * 0.72)
	else:
		target_height = random.randf_range(large_height_ceiling * 0.72, large_height_ceiling)

	# The regular tree primitive reaches 5.7 meters at scale 1.0.
	return target_height / 5.7


func create_rock(
	chunk: StaticBody3D,
	base_position: Vector3,
	index: int,
	random: RandomNumberGenerator,
	rock_size: float
) -> void:
	var rock := MeshInstance3D.new()
	var target_height: float = rock_size * 1.4
	var is_large_boulder: bool = target_height >= 8.0
	var horizontal_min: float = 1.15 if is_large_boulder else 0.85
	var horizontal_max: float = 1.75 if is_large_boulder else 1.35
	var rock_scale := Vector3(
		rock_size * random.randf_range(horizontal_min, horizontal_max),
		rock_size * random.randf_range(0.85, 1.05),
		rock_size * random.randf_range(horizontal_min * 0.9, horizontal_max * 0.92)
	)
	rock.name = "Rock_%d" % index
	rock.position = base_position + Vector3(0.0, 0.42 * rock_scale.y, 0.0)
	rock.rotation.x = random.randf_range(-0.1, 0.1)
	rock.rotation.y = random.randf_range(-PI, PI)
	rock.rotation.z = random.randf_range(-0.12, 0.12)
	rock.scale = rock_scale
	rock.mesh = rock_mesh
	rock.material_override = rock_materials[random.randi_range(0, rock_materials.size() - 1)]
	if is_large_boulder:
		var shoulder := MeshInstance3D.new()
		shoulder.name = "EmbeddedShoulder"
		shoulder.position = Vector3(
			random.randf_range(-0.18, 0.18),
			random.randf_range(0.05, 0.18),
			random.randf_range(-0.15, 0.15)
		)
		shoulder.rotation = Vector3(
			random.randf_range(-0.3, 0.3),
			random.randf_range(-PI, PI),
			random.randf_range(-0.25, 0.25)
		)
		shoulder.scale = Vector3(
			random.randf_range(0.38, 0.55),
			random.randf_range(0.32, 0.52),
			random.randf_range(0.4, 0.58)
		)
		shoulder.mesh = rock_mesh
		shoulder.material_override = rock.material_override
		rock.add_child(shoulder)
	chunk.add_child(rock)

	var collision := CollisionShape3D.new()
	collision.name = "RockCollision_%d" % index
	collision.shape = rock_shape
	if is_large_boulder:
		var base_collision_scale := Vector3(
			rock_scale.x * 0.72,
			minf(rock_scale.y * 0.35, 8.0),
			rock_scale.z * 0.72
		)
		collision.position = base_position + Vector3.UP * base_collision_scale.y * 0.5
		collision.scale = base_collision_scale
	else:
		collision.position = base_position + Vector3.UP * rock_scale.y * 0.5
		collision.scale = rock_scale
	chunk.add_child(collision)


func get_rock_scale(random: RandomNumberGenerator) -> float:
	var size_roll: float = random.randf()
	var target_height: float
	if size_roll < monumental_boulder_chance:
		target_height = random.randf_range(25.0, max_monumental_boulder_height)
	elif size_roll < monumental_boulder_chance + large_boulder_chance:
		target_height = random.randf_range(8.0, 20.0)
	elif size_roll < 0.58:
		target_height = random.randf_range(1.0, 3.2)
	else:
		target_height = random.randf_range(3.2, 7.5)
	return target_height / 1.4


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
	remove_chunk_story_traces(chunk)
	remove_dimension_landmarks_under(chunk)
	active_prop_count -= chunk_prop_counts.get(coordinate, 0)
	active_giant_landmark_count -= chunk_giant_counts.get(coordinate, 0)
	chunk_prop_counts.erase(coordinate)
	chunk_giant_counts.erase(coordinate)
	active_chunks.erase(coordinate)
	chunk.queue_free()


func remove_chunk_story_traces(chunk: StaticBody3D) -> void:
	for index in range(story_traces.size() - 1, -1, -1):
		var trace := story_traces[index]
		if not is_instance_valid(trace) or chunk.is_ancestor_of(trace):
			story_traces.remove_at(index)


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


func get_visible_story_trace_count() -> int:
	var visible_count := 0
	for trace in story_traces:
		if is_instance_valid(trace) and trace.visible:
			visible_count += 1
	return visible_count


func get_active_giant_landmark_count() -> int:
	return active_giant_landmark_count


func get_far_landmark_proxy_count() -> int:
	return far_landmark_proxies.size()


func get_nearest_giant_landmark_position(
	world_position: Vector3,
	maximum_distance: float
) -> Vector3:
	var center_coordinate: Vector2i = world_to_chunk(world_position)
	var search_radius: int = ceili(maximum_distance / chunk_size) + 1
	var nearest_position := Vector3.INF
	var nearest_distance: float = maximum_distance
	for x in range(center_coordinate.x - search_radius, center_coordinate.x + search_radius + 1):
		for z in range(center_coordinate.y - search_radius, center_coordinate.y + search_radius + 1):
			var coordinate := Vector2i(x, z)
			if not is_giant_landmark_chunk(coordinate):
				continue
			var giant_random: RandomNumberGenerator = create_giant_instance_random(coordinate)
			var no_reserved_positions: Array[Vector2] = []
			var local_position: Vector3 = get_giant_landmark_position(
				giant_random,
				coordinate,
				no_reserved_positions,
				is_guaranteed_ring_chunk(coordinate)
			)
			if local_position == Vector3.INF:
				continue
			var giant_world_position := local_position + Vector3(
				coordinate.x * chunk_size,
				0.0,
				coordinate.y * chunk_size
			)
			var distance: float = Vector2(
				giant_world_position.x - world_position.x,
				giant_world_position.z - world_position.z
			).length()
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_position = giant_world_position
	return nearest_position


func is_world_position_open(world_position: Vector3, clearance: float) -> bool:
	var clearance_squared: float = clearance * clearance
	for chunk in active_chunks.values():
		for child in chunk.get_children():
			if not (
				child.name.begins_with("Tree_")
				or child.name.begins_with("Rock_")
				or child.name == "Landmark"
				or child.name.begins_with("Revelation_")
			):
				continue
			var child_position: Vector3 = child.global_position
			var offset := Vector2(
				child_position.x - world_position.x,
				child_position.z - world_position.z
			)
			if offset.length_squared() < clearance_squared:
				return false
	return true
