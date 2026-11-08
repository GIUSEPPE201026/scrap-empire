extends Node
## Original, short procedural Foley. Generated once; all voices respect the SFX bus.
static var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var engine: AudioStreamPlayer
var player: Node3D
var previous_credits: int = 0
var stride: float = 0
var next_voice: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("yard_audio")
	if AudioServer.get_bus_index("SFX")<0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,"SFX")
	if streams.is_empty():
		for kind in ["metal","plastic","electronics","deposit","sale","craft","step","engine"]:
			streams[kind] = _make_stream(kind)
	for index in 6:
		var voice = AudioStreamPlayer.new()
		voice.bus = "SFX"
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)
	engine = AudioStreamPlayer.new()
	engine.bus = "SFX"
	engine.stream = streams.engine
	engine.volume_db = -29
	add_child(engine)
	previous_credits = GameState.team_credits
	GameState.credits_changed.connect(_credits)

func _credits(amount: int) -> void:
	if amount>previous_credits:
		play_event("sale")
	elif amount<previous_credits:
		play_event("craft")
	previous_credits = amount

func play_event(kind: String) -> void:
	if not streams.has(kind) or voices.is_empty():
		return
	var voice: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice+1)%voices.size()
	voice.stream = streams[kind]
	voice.volume_db = -27 if kind=="step" else -15
	voice.pitch_scale = 1
	# The dummy audio driver retains pending playbacks at process shutdown.
	# Headless checks validate the samples/routing; real playback is tested rendered.
	if DisplayServer.get_name()!="headless":
		voice.play()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players")
	if not is_instance_valid(player):
		return
	if get_tree().paused or not player.is_local_player:
		engine.stop()
		return
	var buggy: bool = is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.level in [2,3]
	if buggy:
		if not engine.playing and DisplayServer.get_name()!="headless":
			engine.play()
		engine.pitch_scale = clampf(0.65+absf(player._vehicle_speed)*0.07,0.65,1.65)
		engine.volume_db = -29+minf(absf(player._vehicle_speed),10)*0.4
	else:
		engine.stop()
	var speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	if not is_instance_valid(player._mounted_vehicle) and player.is_on_floor() and speed>0.4:
		stride += speed*delta
		if stride>=1.65:
			stride = fmod(stride,1.65)
			play_event("step")
	else:
		stride = 0

static func _make_stream(kind: String) -> AudioStreamWAV:
	var duration: float = {"metal":0.19,"plastic":0.13,"electronics":0.17,"deposit":0.24,"sale":0.3,"craft":0.28,"step":0.12,"engine":1.0}[kind]
	var rate: int = 22050
	var samples: int = int(duration*rate)
	var bytes = PackedByteArray()
	bytes.resize(samples*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = absi(kind.hash())
	for index in samples:
		var t: float = float(index)/rate
		var noise: float = rng.randf_range(-1,1)
		var value: float = 0
		match kind:
			"metal": value = (sin(TAU*1740*t)*0.35+sin(TAU*2870*t)*0.15+noise*0.12)*exp(-t*30)
			"plastic": value = (sin(TAU*230*t)*0.25+noise*0.35)*exp(-t*38)
			"electronics": value = (sin(TAU*770*t)+sin(TAU*1160*t))*0.18*exp(-t*23)
			"deposit": value = (sin(TAU*95*t)*0.55+noise*0.2)*exp(-t*20)
			"sale":
				for tone in 3:
					var age: float = t-tone*0.055
					if age>=0:
						value += sin(TAU*[880,1108,1320][tone]*age)*0.25*exp(-age*24)
			"craft": value = (sin(TAU*(260+350*t)*t)*0.25+noise*0.15)*exp(-t*12)
			"step": value = (noise*0.35+sin(TAU*120*t)*0.2)*exp(-t*40)
			"engine": value = (sin(TAU*63*t)*0.3+sin(TAU*126*t)*0.12+sin(TAU*189*t)*0.06+noise*0.035)
		var edge: float = minf(1,minf(t/0.004,(duration-t)/0.008))
		var sample: int = roundi(clampf(value*edge,-0.8,0.8)*32767)
		bytes[index*2] = sample & 255
		bytes[index*2+1] = (sample>>8) & 255
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if kind=="engine":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples
	return stream

func _exit_tree() -> void:
	if is_instance_valid(engine):
		engine.stop()
		engine.stream = null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

