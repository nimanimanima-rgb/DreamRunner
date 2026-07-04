extends CanvasLayer

@export var player_path: NodePath
@export var terrain_manager_path: NodePath
@export var atmosphere_path: NodePath
@export var destination_manager_path: NodePath

@onready var player: CharacterBody3D = get_node(player_path)
@onready var readout: Label = $MarginContainer/PanelContainer/MarginContainer/Readout
@onready var terrain_manager: Node = (
	null if terrain_manager_path.is_empty() else get_node_or_null(terrain_manager_path)
)
@onready var atmosphere: Node = (
	null if atmosphere_path.is_empty() else get_node_or_null(atmosphere_path)
)
@onready var destination_manager: Node = (
	null if destination_manager_path.is_empty() else get_node_or_null(destination_manager_path)
)


func _process(_delta: float) -> void:
	if not visible:
		return

	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var movement_state := "Grounded" if player.is_on_floor() else "Airborne"
	var sprinting := Input.is_action_pressed("sprint") and horizontal_speed > 0.1
	var gliding := (
		not player.is_on_floor()
		and player.velocity.y < 0.0
		and Input.is_action_pressed("jump")
	)
	var mouse_hint := "Esc to release mouse"
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		mouse_hint = "Click to capture mouse"
	var terrain_text := ""
	if terrain_manager != null:
		var chunk_coordinate = terrain_manager.call("get_current_chunk_coordinate")
		var chunk_count = terrain_manager.call("get_active_chunk_count")
		var prop_count = terrain_manager.call("get_active_prop_count")
		var giant_landmark_count = terrain_manager.call("get_active_giant_landmark_count")
		var far_landmark_count = terrain_manager.call("get_far_landmark_proxy_count")
		terrain_text = (
			"\nChunk: (%d, %d)\n" % [chunk_coordinate.x, chunk_coordinate.y]
			+ "Active chunks: %d\n" % chunk_count
			+ "Active props: %d\n" % prop_count
			+ "Giant forms: %d\n" % giant_landmark_count
			+ "Far silhouettes: %d" % far_landmark_count
		)
		if atmosphere != null:
			terrain_text += "\nDream motes: %d" % atmosphere.call("get_active_mote_count")
			terrain_text += "\nMood: %s" % atmosphere.call("get_current_mood_name")
		if destination_manager != null:
			var destination_distance: float = float(
				destination_manager.call("get_destination_distance")
			)
			terrain_text += "\nDream signal: %.0f m" % destination_distance
			terrain_text += "\nComposition: %s" % destination_manager.call(
				"get_current_composition_name"
			)
			terrain_text += "\nPlacement: %s" % destination_manager.call(
				"get_placement_mode"
			)
			terrain_text += "\nDirection offset: %+.0f deg" % float(
				destination_manager.call("get_direction_offset_degrees")
			)
			terrain_text += "\nLaunch route: %s" % (
				"favored" if bool(destination_manager.call("is_launch_route_favored")) else "normal"
			)
	var movement_mode := "Gliding" if gliding else "Airborne"
	if player.is_on_floor():
		if horizontal_speed < 0.1:
			movement_mode = "Idle"
		elif sprinting:
			movement_mode = "Sprinting"
		else:
			movement_mode = "Running"

	readout.text = (
		"Speed: %5.1f m/s\n" % horizontal_speed
		+ "State: %s\n" % movement_state
		+ "Vertical velocity: %5.1f m/s\n" % player.velocity.y
		+ "Sprinting: %s\n" % str(sprinting)
		+ "Gliding: %s\n" % str(gliding)
		+ "Mode: %s\n" % movement_mode
		+ "Ground clearance: %4.1f m\n" % float(player.call("get_ground_clearance"))
		+ "Glide pose: %3.0f%%\n" % (float(player.call("get_glide_pose_blend")) * 100.0)
		+ mouse_hint
		+ terrain_text
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()
