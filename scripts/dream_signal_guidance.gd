extends CanvasLayer

@export var camera_path: NodePath
@export var destination_manager_path: NodePath
@export var edge_margin: float = 42.0

@onready var camera: Camera3D = get_node(camera_path)
@onready var destination_manager: Node = get_node(destination_manager_path)
@onready var indicator: Control = $Indicator
@onready var arrow: Label = $Indicator/Arrow
@onready var distance_label: Label = $Indicator/Distance


func _process(_delta: float) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		indicator.visible = false
		return

	var destination_position: Vector3 = Vector3(
		destination_manager.call("get_destination_position")
	)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var screen_center: Vector2 = viewport_size * 0.5
	var screen_position: Vector2 = camera.unproject_position(destination_position)
	var is_behind: bool = camera.is_position_behind(destination_position)
	var safe_rect := Rect2(
		Vector2(edge_margin, edge_margin),
		viewport_size - Vector2.ONE * edge_margin * 2.0
	)

	if not is_behind and safe_rect.has_point(screen_position):
		indicator.visible = false
		return

	indicator.visible = true
	var direction: Vector2 = screen_position - screen_center
	if is_behind:
		direction = -direction
	if direction.length_squared() < 0.001:
		direction = Vector2.UP
	direction = direction.normalized()

	var indicator_half_size := indicator.size * 0.5
	var available := Vector2(
		maxf(screen_center.x - edge_margin - indicator_half_size.x, 1.0),
		maxf(screen_center.y - edge_margin - indicator_half_size.y, 1.0)
	)
	var edge_scale: float = minf(
		available.x / maxf(absf(direction.x), 0.001),
		available.y / maxf(absf(direction.y), 0.001)
	)
	indicator.position = screen_center + direction * edge_scale - indicator_half_size
	arrow.rotation = direction.angle() + PI * 0.5

	var distance: float = float(destination_manager.call("get_destination_distance"))
	distance_label.text = "Dream signal: %.0f m" % distance
	indicator.modulate.a = lerpf(0.72, 0.96, clampf((distance - 220.0) / 500.0, 0.0, 1.0))
