extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/audio_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var audio = get_tree().get_first_node_in_group("yard_audio")
	check(audio!=null and audio.voices.size()==6,"bounded six-voice feedback pool exists")
	for kind in ["metal","plastic","electronics","deposit","sale","craft","step","engine"]:
		var stream: AudioStreamWAV = audio.streams[kind]
		check(stream!=null and stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.data.size()>1000 and stream.get_length()>0,"valid original waveform: "+kind)
	check(audio.streams.metal.data!=audio.streams.plastic.data and audio.streams.electronics.data!=audio.streams.metal.data,"three material families have distinct sound data")
	audio.play_event("metal")
	check(audio.voices.any(func(voice):return (voice.playing or DisplayServer.get_name()=="headless") and voice.stream==audio.streams.metal),"collection cue routes to playback voice (playing checked with renderer)")
	check(audio.voices.all(func(voice):return voice.bus=="SFX") and audio.engine.bus=="SFX","feedback and motor both follow user SFX bus")
	var bus: int = AudioServer.get_bus_index("SFX")
	var previous_volume: float = AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_volume_db(bus,-60)
	audio.play_event("sale")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),-60),"playing a cue cannot override configured effects volume")
	AudioServer.set_bus_volume_db(bus,previous_volume)
	GameState.yard_level = 1
	GameState.vehicle_level = 2
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(vehicle):return vehicle.level==2)[0]
	buggy.position=Vector3(43,0,60)
	player.position = buggy.position+Vector3(1.5,0,0)
	check(player._mount_vehicle(buggy),"audio trial mounts actual buggy")
	await frames(4)
	check(audio.engine.playing if DisplayServer.get_name()!="headless" else audio.engine.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"mounted buggy configures loop and starts playback with real renderer")
	hold_test_action("move_forward")
	await frames(90)
	release_test_action("move_forward")
	check(player._vehicle_speed>3.6 and audio.engine.pitch_scale>0.9,"motor pitch follows actual accelerated displacement rather than an injected speed")
	player._open_pause_menu()
	await frames(3)
	check(not audio.engine.playing,"pause silences motor instead of idling through menu")
	audio.play_event("craft")
	check(audio.voices.any(func(voice):return (voice.playing or DisplayServer.get_name()=="headless") and voice.stream==audio.streams.craft),"menu action feedback remains available while world paused")
	player._close_pause_menu()
	await frames(4)
	player._vehicle_motion.parking_brake=true
	await frames(90)
	player._dismount_vehicle()
	await frames(3)
	check(player._mounted_vehicle==null,"audio stop trial really completes dismount on clear ground")
	check(not audio.engine.playing,"leaving vehicle stops motor loop")
	print("AUDIO_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
