extends Node

@export var player_path: NodePath
@export var atmosphere_path: NodePath
@export var destination_manager_path: NodePath
@export_range(0.0, 16.0, 0.5) var overall_gain_db: float = 11.0
@export_range(-45.0, -8.0, 1.0) var ambience_volume_db: float = -21.0
@export_range(-40.0, -6.0, 1.0) var signal_volume_db: float = -10.0
@export_range(0.0, 0.5, 0.01) var movement_wind_boost: float = 0.18
@export_group("Revelation Bass")
@export_range(32.0, 72.0, 1.0) var revelation_bass_frequency: float = 48.0
@export_range(0.05, 0.5, 0.01) var revelation_bass_gain: float = 0.24
@export_range(0.08, 0.3, 0.01) var revelation_bass_attack: float = 0.15
@export_range(1.5, 7.0, 0.1) var revelation_bass_decay_rate: float = 3.8
@export_range(0.0, 0.5, 0.01) var revelation_bass_harmonic: float = 0.2

@onready var player: CharacterBody3D = get_node(player_path)
@onready var atmosphere: Node = get_node(atmosphere_path)
@onready var destination_manager: Node = get_node(destination_manager_path)
@onready var ambience_player: AudioStreamPlayer = $Ambience
@onready var signal_player: AudioStreamPlayer = $SignalResonance

const MIX_RATE: float = 22050.0
const SIGNAL_DURATION: float = 3.6
const DIMENSION_CUE_DURATION: float = 0.65
const REVELATION_BASS_DURATION: float = 0.9

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
var revelation_bass_sample: int = 0
var revelation_bass_active: bool = false
var current_wind_level: float = 0.7
var current_drone_level: float = 0.08
var current_drone_frequency: float = 58.0
var current_signal_frequency: float = 176.0
var current_air_body: float = 0.1
var target_wind_level: float = 0.68
var target_drone_level: float = 0.05
var target_drone_frequency: float = 70.0
var target_signal_frequency: float = 176.0
var target_air_body: float = 0.1
var dimension_cue_samples_remaining: int = 0
var dimension_cue_phase: float = 0.0


func _ready() -> void:
	random.seed = 18473
	create_generator_streams()
	player.connect("dream_entered", unlock_audio)
	destination_manager.connect("destination_reached", play_signal_resonance)
	destination_manager.connect("revelation_pulse", play_revelation_bass_pulse)
	atmosphere.connect("dimension_changed", play_dimension_transition_cue)
	atmosphere.connect("dimension_changed", update_dimension_targets)
	update_dimension_targets(atmosphere.call("get_current_dimension_id"), "")


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
	# This is called directly from the overlay click. Do not permanently short
	# circuit retries: a browser may reject or suspend an earlier play request.
	if not ambience_player.playing:
		ambience_player.play()
	ambience_player.stream_paused = audio_muted
	var playback := ambience_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		ambience_playback = playback
		audio_unlocked = true


func _process(delta: float) -> void:
	smooth_dimension_audio(delta)
	if not audio_unlocked or audio_muted:
		return
	fill_ambience_buffer()
	fill_signal_buffer()


func update_dimension_targets(dimension_id: StringName, _display_name: String) -> void:
	match dimension_id:
		&"pale_dawn":
			target_wind_level = 0.68
			target_drone_level = 0.05
			target_drone_frequency = 70.0
			target_signal_frequency = 176.0
			target_air_body = 0.1
		&"cold_overcast":
			target_wind_level = 0.63
			target_drone_level = 0.065
			target_drone_frequency = 46.0
			target_signal_frequency = 132.0
			target_air_body = 0.02
		&"golden_dissolve":
			target_wind_level = 0.56
			target_drone_level = 0.12
			target_drone_frequency = 78.0
			target_signal_frequency = 196.0
			target_air_body = 0.22
		&"blue_liminal_night":
			target_wind_level = 0.46
			target_drone_level = 0.14
			target_drone_frequency = 37.0
			target_signal_frequency = 148.0
			target_air_body = 0.18
		&"dust_haze_afternoon":
			target_wind_level = 0.86
			target_drone_level = 0.025
			target_drone_frequency = 52.0
			target_signal_frequency = 164.0
			target_air_body = 0.0


