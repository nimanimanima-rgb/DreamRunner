extends Node

@export_group("Custom Character")
@export_file("*.glb") var character_scene_path: String = (
	"res://assets/models/characters/dream_runner_character_01.glb"
)
@export_range(0.1, 3.0, 0.05) var custom_character_scale: float = 1.0
@export_range(-2.0, 2.0, 0.05) var custom_character_y_offset: float = -0.9
@export_range(-180.0, 180.0, 1.0) var custom_character_forward_rotation_degrees: float = 180.0

const REQUIRED_PART_NAMES: PackedStringArray = [
	"DR_Torso_Coat",
	"DR_Coat_Back_Panel",
	"DR_Neck",
	"DR_Hood_Head",
	"DR_Faceless_Mask",
	"DR_Chest_Signal",
	"DR_Hanging_Scarf",
	"DR_Left_Arm",
	"DR_Right_Arm",
	"DR_Left_Hand",
	"DR_Right_Hand",
	"DR_Left_Leg",
	"DR_Right_Leg",
	"DR_Left_Foot",
	"DR_Right_Foot",
]

const LIMB_TARGET_PATHS := {
	"DR_Left_Arm": NodePath("VisualPivot/PosePivot/MotionPivot/LeftArmPivot"),
	"DR_Right_Arm": NodePath("VisualPivot/PosePivot/MotionPivot/RightArmPivot"),
	"DR_Left_Leg": NodePath("VisualPivot/PosePivot/MotionPivot/LeftLegPivot"),
	"DR_Right_Leg": NodePath("VisualPivot/PosePivot/MotionPivot/RightLegPivot"),
}

const FALLBACK_PATHS: Array[NodePath] = [
	NodePath("VisualPivot/PosePivot/MotionPivot/Torso"),
	NodePath("VisualPivot/PosePivot/MotionPivot/Head"),
	NodePath("VisualPivot/PosePivot/MotionPivot/LeftArmPivot/LeftArm"),
	NodePath("VisualPivot/PosePivot/MotionPivot/RightArmPivot/RightArm"),
	NodePath("VisualPivot/PosePivot/MotionPivot/LeftLegPivot/LeftLeg"),
	NodePath("VisualPivot/PosePivot/MotionPivot/RightLegPivot/RightLeg"),
]

var custom_character_loaded: bool = false


func _ready() -> void:
	load_custom_character()


func load_custom_character() -> void:
	var player := get_parent()
	var motion_pivot := player.get_node_or_null("VisualPivot/PosePivot/MotionPivot") as Node3D
	if motion_pivot == null:
		warn_and_keep_fallback("MotionPivot is unavailable")
		return
	if not ResourceLoader.exists(character_scene_path, "PackedScene"):
		warn_and_keep_fallback("GLB resource is unavailable at %s" % character_scene_path)
		return
	var character_scene := ResourceLoader.load(character_scene_path, "PackedScene") as PackedScene
	if character_scene == null:
		warn_and_keep_fallback("GLB resource did not load as a PackedScene")
		return

	var character_root := character_scene.instantiate() as Node3D
	if character_root == null:
		warn_and_keep_fallback("GLB root is not a Node3D")
		return

	character_root.name = "CustomCharacterBody"
	motion_pivot.add_child(character_root)
	character_root.position.y = custom_character_y_offset
	character_root.rotation.y = deg_to_rad(custom_character_forward_rotation_degrees)
	character_root.scale = Vector3.ONE * custom_character_scale

	var parts := collect_named_parts(character_root)
	var missing_parts: PackedStringArray = []
	for part_name in REQUIRED_PART_NAMES:
		if not parts.has(part_name):
			missing_parts.append(part_name)
	if not missing_parts.is_empty():
		character_root.queue_free()
		warn_and_keep_fallback("missing GLB nodes: %s" % ", ".join(missing_parts))
		return

	var limb_targets := {}
	for part_name in LIMB_TARGET_PATHS:
		var target := player.get_node_or_null(LIMB_TARGET_PATHS[part_name]) as Node3D
		if target == null:
			character_root.queue_free()
			warn_and_keep_fallback("missing animation pivot for %s" % part_name)
			return
		limb_targets[part_name] = target

	# Keep each modular limb on the established procedural animation pivot.
	# Reparenting with keep_global_transform bakes the GLB root tuning into the
	# limb's local rest pose without changing any movement or pose code.
	for part_name in LIMB_TARGET_PATHS:
		var limb := parts[part_name] as Node3D
		limb.reparent(limb_targets[part_name], true)

	set_fallback_visible(player, false)
	custom_character_loaded = true


func collect_named_parts(root: Node) -> Dictionary:
	var parts := {}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		var current_name := String(current.name)
		if current_name in REQUIRED_PART_NAMES:
			parts[current_name] = current
		for child in current.get_children():
			pending.append(child)
	return parts


func set_fallback_visible(player: Node, is_visible: bool) -> void:
	for fallback_path in FALLBACK_PATHS:
		var fallback := player.get_node_or_null(fallback_path) as GeometryInstance3D
		if fallback != null:
			fallback.visible = is_visible


func warn_and_keep_fallback(reason: String) -> void:
	custom_character_loaded = false
	push_warning("Custom Dream Runner character was not loaded (%s); using primitive fallback." % reason)
