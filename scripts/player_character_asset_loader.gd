extends Node

@export_group("Custom Character")
@export_file("*.glb") var character_scene_path: String = (
	"res://assets/models/characters/dream_runner_character_03.glb"
)
@export_file("*.glb") var character_v02_scene_path: String = (
	"res://assets/models/characters/dream_runner_character_02.glb"
)
@export_file("*.glb") var character_v01_scene_path: String = (
	"res://assets/models/characters/dream_runner_character_01.glb"
)
@export_range(0.1, 3.0, 0.05) var custom_character_scale: float = 1.0
@export_range(-2.0, 2.0, 0.05) var custom_character_y_offset: float = -0.9
@export_range(-180.0, 180.0, 1.0) var custom_character_forward_rotation_degrees: float = 180.0

const ESSENTIAL_PART_NAMES: PackedStringArray = [
	"DR_Torso_Coat",
	"DR_Hood_Head",
	"DR_Left_Arm",
	"DR_Right_Arm",
	"DR_Left_Leg",
	"DR_Right_Leg",
]

# Each root drives the listed modular pieces. Nested v03/v01 pieces remain
# nested; flat v02 pieces are attached directly to the same animation pivot.
var animated_assemblies: Array[Dictionary] = [
	{
		"root": "DR_Left_Arm",
		"parts": PackedStringArray(["DR_Left_Arm", "DR_Left_Hand"]),
		"target": NodePath("VisualPivot/PosePivot/MotionPivot/LeftArmPivot"),
	},
	{
		"root": "DR_Right_Arm",
		"parts": PackedStringArray(["DR_Right_Arm", "DR_Right_Hand"]),
		"target": NodePath("VisualPivot/PosePivot/MotionPivot/RightArmPivot"),
	},
	{
		"root": "DR_Left_Leg",
		"parts": PackedStringArray([
			"DR_Left_Leg", "DR_Left_Boot", "DR_Left_Foot",
			"DR_Left_Knee_Pad", "DR_Boot_Sole_Left",
		]),
		"target": NodePath("VisualPivot/PosePivot/MotionPivot/LeftLegPivot"),
	},
	{
		"root": "DR_Right_Leg",
		"parts": PackedStringArray([
			"DR_Right_Leg", "DR_Right_Boot", "DR_Right_Foot",
			"DR_Right_Knee_Pad", "DR_Boot_Sole_Right",
		]),
		"target": NodePath("VisualPivot/PosePivot/MotionPivot/RightLegPivot"),
	},
]

# These pivots are optional future visual upgrades. In the current scene the
# parts safely remain under MotionPivot and inherit the existing body motion.
var optional_visual_assemblies: Array[Dictionary] = [
	{
		"root": "DR_Torso_Coat",
		"parts": PackedStringArray([
			"DR_Torso_Coat", "DR_Coat_Lower_Skirt", "DR_Coat_Back_Panel",
			"DR_Shoulder_Mantle", "DR_Waist_Belt", "DR_Chest_Signal",
			"DR_Cloak_Left_Tail", "DR_Cloak_Right_Tail",
			"DR_Hip_Gear_Left", "DR_Back_Pack_Shadow",
			"DR_Coat_Edge_Left", "DR_Coat_Edge_Right", "DR_Neck",
		]),
		"target": NodePath("VisualPivot/PosePivot/MotionPivot/TorsoPivot"),
	},
	{
		"root": "DR_Hood_Head",
		"parts": PackedStringArray([
			"DR_Hood_Head", "DR_Faceless_Mask", "DR_Hood_Cowl_Back",
		]),
		"target": NodePath("VisualPivot/PosePivot/MotionPivot/HeadPivot"),
	},
	{
		"root": "DR_Scarf_Root",
		"parts": PackedStringArray([
			"DR_Scarf_Root", "DR_Hanging_Scarf", "DR_Scarf_Tail",
		]),
		"target": NodePath("VisualPivot/PosePivot/MotionPivot/ScarfPivot"),
	},
]

const FALLBACK_PATHS: Array[NodePath] = [
	NodePath("VisualPivot/PosePivot/MotionPivot/Torso"),
	NodePath("VisualPivot/PosePivot/MotionPivot/Head"),
	NodePath("VisualPivot/PosePivot/MotionPivot/LeftArmPivot/LeftArm"),
	NodePath("VisualPivot/PosePivot/MotionPivot/RightArmPivot/RightArm"),
	NodePath("VisualPivot/PosePivot/MotionPivot/LeftLegPivot/LeftLeg"),
	NodePath("VisualPivot/PosePivot/MotionPivot/RightLegPivot/RightLeg"),
]

