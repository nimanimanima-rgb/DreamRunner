extends MultiMeshInstance3D

signal dimension_changed(dimension_id: StringName, display_name: String)

class DimensionLayer:
	# Stable ID for code integrations; display_name can evolve with the art direction.
	var id: StringName
	var display_name: String
	var sky_top: Color
	var sky_horizon: Color
	var ground_bottom: Color
	var ground_horizon: Color
	var fog_color: Color
	var fog_density: float
	var ambient_color: Color
	var ambient_energy: float
	var light_color: Color
	var light_energy: float
	var mote_color: Color
	var mote_energy: float


@export var player_path: NodePath
@export var world_environment_path: NodePath
@export var directional_light_path: NodePath
@export_range(8, 128, 1) var particle_count: int = 48
@export_range(8.0, 80.0, 1.0) var spawn_radius: float = 34.0
@export_range(0.05, 2.0, 0.05) var drift_speed: float = 0.35
@export_range(2.0, 30.0, 1.0) var vertical_range: float = 14.0
@export_range(1.0, 30.0, 0.5) var dimension_transition_seconds: float = 8.0

@onready var player: CharacterBody3D = get_node(player_path)
@onready var world_environment_node: WorldEnvironment = get_node(world_environment_path)
@onready var directional_light: DirectionalLight3D = get_node(directional_light_path)

var random := RandomNumberGenerator.new()
var mote_positions: Array[Vector3] = []
var mote_directions: Array[Vector3] = []
var mote_phases: PackedFloat32Array = []
var previous_player_position := Vector3.ZERO
var dimension_layers: Array[DimensionLayer] = []
var current_dimension_index: int = 0
var world_environment: Environment
var sky_material: ProceduralSkyMaterial
var mote_material: StandardMaterial3D


func _ready() -> void:
	random.seed = 7717
	world_environment = world_environment_node.environment
	sky_material = world_environment.sky.sky_material as ProceduralSkyMaterial
	create_dimension_layers()
	create_mote_multimesh()
	apply_dimension_immediately(dimension_layers[current_dimension_index])
	previous_player_position = player.global_position
	global_position = previous_player_position

	for index in range(particle_count):
		mote_positions.append(random_mote_position())
		mote_directions.append(random_drift_direction())
		mote_phases.append(random.randf_range(0.0, TAU))
		update_mote_transform(index)


func _process(delta: float) -> void:
	update_dimension_transition(delta)

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
	mote_material = StandardMaterial3D.new()
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		cycle_dimension()
		get_viewport().set_input_as_handled()


func cycle_dimension() -> void:
	current_dimension_index = (current_dimension_index + 1) % dimension_layers.size()
	var layer := dimension_layers[current_dimension_index]
	dimension_changed.emit(layer.id, layer.display_name)


func create_dimension_layers() -> void:
	dimension_layers = [
		create_dimension(
			"pale_dawn", "Waking / Pale World",
			Color(0.18, 0.32, 0.5), Color(0.82, 0.66, 0.68),
			Color(0.11, 0.14, 0.18), Color(0.5, 0.49, 0.47),
			Color(0.68, 0.64, 0.7), 0.00135,
			Color(0.58, 0.65, 0.78), 0.52,
			Color(0.95, 0.74, 0.67), 1.0,
			Color(0.62, 0.75, 0.92), 0.85
		),
		create_dimension(
			"cold_overcast", "Dead / Empty World",
			Color(0.07, 0.09, 0.12), Color(0.34, 0.38, 0.42),
			Color(0.07, 0.085, 0.1), Color(0.28, 0.31, 0.33),
			Color(0.38, 0.43, 0.47), 0.00195,
			Color(0.34, 0.42, 0.52), 0.42,
			Color(0.58, 0.66, 0.74), 0.65,
			Color(0.48, 0.57, 0.66), 0.45
		),
		create_dimension(
			"golden_dissolve", "Memory / Golden World",
			Color(0.24, 0.31, 0.42), Color(0.9, 0.64, 0.34),
			Color(0.17, 0.14, 0.12), Color(0.55, 0.42, 0.29),
			Color(0.76, 0.58, 0.38), 0.00155,
			Color(0.74, 0.59, 0.43), 0.65,
			Color(1.0, 0.67, 0.32), 1.35,
			Color(0.98, 0.75, 0.38), 1.1
		),
		create_dimension(
			"blue_liminal_night", "Liminal Night / Dream-Between",
			Color(0.012, 0.022, 0.065), Color(0.09, 0.14, 0.25),
			Color(0.008, 0.015, 0.035), Color(0.06, 0.09, 0.16),
			Color(0.07, 0.11, 0.21), 0.00145,
			Color(0.15, 0.22, 0.38), 0.48,
			Color(0.25, 0.4, 0.72), 0.62,
			Color(0.48, 0.72, 1.0), 1.65
		),
		create_dimension(
			"dust_haze_afternoon", "Forgotten Road / Dust World",
			Color(0.48, 0.45, 0.42), Color(0.74, 0.64, 0.54),
			Color(0.26, 0.23, 0.2), Color(0.51, 0.45, 0.39),
			Color(0.65, 0.57, 0.48), 0.0019,
			Color(0.67, 0.59, 0.51), 0.58,
			Color(0.86, 0.69, 0.52), 0.92,
			Color(0.72, 0.63, 0.55), 0.45
		),
	]


