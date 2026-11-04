# scripts/autoload/SoundManager.gd
extends Node

## Pure GDScript procedural 16-bit PCM waveform synthesis for «Шагающий дом».
## Zero external audio files (.wav/.ogg/.mp3). 100% programmatically generated.

const MIX_RATE: int = 22050

var sfx_streams: Dictionary = {}
var loop_streams: Dictionary = {}

var engine_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var stove_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_player_index: int = 0

func _init() -> void:
	_init_buses()
	_generate_all_streams()

func _ready() -> void:
	_setup_audio_nodes()
	_connect_event_bus()

func _init_buses() -> void:
	var required_buses: Array[String] = ["SFX", "Engine", "Wind", "UI"]
	for bus_name in required_buses:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			var new_idx: int = AudioServer.bus_count
			AudioServer.add_bus(new_idx)
			AudioServer.set_bus_name(new_idx, bus_name)
			AudioServer.set_bus_send(new_idx, "Master")

func _setup_audio_nodes() -> void:
	engine_player = AudioStreamPlayer.new()
	engine_player.name = "EnginePlayer"
	engine_player.bus = "Engine"
	engine_player.stream = loop_streams.get("engine", null)
	add_child(engine_player)
	
	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindPlayer"
	wind_player.bus = "Wind"
	wind_player.stream = loop_streams.get("wind", null)
	add_child(wind_player)
	
	stove_player = AudioStreamPlayer.new()
	stove_player.name = "StovePlayer"
	stove_player.bus = "SFX"
	stove_player.stream = loop_streams.get("stove", null)
	add_child(stove_player)
	
	sfx_players.clear()
	for i in range(8):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

func _connect_event_bus() -> void:
	var bus_node: Node = null
	if Engine.has_singleton("EventBus"):
		bus_node = Engine.get_singleton("EventBus")
	elif is_inside_tree() and get_tree().root.has_node("EventBus"):
		bus_node = get_tree().root.get_node("EventBus")
	
	if bus_node != null:
		if bus_node.has_signal("stove_toggled"):
			bus_node.connect("stove_toggled", Callable(self, "_on_stove_toggled"))
		if bus_node.has_signal("stove_extinguished"):
			bus_node.connect("stove_extinguished", Callable(self, "_on_stove_extinguished"))
		if bus_node.has_signal("repair_performed"):
			bus_node.connect("repair_performed", Callable(self, "_on_repair_performed"))
		if bus_node.has_signal("resource_looted"):
			bus_node.connect("resource_looted", Callable(self, "_on_resource_looted"))
		if bus_node.has_signal("critical_stop_triggered"):
			bus_node.connect("critical_stop_triggered", Callable(self, "_on_critical_stop"))

func _on_stove_toggled(is_on: bool) -> void:
	if is_on:
		play_sfx("stove_ignite")
	set_stove_sound(is_on)

func _on_stove_extinguished(_reason: String) -> void:
	play_sfx("stove_extinguish")
	set_stove_sound(false)

func _on_repair_performed(_spent: float, _restored: float) -> void:
	play_sfx("metal_clank")

func _on_resource_looted(_type: String, _amount: float, _pos: Vector2) -> void:
	play_sfx("loot")

func _on_critical_stop(_reason: String) -> void:
	play_sfx("alarm")

func _generate_all_streams() -> void:
	sfx_streams["step"] = _generate_step()
	sfx_streams["metal_clank"] = _generate_metal_clank()
	sfx_streams["loot"] = _generate_loot()
	sfx_streams["stove_ignite"] = _generate_stove_ignite()
	sfx_streams["stove_extinguish"] = _generate_stove_extinguish()
	sfx_streams["alarm"] = _generate_alarm()
	sfx_streams["click"] = _generate_click()
	sfx_streams["error"] = _generate_error()
	
	loop_streams["engine"] = _generate_engine_loop()
	loop_streams["wind"] = _generate_wind_loop()
	loop_streams["stove"] = _generate_stove_loop()

# ==============================================================================
# PUBLIC AUDIO API
# ==============================================================================
func play_sfx(sfx_name: String) -> void:
	if not sfx_streams.has(sfx_name):
		return
	if not is_inside_tree() or sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = sfx_players[next_sfx_player_index]
	next_sfx_player_index = (next_sfx_player_index + 1) % sfx_players.size()
	
	if sfx_name == "click" or sfx_name == "error":
		player.bus = "UI"
	else:
		player.bus = "SFX"
		
	player.stream = sfx_streams[sfx_name]
	player.play()

func set_engine_hum(intensity: float) -> void:
	if engine_player == null or not is_inside_tree():
		return
	var clamped: float = clampf(intensity, 0.0, 1.0)
	if clamped <= 0.01:
		if engine_player.playing:
			engine_player.stop()
	else:
		if not engine_player.playing:
			engine_player.play()
		var vol_db: float = lerpf(-30.0, 0.0, clamped)
		engine_player.volume_db = vol_db
		engine_player.pitch_scale = lerpf(0.85, 1.15, clamped)

func set_wind_intensity(intensity: float) -> void:
	if wind_player == null or not is_inside_tree():
		return
	var clamped: float = clampf(intensity, 0.0, 1.0)
	if not wind_player.playing:
		wind_player.play()
	var vol_db: float = lerpf(-36.0, 2.0, clamped)
	wind_player.volume_db = vol_db
	wind_player.pitch_scale = lerpf(0.75, 1.25, clamped)

func set_stove_sound(is_burning: bool) -> void:
	if stove_player == null or not is_inside_tree():
		return
	if is_burning:
		if not stove_player.playing:
			stove_player.volume_db = -6.0
			stove_player.play()
	else:
		if stove_player.playing:
			stove_player.stop()

