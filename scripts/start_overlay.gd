extends CanvasLayer

@export var player_path: NodePath
@export var audio_manager_path: NodePath

@onready var player: CharacterBody3D = get_node(player_path)
@onready var audio_manager: Node = get_node(audio_manager_path)
@onready var prompt: Label = $CenterContainer/Message/Prompt

var has_entered_dream: bool = false
var was_mouse_captured: bool = false
var start_click_debug_printed: bool = false
var resume_debug_printed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	set_overlay_active(true)


func _process(_delta: float) -> void:
	var mouse_is_captured: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	# Browsers can release pointer lock themselves before Godot receives Esc.
	# Treat every captured-to-visible transition as a pause, including focus loss.
	if was_mouse_captured and not mouse_is_captured and not get_tree().paused:
		get_tree().paused = true
		set_overlay_active(true)
	if get_tree().paused:
		set_overlay_active(true)
	was_mouse_captured = mouse_is_captured
	prompt.text = "Click to resume dream" if has_entered_dream else "Click to enter dream"


func _input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if not start_click_debug_printed:
			print("StartOverlay: start/resume click received.")
			start_click_debug_printed = true
		resume_gameplay_from_overlay()
		attempt_audio_unlock()
		get_viewport().set_input_as_handled()


func resume_gameplay_from_overlay() -> void:
	# Gameplay resume must not depend on Web audio unlock succeeding.
	has_entered_dream = true
	set_overlay_active(false)
	release_focus_recursive(self)
	get_tree().paused = false
	player.call("capture_mouse")
	was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if not resume_debug_printed:
		print(
			"StartOverlay: resumed. paused=%s visible=%s mouse_filter=%s" % [
				str(get_tree().paused),
				str(visible),
				get_overlay_mouse_filter_debug()
			]
		)
		resume_debug_printed = true


func attempt_audio_unlock() -> void:
	if audio_manager == null or not audio_manager.has_method("unlock_audio"):
		print("StartOverlay: audio unlock skipped; AudioManager unavailable.")
		return
	audio_manager.call("unlock_audio")


func set_overlay_active(active: bool) -> void:
	visible = active
	set_control_mouse_filter_recursive(self, Control.MOUSE_FILTER_IGNORE)


func set_control_mouse_filter_recursive(node: Node, mouse_filter: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = mouse_filter
	for child in node.get_children():
		set_control_mouse_filter_recursive(child, mouse_filter)


func release_focus_recursive(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.release_focus()
	for child in node.get_children():
		release_focus_recursive(child)


func get_overlay_mouse_filter_debug() -> String:
	var center := get_node_or_null("CenterContainer") as Control
	if center == null:
		return "n/a"
	return str(center.mouse_filter)