func create_dimension(
	dimension_id: StringName,
	display_name: String,
	sky_top: Color,
	sky_horizon: Color,
	ground_bottom: Color,
	ground_horizon: Color,
	fog_color: Color,
	fog_density: float,
	ambient_color: Color,
	ambient_energy: float,
	light_color: Color,
	light_energy: float,
	mote_color: Color,
	mote_energy: float
) -> DimensionLayer:
	var layer := DimensionLayer.new()
	layer.id = dimension_id
	layer.display_name = display_name
	layer.sky_top = sky_top
	layer.sky_horizon = sky_horizon
	layer.ground_bottom = ground_bottom
	layer.ground_horizon = ground_horizon
	layer.fog_color = fog_color
	layer.fog_density = fog_density
	layer.ambient_color = ambient_color
	layer.ambient_energy = ambient_energy
	layer.light_color = light_color
	layer.light_energy = light_energy
	layer.mote_color = mote_color
	layer.mote_energy = mote_energy
	return layer


func apply_dimension_immediately(layer: DimensionLayer) -> void:
	sky_material.sky_top_color = layer.sky_top
	sky_material.sky_horizon_color = layer.sky_horizon
	sky_material.ground_bottom_color = layer.ground_bottom
	sky_material.ground_horizon_color = layer.ground_horizon
	world_environment.fog_light_color = layer.fog_color
	world_environment.fog_density = layer.fog_density
	world_environment.ambient_light_color = layer.ambient_color
	world_environment.ambient_light_energy = layer.ambient_energy
	directional_light.light_color = layer.light_color
	directional_light.light_energy = layer.light_energy
	mote_material.albedo_color = layer.mote_color
	mote_material.emission = layer.mote_color
	mote_material.emission_energy_multiplier = layer.mote_energy


func update_dimension_transition(delta: float) -> void:
	var target: DimensionLayer = dimension_layers[current_dimension_index]
	var weight: float = 1.0 - exp(-4.6 * delta / dimension_transition_seconds)
	sky_material.sky_top_color = sky_material.sky_top_color.lerp(target.sky_top, weight)
	sky_material.sky_horizon_color = sky_material.sky_horizon_color.lerp(
		target.sky_horizon, weight
	)
	sky_material.ground_bottom_color = sky_material.ground_bottom_color.lerp(
		target.ground_bottom, weight
	)
	sky_material.ground_horizon_color = sky_material.ground_horizon_color.lerp(
		target.ground_horizon, weight
	)
	world_environment.fog_light_color = world_environment.fog_light_color.lerp(
		target.fog_color, weight
	)
	world_environment.fog_density = lerpf(
		world_environment.fog_density, target.fog_density, weight
	)
	world_environment.ambient_light_color = world_environment.ambient_light_color.lerp(
		target.ambient_color, weight
	)
	world_environment.ambient_light_energy = lerpf(
		world_environment.ambient_light_energy, target.ambient_energy, weight
	)
	directional_light.light_color = directional_light.light_color.lerp(
		target.light_color, weight
	)
	directional_light.light_energy = lerpf(
		directional_light.light_energy, target.light_energy, weight
	)
	mote_material.albedo_color = mote_material.albedo_color.lerp(target.mote_color, weight)
	mote_material.emission = mote_material.emission.lerp(target.mote_color, weight)
	mote_material.emission_energy_multiplier = lerpf(
		mote_material.emission_energy_multiplier, target.mote_energy, weight
	)


func get_current_dimension_id() -> StringName:
	return dimension_layers[current_dimension_index].id


func get_current_dimension_name() -> String:
	return dimension_layers[current_dimension_index].display_name


# Future dimension-aware objects can connect to dimension_changed and decide whether
# to reveal, transform, recolor, or alter sound. Keep those behaviors out of this node.