func smooth_dimension_audio(delta: float) -> void:
	var weight: float = 1.0 - exp(-delta * 0.45)
	current_wind_level = lerpf(current_wind_level, target_wind_level, weight)
	current_drone_level = lerpf(current_drone_level, target_drone_level, weight)
	current_drone_frequency = lerpf(
		current_drone_frequency,
		target_drone_frequency,
		weight
	)
	current_signal_frequency = lerpf(current_signal_frequency, target_signal_frequency, weight)
	current_air_body = lerpf(current_air_body, target_air_body, weight)


func fill_ambience_buffer() -> void:
	if ambience_playback == null:
		return
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var run_speed: float = float(player.get("run_speed"))
	var speed_blend: float = clampf(horizontal_speed / maxf(run_speed, 1.0), 0.0, 1.25)
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
		var sample: float = soft_limit(
			soft_air * 0.42 + air_body * 0.16 + distant_tone + dimension_cue
		)
		sample = clampf(sample, -0.95, 0.95)
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


func play_revelation_bass_pulse(_pulse_index: int) -> void:
	if not audio_unlocked or audio_muted:
		return
	revelation_bass_sample = 0
	revelation_bass_active = true
	if not signal_player.playing:
		signal_player.play()
		signal_playback = signal_player.get_stream_playback() as AudioStreamGeneratorPlayback


func fill_signal_buffer() -> void:
	if (not signal_active and not revelation_bass_active) or signal_playback == null:
		return
	var total_samples: int = int(SIGNAL_DURATION * MIX_RATE)
	for _frame in range(signal_playback.get_frames_available()):
		var resonance: float = 0.0
		if signal_active:
			if signal_sample >= total_samples:
				signal_active = false
			else:
				var time: float = float(signal_sample) / MIX_RATE
				var progress: float = time / SIGNAL_DURATION
				var envelope: float = sin(minf(progress * PI * 2.2, PI)) * exp(-2.6 * time)
				resonance = (
					sin(TAU * current_signal_frequency * time)
					+ sin(TAU * current_signal_frequency * 1.5 * time) * 0.38
					+ sin(TAU * current_signal_frequency * 0.5 * time) * 0.3
				) * envelope * 0.28
				signal_sample += 1

		var bass_pulse: float = get_revelation_bass_sample()
		var final_signal: float = soft_limit(resonance + bass_pulse)
		final_signal = clampf(final_signal, -0.95, 0.95)
		signal_playback.push_frame(Vector2(final_signal, final_signal * 0.94))


func soft_limit(sample: float) -> float:
	return tanh(sample * 1.15) / tanh(1.15)


func get_revelation_bass_sample() -> float:
	if not revelation_bass_active:
		return 0.0
	var local_time: float = float(revelation_bass_sample) / MIX_RATE
	if local_time >= REVELATION_BASS_DURATION:
		revelation_bass_active = false
		return 0.0
	var attack: float = sin(
		clampf(local_time / maxf(revelation_bass_attack, 0.01), 0.0, 1.0)
		* PI * 0.5
	)
	var tail_fade: float = 1.0 - smoothstep(0.72, REVELATION_BASS_DURATION, local_time)
	var envelope: float = attack * exp(-revelation_bass_decay_rate * local_time) * tail_fade
	var fundamental: float = sin(TAU * revelation_bass_frequency * local_time)
	var harmonic: float = sin(TAU * revelation_bass_frequency * 2.0 * local_time)
	revelation_bass_sample += 1
	return (
		fundamental + harmonic * revelation_bass_harmonic
	) * envelope * revelation_bass_gain


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		audio_muted = not audio_muted
		ambience_player.stream_paused = audio_muted
		if audio_muted:
			signal_player.stop()
			signal_active = false
			revelation_bass_active = false
		get_viewport().set_input_as_handled()


func is_audio_muted() -> bool:
	return audio_muted


func is_audio_unlocked() -> bool:
	return audio_unlocked