func set_volume(bus_name: String, volume_linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var clamped: float = clampf(volume_linear, 0.0, 1.0)
		var db: float = linear_to_db(clamped)
		AudioServer.set_bus_volume_db(idx, db)

func get_volume(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0

func stop_all() -> void:
	if engine_player != null and engine_player.playing:
		engine_player.stop()
	if wind_player != null and wind_player.playing:
		wind_player.stop()
	if stove_player != null and stove_player.playing:
		stove_player.stop()
	for p in sfx_players:
		if p != null and p.playing:
			p.stop()

# ==============================================================================
# SYNTHESIS ALGORITHMS (16-bit signed PCM mono)
# ==============================================================================
func _float_to_16bit_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var sample_count: int = samples.size()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var s: float = clampf(samples[i], -1.0, 1.0)
		var val: int = int(s * 32767.0)
		if val < 0:
			val += 65536
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = sample_count
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav

func _generate_step() -> AudioStreamWAV:
	var duration: float = 0.22
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-18.0 * t)
		var thud: float = sin(t * 65.0 * TAU) * 0.8
		var noise: float = (randf() * 2.0 - 1.0) * 0.4 * exp(-25.0 * t)
		samples[i] = (thud + noise) * env
	return _float_to_16bit_wav(samples, false)

func _generate_metal_clank() -> AudioStreamWAV:
	var duration: float = 0.35
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-10.0 * t)
		var f1: float = sin(t * 540.0 * TAU) * 0.6
		var f2: float = sin(t * 1160.0 * TAU) * 0.35
		var f3: float = sin(t * 2240.0 * TAU) * 0.15
		samples[i] = (f1 + f2 + f3) * env
	return _float_to_16bit_wav(samples, false)

func _generate_loot() -> AudioStreamWAV:
	var duration: float = 0.28
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-7.0 * t)
		var freq: float = 587.33 if t < 0.14 else 880.0
		var tone: float = sin(t * freq * TAU) * 0.7
		var chime: float = sin(t * freq * 2.0 * TAU) * 0.25
		samples[i] = (tone + chime) * env
	return _float_to_16bit_wav(samples, false)

func _generate_stove_ignite() -> AudioStreamWAV:
	var duration: float = 0.35
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = sin(PI * clampf(t / duration, 0.0, 1.0))
		var freq: float = lerpf(140.0, 45.0, t / duration)
		var whoosh: float = sin(t * freq * TAU) * 0.6
		var noise: float = (randf() * 2.0 - 1.0) * 0.4
		samples[i] = (whoosh + noise) * env
	return _float_to_16bit_wav(samples, false)

func _generate_stove_extinguish() -> AudioStreamWAV:
	var duration: float = 0.30
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-8.0 * t)
		var hiss: float = (randf() * 2.0 - 1.0) * 0.5
		var tone: float = sin(t * 220.0 * TAU) * 0.3 * (1.0 - t / duration)
		samples[i] = (hiss + tone) * env
	return _float_to_16bit_wav(samples, false)

func _generate_alarm() -> AudioStreamWAV:
	var duration: float = 0.40
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = 0.8
		var freq: float = 880.0 if fmod(t, 0.20) < 0.10 else 660.0
		var phase: float = fmod(t * freq, 1.0)
		var wave: float = 1.0 if phase < 0.5 else -1.0
		samples[i] = wave * env
	return _float_to_16bit_wav(samples, false)

func _generate_click() -> AudioStreamWAV:
	var duration: float = 0.04
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-80.0 * t)
		var pop: float = sin(t * 1800.0 * TAU) * 0.9
		samples[i] = pop * env
	return _float_to_16bit_wav(samples, false)

func _generate_error() -> AudioStreamWAV:
	var duration: float = 0.25
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-7.0 * t)
		var tone1: float = 1.0 if fmod(t * 160.0, 1.0) < 0.5 else -1.0
		var tone2: float = 1.0 if fmod(t * 170.0, 1.0) < 0.5 else -1.0
		samples[i] = (tone1 + tone2) * 0.4 * env
	return _float_to_16bit_wav(samples, false)

func _generate_engine_loop() -> AudioStreamWAV:
	var duration: float = 1.0
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var f1: float = sin(t * 55.0 * TAU) * 0.6
		var f2: float = sin(t * 110.0 * TAU) * 0.3
		var f3: float = sin(t * 165.0 * TAU) * 0.15
		var rumble: float = sin(t * 27.5 * TAU) * 0.2
		samples[i] = (f1 + f2 + f3 + rumble) * 0.7
	return _float_to_16bit_wav(samples, true)

func _generate_wind_loop() -> AudioStreamWAV:
	var duration: float = 1.5
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var last_val: float = 0.0
	for i in range(count):
		var white: float = randf() * 2.0 - 1.0
		last_val = lerpf(last_val, white, 0.08)
		samples[i] = last_val * 0.8
	var fade_len: int = 1000
	for i in range(fade_len):
		var weight: float = float(i) / float(fade_len)
		samples[i] = lerpf(samples[count - fade_len + i], samples[i], weight)
	return _float_to_16bit_wav(samples, true)

func _generate_stove_loop() -> AudioStreamWAV:
	var duration: float = 1.0
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var last_val: float = 0.0
	for i in range(count):
		var white: float = randf() * 2.0 - 1.0
		last_val = lerpf(last_val, white, 0.05)
		var crackle: float = 0.0
		if randf() < 0.005:
			crackle = (randf() * 2.0 - 1.0) * 0.7
		samples[i] = (last_val * 0.4 + crackle)
	var fade_len: int = 1000
	for i in range(fade_len):
		var weight: float = float(i) / float(fade_len)
		samples[i] = lerpf(samples[count - fade_len + i], samples[i], weight)
	return _float_to_16bit_wav(samples, true)
