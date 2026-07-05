extends CanvasLayer

@export var atmosphere_path: NodePath
@export_range(0.4, 1.0, 0.05) var transition_duration: float = 0.7
@export_range(0.05, 0.3, 0.01) var peak_alpha: float = 0.16

@onready var atmosphere: Node = get_node(atmosphere_path)
@onready var veil: ColorRect = $Veil

var transition_time: float = -1.0
var veil_color := Color(0.7, 0.78, 0.86)


func _ready() -> void:
	veil.visible = false
	atmosphere.connect("dimension_changed", _on_dimension_changed)


func _process(delta: float) -> void:
	if transition_time < 0.0:
		return

	transition_time += delta
	var progress := clampf(transition_time / transition_duration, 0.0, 1.0)
	# A single soft breath hides instant object/material swaps without becoming a fade.
	var alpha := sin(progress * PI) * peak_alpha
	veil.color = Color(veil_color, alpha)

	if progress >= 1.0:
		transition_time = -1.0
		veil.visible = false


func _on_dimension_changed(dimension_id: StringName, _display_name: String) -> void:
	match dimension_id:
		&"pale_dawn":
			veil_color = Color(0.72, 0.8, 0.86)
		&"cold_overcast":
			veil_color = Color(0.2, 0.29, 0.38)
		&"golden_dissolve":
			veil_color = Color(0.88, 0.63, 0.3)
		&"blue_liminal_night":
			veil_color = Color(0.16, 0.28, 0.55)
		&"dust_haze_afternoon":
			veil_color = Color(0.62, 0.49, 0.36)

	transition_time = 0.0
	veil.color = Color(veil_color, 0.0)
	veil.visible = true
