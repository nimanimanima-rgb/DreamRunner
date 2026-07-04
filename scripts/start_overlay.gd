extends CanvasLayer


func _process(_delta: float) -> void:
	visible = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
