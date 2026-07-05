extends Node

@export var player_path: NodePath
@export var atmosphere_path: NodePath
@export var destination_manager_path: NodePath
@export_range(0.0, 6.0, 0.5) var overall_gain_db: float = 3.0
@export_range(-45.0, -8.0, 1.0) var ambience_volume_db: float = -27.0
@export_range(-40.0, -6.0, 1.0) var signal_volume_db: float = -17.0
@export_range(0.0, 0.5, 0.01) var movement_wind_boost: float = 0.18

@onready var player: CharacterBody3D = get_node(player_path)
@onready var atmosphere: Node = get_node(atmosphere_path)
@onready var destination_manager: Node = get_node(destination_manager_path)
@onready var ambience_player: AudioStreamPlayer = $Ambience
@onready var signal_player: AudioStreamPlayer = $SignalResonance

const MIX_RATE: float = 22050.0
const SIGNAL_DURATION: float = 1.8
const DIMENSION_CUE_DURATION: float = 0.65

var random := RandomNumberGenerator.new()
var ambience_playback: AudioStreamGeneratorPlayback
var signal_playback: AudioStreamGeneratorPlayback
var audio_unlocked: bool = false
var audio_muted: bool = false
var fast_wind: float = 0.0
var slow_wind: float = 0.0
var drone_phase: float = 0.0
var signal_sample: int = 0
var signal_active: bool = false
var current_wind_level: float = 0.7
var current_drone_level: float = 0.08
var current_drone_frequency: float = 58.0
var current_signal_frequency: float = 176.0
var current_air_body: float = 0.1
var dimension_cue_samples_remaining: int = 0
var dimension_cue_phase: float = 0.0


func _ready() -> void:
	random.seed = 18473
	create_generator_streams()
	player.connect("dream_entered", unlock_audio)
	destination_manager.connect("destination_reached", play_signal_resonance)
	atmosphere.connect("dimension_changed", play_dimension_transition_cue)


func create_generator_streams() -> void:
	var ambience_stream := AudioStreamGenerator.new()
	ambience_stream.mix_rate = MIX_RATE
	ambience_stream.buffer_length = 0.35
	ambience_player.stream = ambience_stream
	ambience_player.volume_db = ambience_volume_db + overall_gain_db
	var signal_stream := AudioStreamGenerator.new()
	signal_stream.mix_rate = MIX_RATE
	signal_stream.buffer_length = 0.25
	signal_player.stream = signal_stream
	signal_player.volume_db = signal_volume_db + overall_gain_db


func unlock_audio() -> void:
	if audio_unlocked:
		return
	audio_unlocked = true
	ambience_player.play()
	ambience_playback = ambience_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	update_dimension_color(delta)
	if not audio_unlocked or audio_muted:
		return
	fill_ambience_buffer()
	fill_signal_buffer()


func update_dimension_color(delta: float) -> void:
	# Audio follows stable IDs so conceptual display names can change safely.
	var dimension_id: StringName = atmosphere.call("get_current_dimension_id")
	var target_wind: float = 0.7
	var target_drone: float = 0.08
	var target_frequency: float = 58.0
	var target_signal_frequency: float = 176.0
	var target_air_body: float = 0.1
	match dimension_id:
		&"pale_dawn":
			target_wind = 0.68
			target_drone = 0.05
			target_frequency = 70.0
			target_signal_frequency = 176.0
			target_air_body = 0.1
		&"cold_overcast":
			target_wind = 0.63
			target_drone = 0.065
			target_frequency = 46.0
			target_signal_frequency = 132.0
			target_air_body = 0.02
		&"golden_dissolve":
			target_wind = 0.56
			target_drone = 0.12
			target_frequency = 78.0
			target_signal_frequency = 196.0
			target_air_body = 0.22
		&"blue_liminal_night":
			target_wind = 0.46
			target_drone = 0.14
			target_frequency = 37.0
			target_signal_frequency = 148.0
			target_air_body = 0.18
		&"dust_haze_afternoon":
			target_wind = 0.86
			target_drone = 0.025
			target_frequency = 52.0
			target_signal_frequency = 164.0
			target_air_body = 0.0
	var weight: float = 1.0 - exp(-delta * 0.45)
	current_wind_level = lerpf(current_wind_level, target_wind, weight)
	current_drone_level = lerpf(current_drone_level, target_drone, weight)
	current_drone_frequency = lerpf(current_drone_frequency, target_frequency, weight)
	current_signal_frequency = lerpf(current_signal_frequency, target_signal_frequency, weight)
	current_air_body = lerpf(current_air_body, target_air_body, weight)


