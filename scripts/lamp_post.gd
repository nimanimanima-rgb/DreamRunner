extends Node3D

@onready var bulb: MeshInstance3D = $LampBulb
@onready var light_pool: MeshInstance3D = $LightPool

var bulb_material: StandardMaterial3D
var pool_material: StandardMaterial3D


func _ready() -> void:
	# Each rare lamp owns only two tiny material instances so dimensions can
	# change its presence without dynamic lights or shared-resource side effects.
	bulb_material = (bulb.material_override as StandardMaterial3D).duplicate()
	pool_material = (light_pool.material_override as StandardMaterial3D).duplicate()
	bulb.material_override = bulb_material
	light_pool.material_override = pool_material
	apply_dimension_profile(get_meta("dimension_id", &"pale_dawn"))


func apply_dimension_profile(dimension_id: StringName) -> void:
	var warm_color := Color(1.0, 0.56, 0.18)
	var bulb_energy: float = 0.75
	var pool_alpha: float = 0.07
	match dimension_id:
		&"cold_overcast":
			warm_color = Color(0.64, 0.57, 0.45)
			bulb_energy = 0.28
			pool_alpha = 0.03
		&"golden_dissolve":
			warm_color = Color(1.0, 0.58, 0.2)
			bulb_energy = 1.7
			pool_alpha = 0.13
		&"blue_liminal_night":
			warm_color = Color(1.0, 0.52, 0.16)
			bulb_energy = 2.0
			pool_alpha = 0.15
		&"dust_haze_afternoon":
			warm_color = Color(0.93, 0.52, 0.2)
			bulb_energy = 1.2
			pool_alpha = 0.1

	bulb_material.albedo_color = warm_color
	bulb_material.emission = warm_color
	bulb_material.emission_energy_multiplier = bulb_energy
	pool_material.albedo_color = Color(warm_color, pool_alpha)
	pool_material.emission = warm_color
	pool_material.emission_energy_multiplier = bulb_energy * 0.18