var custom_character_loaded: bool = false
var loaded_character_version: StringName = &"primitive"
var last_attempt_failure: String = ""


func _ready() -> void:
	load_custom_character()


func load_custom_character() -> void:
	var player := get_parent()
	var motion_pivot := player.get_node_or_null("VisualPivot/PosePivot/MotionPivot") as Node3D
	if motion_pivot == null:
		use_primitive_fallback(player, "MotionPivot is unavailable")
		return

	var failures: PackedStringArray = []
	for candidate in get_character_candidates():
		var version := StringName(candidate["version"])
		var path := String(candidate["path"])
		if try_load_character(player, motion_pivot, path, version):
			set_fallback_visible(player, false)
			custom_character_loaded = true
			loaded_character_version = version
			print("DreamRunner character visual loaded: %s" % version)
			return
		failures.append("%s: %s" % [version, last_attempt_failure])

	use_primitive_fallback(player, "; ".join(failures))


func get_character_candidates() -> Array[Dictionary]:
	return [
		{"version": &"v03", "path": character_scene_path},
		{"version": &"v02", "path": character_v02_scene_path},
		{"version": &"v01", "path": character_v01_scene_path},
	]


func try_load_character(
	player: Node,
	motion_pivot: Node3D,
	character_path: String,
	version: StringName
) -> bool:
	last_attempt_failure = ""
	if not ResourceLoader.exists(character_path, "PackedScene"):
		last_attempt_failure = "resource unavailable at %s" % character_path
		return false
	var character_scene := ResourceLoader.load(character_path, "PackedScene") as PackedScene
	if character_scene == null:
		last_attempt_failure = "resource did not load as a PackedScene"
		return false

	var character_root := character_scene.instantiate() as Node3D
	if character_root == null:
		last_attempt_failure = "GLB root is not a Node3D"
		return false
	var parts := collect_named_parts(character_root)
	var missing_parts: PackedStringArray = []
	for part_name in ESSENTIAL_PART_NAMES:
		if not parts.has(part_name):
			missing_parts.append(part_name)
	if not missing_parts.is_empty():
		character_root.free()
		last_attempt_failure = "missing essential nodes: %s" % ", ".join(missing_parts)
		return false

	var animation_targets := {}
	for assembly in animated_assemblies:
		var target_path: NodePath = assembly["target"]
		var target := player.get_node_or_null(target_path) as Node3D
		if target == null:
			character_root.free()
			last_attempt_failure = "missing animation pivot at %s" % target_path
			return false
		animation_targets[String(assembly["root"])] = target

	character_root.name = "CustomCharacterBody_%s" % version
	motion_pivot.add_child(character_root)
	character_root.position.y = custom_character_y_offset
	character_root.rotation.y = deg_to_rad(custom_character_forward_rotation_degrees)
	character_root.scale = Vector3.ONE * custom_character_scale

	for assembly in animated_assemblies:
		var root_name := String(assembly["root"])
		reparent_assembly_parts(
			parts,
			root_name,
			assembly["parts"],
			animation_targets[root_name]
		)

	for assembly in optional_visual_assemblies:
		var optional_target_path: NodePath = assembly["target"]
		var optional_target := player.get_node_or_null(optional_target_path) as Node3D
		if optional_target == null:
			continue
		reparent_assembly_parts(
			parts,
			String(assembly["root"]),
			assembly["parts"],
			optional_target
		)
	return true


func reparent_assembly_parts(
	parts: Dictionary,
	root_name: String,
	part_names: PackedStringArray,
	target: Node3D
) -> void:
	var assembly_root := parts.get(root_name) as Node3D
	if assembly_root == null:
		return
	assembly_root.reparent(target, true)
	for part_name in part_names:
		if part_name == root_name or not parts.has(part_name):
			continue
		var part := parts[part_name] as Node3D
		if part != null and not assembly_root.is_ancestor_of(part):
			part.reparent(target, true)


func collect_named_parts(root: Node) -> Dictionary:
	var parts := {}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		var current_name := String(current.name)
		if current_name.begins_with("DR_"):
			parts[current_name] = current
		for child in current.get_children():
			pending.append(child)
	return parts


func set_fallback_visible(player: Node, is_visible: bool) -> void:
	for fallback_path in FALLBACK_PATHS:
		var fallback := player.get_node_or_null(fallback_path) as GeometryInstance3D
		if fallback != null:
			fallback.visible = is_visible


func use_primitive_fallback(player: Node, reason: String) -> void:
	set_fallback_visible(player, true)
	custom_character_loaded = false
	loaded_character_version = &"primitive"
	print("DreamRunner character visual loaded: primitive fallback")
	push_warning("Custom DreamRunner characters were not loaded (%s)." % reason)
