extends CanvasLayer

@export var player_path: NodePath
@export var audio_manager_path: NodePath

@onready var player: CharacterBody3D = get_node(player_path)
@onready var audio_manager: Node = get_node(audio_manager_path)
@onready var prompt: Label = $CenterContainer/Message/Prompt

var has_entered_dream: bool = false
var was_mouse_captured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	visible = true


func _process(_delta: float) -> void:
	var mouse_is_captured: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	visible = not mouse_is_captured
	# Browsers can release pointer lock themselves before Godot receives Esc.
	# Treat every captured-to-visible transition as a pause, including focus loss.
	if was_mouse_captured and not mouse_is_captured and not get_tree().paused:
		get_tree().paused = true
	was_mouse_captured = mouse_is_captured
	if not visible:
		has_entered_dream = true
	prompt.text = "Click to resume dream" if has_entered_dream else "Click to enter dream"


func _input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		get_tree().paused = false
		# Keep the browser audio start inside the original mouse gesture. Doing
		# this before requesting pointer lock avoids relying on another app or click.
		audio_manager.call("unlock_audio")
		player.call("capture_mouse")
		has_entered_dream = true
		was_mouse_captured = true
		get_viewport().set_input_as_handled()
