extends CanvasLayer

@export var player_path: NodePath

@onready var player: CharacterBody3D = get_node(player_path)
@onready var prompt: Label = $CenterContainer/Message/Prompt

var has_entered_dream: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	visible = true


func _process(_delta: float) -> void:
	visible = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
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
		player.call("capture_mouse")
		has_entered_dream = true
		get_viewport().set_input_as_handled()
