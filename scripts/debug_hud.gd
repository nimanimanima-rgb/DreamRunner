extends CanvasLayer

@export var player_path: NodePath
@export var terrain_manager_path: NodePath

@onready var player: CharacterBody3D = get_node(player_path)
@onready var readout: Label = $MarginContainer/PanelContainer/MarginContainer/Readout
@onready var terrain_manager: Node = (
	null if terrain_manager_path.is_empty() else get_node_or_null(terrain_manager_path)
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
		terrain_text = (
			"\nChunk: (%d, %d)\n" % [chunk_coordinate.x, chunk_coordinate.y]
			+ "Active chunks: %d\n" % chunk_count
			+ "Active props: %d" % prop_count
		)
	var movement_mode := "Gliding" if gliding else "Airborne"
	if player.is_on_floor():
		if horizontal_speed < 0.1:
			movement_mode = "Idle"
		elif sprinting:
			movement_mode = "Sprint"
		else:
			movement_mode = "Run"

	readout.text = (
		"Speed: %5.1f m/s\n" % horizontal_speed
		+ "State: %s\n" % movement_state
		+ "Vertical velocity: %5.1f m/s\n" % player.velocity.y
		+ "Sprinting: %s\n" % str(sprinting)
		+ "Gliding: %s\n" % str(gliding)
		+ "Mode: %s\n" % movement_mode
		+ mouse_hint
		+ terrain_text
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()
