extends CanvasLayer

@export var player_path: NodePath

@onready var player: CharacterBody3D = get_node(player_path)
@onready var readout: Label = $MarginContainer/PanelContainer/MarginContainer/Readout


func _process(_delta: float) -> void:
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var movement_state := "Grounded" if player.is_on_floor() else "Airborne"
	var sprinting := Input.is_action_pressed("sprint") and horizontal_speed > 0.1
	var mouse_hint := "Esc to release mouse"
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		mouse_hint = "Click to capture mouse"
	var movement_mode := "Airborne"
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
		+ "Mode: %s\n" % movement_mode
		+ mouse_hint
	)
