extends "res://tests/crafting_test.gd"
var result: Dictionary = {}

func sample(player, label: String, point: Vector3, target: Vector3) -> void:
	await look(player,point,target)
	await frames(30)
	var frame_times: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	var process: Array[float] = []
	var physics: Array[float] = []
	var draws: Array[float] = []
	for frame in 120:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		frame_times.append(float(now-previous)/1000.0)
		previous=now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frame_times.sort()
	var start: int = Time.get_ticks_usec()
	for index in 200:
		preload("res://scripts/gameplay/interaction_focus.gd").resolve(player)
	var focus_us: float = float(Time.get_ticks_usec()-start)/200.0
	start=Time.get_ticks_usec()
	for index in 200:
		player._update_inventory_hud()
	var inventory_us: float = float(Time.get_ticks_usec()-start)/200.0
	start=Time.get_ticks_usec()
	for index in 100:
		player._update_hint()
	var hint_us: float = float(Time.get_ticks_usec()-start)/100.0
	result[label]={"frame_median_ms":frame_times[60],"frame_p95_ms":frame_times[114],"process_mean_ms":_mean(process),"physics_mean_ms":_mean(physics),"draw_calls_mean":_mean(draws),"focus_call_us":focus_us,"inventory_call_us":inventory_us,"hint_call_us":hint_us,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	print("PROFILE "+label+" "+JSON.stringify(result[label]))
	await capture("profile_"+label)

func _mean(values: Array[float]) -> float:
	var total: float = 0
	for value in values:
		total+=value
	return total/maxi(1,values.size())

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/profile_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	GameState.yard_level=2
	GameState.vehicle_level=2
	GameState.team_upgrade_levels.tool=2
	sector.apply_land_expansions()
	sector.spawn_owned_vehicles()
	GameState.ops.seed_field_parts()
	await frames(30)
	result.static_batches=sector.get_meta("static_art_batches",{})
	result.context={"engine":Engine.get_version_info().string,"renderer":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y],"note":"120 frames per point after warmup; scripted 60Hz simulation; wall frame spacing includes GPU and OS scheduling; no before/after FPS claim"}
	if OS.get_cmdline_user_args().has("--compare-sky"):
		var sky: Sky = sector.get_node("WorldEnvironment").environment.sky
		for mode in ["realtime128","quality32","realtime128_repeat","quality32_repeat"]:
			sky.process_mode=Sky.PROCESS_MODE_QUALITY if mode.begins_with("quality") else Sky.PROCESS_MODE_REALTIME
			sky.radiance_size=Sky.RADIANCE_SIZE_32 if mode.begins_with("quality") else Sky.RADIANCE_SIZE_128
			await frames(90)
			await sample(player,mode,Vector3(-8,0.1,2),Vector3(0,1,22))
		var probe = FileAccess.open("res://test_logs/profile_sky.json",FileAccess.WRITE)
		probe.store_string(JSON.stringify(result,"\t"))
		probe.close()
		print("SKY_PERFORMANCE_PROBE_COMPLETE")
		get_tree().quit()
		return
	await sample(player,"hub",Vector3(-8,0.1,2),Vector3(0,1,22))
	await sample(player,"piles",Vector3(20,0.1,-25),Vector3(0,2,-40))
	await sample(player,"lot2",Vector3(188,0.1,7),Vector3(218,2,15))
	var terrain = preload("res://scripts/gameplay/desert_world.gd")
	await sample(player,"dunes",Vector3(0,terrain.height_at(Vector3(0,0,120))+0.1,120),Vector3(20,5,180))
	var tag: String = "after" if OS.get_cmdline_user_args().has("--after") else "before"
	var file = FileAccess.open("res://test_logs/profile_"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("PERFORMANCE_PROBE_COMPLETE")
	get_tree().quit()
