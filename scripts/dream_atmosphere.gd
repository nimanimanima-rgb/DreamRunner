extends MultiMeshInstance3D

@export var player_path: NodePath
@export_range(8, 128, 1) var particle_count: int = 48
@export_range(8.0, 80.0, 1.0) var spawn_radius: float = 34.0
@export_range(0.05, 2.0, 0.05) var drift_speed: float = 0.35
@export_range(2.0, 30.0, 1.0) var vertical_range: float = 14.0

@onready var player: CharacterBody3D = get_node(player_path)

var random := RandomNumberGenerator.new()
var mote_positions: Array[Vector3] = []
var mote_directions: Array[Vector3] = []
var mote_phases: PackedFloat32Array = []
var previous_player_position := Vector3.ZERO


func _ready() -> void:
	random.seed = 7717
	create_mote_multimesh()
	previous_player_position = player.global_position
	global_position = previous_player_position

	for index in range(particle_count):
		mote_positions.append(random_mote_position())
		mote_directions.append(random_drift_direction())
		mote_phases.append(random.randf_range(0.0, TAU))
		update_mote_transform(index)


func _process(delta: float) -> void:
	var player_position := player.global_position
	var player_movement := player_position - previous_player_position
	global_position = player_position
	previous_player_position = player_position

	for index in range(particle_count):
		# Keep nearby motes suspended in world space while this node follows the player.
		var mote_position := mote_positions[index] - player_movement
		mote_phases[index] += delta * 0.8
		mote_position += mote_directions[index] * drift_speed * delta
		mote_position.y += sin(mote_phases[index]) * 0.08 * delta

		if should_recycle(mote_position):
			mote_position = random_mote_position()
			mote_directions[index] = random_drift_direction()

		mote_positions[index] = mote_position
		update_mote_transform(index)


func create_mote_multimesh() -> void:
	var mote_material := StandardMaterial3D.new()
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.vertex_color_use_as_albedo = true
	mote_material.emission_enabled = true
	mote_material.emission = Color(0.62, 0.78, 1.0)
	mote_material.emission_energy_multiplier = 1.25

	var mote_mesh := QuadMesh.new()
	mote_mesh.size = Vector2(0.22, 0.22)
	mote_mesh.material = mote_material

	var mote_multimesh := MultiMesh.new()
	mote_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mote_multimesh.use_colors = true
	mote_multimesh.mesh = mote_mesh
	mote_multimesh.instance_count = particle_count
	multimesh = mote_multimesh
	custom_aabb = AABB(
		Vector3(-spawn_radius, -vertical_range, -spawn_radius),
		Vector3(spawn_radius * 2.0, vertical_range * 2.0, spawn_radius * 2.0)
	)

	for index in range(particle_count):
		var tint := Color(0.62, 0.78, 1.0, random.randf_range(0.38, 0.78))
		if index % 5 == 0:
			tint = Color(0.9, 0.68, 1.0, random.randf_range(0.35, 0.65))
		mote_multimesh.set_instance_color(index, tint)


func random_mote_position() -> Vector3:
	var angle := random.randf_range(0.0, TAU)
	var distance := sqrt(random.randf()) * spawn_radius
	return Vector3(
		cos(angle) * distance,
		random.randf_range(-vertical_range * 0.35, vertical_range * 0.65),
		sin(angle) * distance
	)


func random_drift_direction() -> Vector3:
	var angle := random.randf_range(0.0, TAU)
	return Vector3(cos(angle), random.randf_range(-0.12, 0.18), sin(angle)).normalized()


func should_recycle(mote_position: Vector3) -> bool:
	return (
		Vector2(mote_position.x, mote_position.z).length_squared() > spawn_radius * spawn_radius
		or mote_position.y < -vertical_range * 0.5
		or mote_position.y > vertical_range * 0.75
	)


func update_mote_transform(index: int) -> void:
	var pulse := 0.75 + sin(mote_phases[index] * 1.7) * 0.2
	multimesh.set_instance_transform(
		index,
		Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * pulse), mote_positions[index])
	)


func get_active_mote_count() -> int:
	return particle_count