func fill_ambience_buffer() -> void:
	if ambience_playback == null:
		return
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var sprint_speed: float = float(player.get("sprint_speed"))
	var speed_blend: float = clampf(horizontal_speed / maxf(sprint_speed, 1.0), 0.0, 1.25)
	var glide_boost: float = 0.08 if bool(player.call("is_gliding")) else 0.0
	var wind_level: float = current_wind_level + speed_blend * movement_wind_boost + glide_boost
	for _frame in range(ambience_playback.get_frames_available()):
		var noise_sample: float = random.randf_range(-1.0, 1.0)
		fast_wind = lerpf(fast_wind, noise_sample, 0.075)
		slow_wind = lerpf(slow_wind, noise_sample, 0.008)
		var soft_air: float = (fast_wind - slow_wind) * wind_level
		var air_body: float = slow_wind * current_air_body
		drone_phase = fmod(drone_phase + TAU * current_drone_frequency / MIX_RATE, TAU)
		var distant_tone: float = (sin(drone_phase) + sin(drone_phase * 0.503) * 0.28) * current_drone_level
		var dimension_cue := get_dimension_transition_sample()
		var sample: float = clampf(
			soft_air * 0.42 + air_body * 0.16 + distant_tone + dimension_cue,
			-0.75,
			0.75
		)
		ambience_playback.push_frame(Vector2(sample * 0.96, sample))


func play_dimension_transition_cue(_dimension_id: StringName, _display_name: String) -> void:
	if not audio_unlocked or audio_muted:
		return
	dimension_cue_samples_remaining = int(DIMENSION_CUE_DURATION * MIX_RATE)
	dimension_cue_phase = 0.0


func get_dimension_transition_sample() -> float:
	if dimension_cue_samples_remaining <= 0:
		return 0.0
	var total_samples := DIMENSION_CUE_DURATION * MIX_RATE
	var progress := 1.0 - float(dimension_cue_samples_remaining) / total_samples
	var envelope := sin(progress * PI) * 0.035
	dimension_cue_phase = fmod(
		dimension_cue_phase + TAU * current_signal_frequency * 0.5 / MIX_RATE,
		TAU
	)
	dimension_cue_samples_remaining -= 1
	return sin(dimension_cue_phase) * envelope


func play_signal_resonance() -> void:
	if not audio_unlocked or audio_muted:
		return
	signal_sample = 0
	signal_active = true
	signal_player.play()
	signal_playback = signal_player.get_stream_playback() as AudioStreamGeneratorPlayback


func fill_signal_buffer() -> void:
	if not signal_active or signal_playback == null:
		return
	var total_samples: int = int(SIGNAL_DURATION * MIX_RATE)
	for _frame in range(signal_playback.get_frames_available()):
		if signal_sample >= total_samples:
			signal_active = false
			break
		var time: float = float(signal_sample) / MIX_RATE
		var progress: float = time / SIGNAL_DURATION
		var envelope: float = sin(minf(progress * PI * 2.2, PI)) * exp(-2.6 * time)
		var resonance: float = (
			sin(TAU * current_signal_frequency * time)
			+ sin(TAU * current_signal_frequency * 1.5 * time) * 0.38
			+ sin(TAU * current_signal_frequency * 0.5 * time) * 0.3
		) * envelope * 0.28
		signal_playback.push_frame(Vector2(resonance, resonance * 0.94))
		signal_sample += 1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		audio_muted = not audio_muted
		ambience_player.stream_paused = audio_muted
		if audio_muted:
			signal_player.stop()
			signal_active = false
		get_viewport().set_input_as_handled()


func is_audio_muted() -> bool:
	return audio_muted


func is_audio_unlocked() -> bool:
	return audio_unlocked
