extends "res://tests/crafting_test.gd"

func round_trip(player) -> Node3D:
	player._do_quit_to_menu()
	await frames(12)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	return get_tree().get_first_node_in_group("players")

func buggy() -> Node3D:
	return get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/travel_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	GameState.yard_level=1
	GameState.vehicle_level=2
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	buggy().position=Vector3(40,0.05,35)
	buggy().rotation.y=0.7
	buggy().toggle_headlights()
	await look(player,Vector3(36,0.05,36),Vector3(38,1.2,35))
	var point: Vector3 = player.global_position
	var direction: Vector2 = player.look_rotation
	check(SaveService.save_checkpoint(93),"walking and parked vehicle pose checkpoint saves")
	var snapshot: Dictionary = GameState.serialize().duplicate(true)
	check(SaveService._validate_save_schema(snapshot),"local travel snapshot validates with ordinary expedition")
	player = await round_trip(player)
	check(player.global_position.distance_to(point)<0.2 and player.look_rotation.distance_to(direction)<0.02,"menu resume restores actual walking location and viewing direction")
	check(buggy().global_position.distance_to(Vector3(40,0.05,35))<0.2 and absf(buggy().rotation.y-0.7)<0.02,"parked buggy no longer teleports back to garage")
	check(not buggy().headlights_enabled and buggy().parked,"parked lighting and standstill state persist")
	await capture("travel_walking_resume")
	var terrain = preload("res://scripts/gameplay/desert_world.gd")
	player.position=Vector3(0,terrain.height_at(Vector3(0,0,120))+1,120)
	player.velocity=Vector3.ZERO
	await frames(90)
	check(player.is_on_floor(),"dune resume trial starts from a real supported terrain location")
	var dune_point: Vector3 = player.position
	player = await round_trip(player)
	check(player.position.distance_to(dune_point)<0.3,"free-roaming dune location resumes without falling back to base")
	player.position=buggy().to_global(Vector3(2,0.1,0))
	check(player._mount_vehicle(buggy()),"mount retained vehicle before drive-resume trial")
	player._vehicle_third_person=true
	Input.action_press("move_forward")
	await frames(70)
	Input.action_release("move_forward")
	var driven: Vector3 = player.global_position
	check(player._vehicle_speed>1,"vehicle is genuinely moving at save boundary")
	player = await round_trip(player)
	check(player._mounted_vehicle==buggy() and player._vehicle_third_person,"resume restores buggy seat and external view")
	check(player.global_position.distance_to(driven)<0.5 and absf(player._vehicle_speed)<0.05 and player._vehicle_motion.parking_brake,"driving resumes at retained location safely stopped with parking brake")
	await capture("travel_buggy_resume")
	player._dismount_vehicle()
	await frames(5)
	player.position=Vector3(48,0.1,36)
	player._toggle_scooter()
	await frames(5)
	check(player._mounted_vehicle!=null and player._mounted_vehicle.level==1,"portable scooter equips for persistence trial")
	player = await round_trip(player)
	check(player._mounted_vehicle!=null and player._mounted_vehicle.level==1 and player.global_position.distance_to(Vector3(48,0.1,36))<0.3,"equipped scooter resumes under rider without spawning extra world vehicles")
	player._toggle_scooter()
	for key in ["yaw","pitch"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.local_expedition.travel.player[key]=INF
		check(not SaveService._validate_save_schema(bad),"nonfinite travel angle rejected: "+key)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.local_expedition.travel.player.position=[900,0,0]
	check(not SaveService._validate_save_schema(bad),"out-of-world resume coordinates rejected")
	bad=snapshot.duplicate(true)
	bad.vehicle_level=0
	check(not SaveService._validate_save_schema(bad),"unowned vehicle cannot be reconstructed by travel payload")
	bad=snapshot.duplicate(true)
	bad.local_expedition.travel.epoch+=1
	check(not SaveService._validate_save_schema(bad),"stale or future expedition travel epoch rejected")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.local_expedition.erase("travel")
	check(SaveService._validate_save_schema(legacy),"expedition saves predating travel remain valid")
	GameState.local_travel={"epoch":int(GameState.operations.epoch),"player":{"position":[4,95,4],"yaw":0,"pitch":0,"vehicle":0,"third_person":false}}
	player.position=preload("res://scripts/gameplay/arrival_area.gd").SPAWN
	await preload("res://scripts/save/travel_snapshot.gd").restore(player)
	check(player.position.distance_to(preload("res://scripts/gameplay/arrival_area.gd").SPAWN)<0.4,"unsupported resume location falls back safely to arrival")
	GameState.local_travel=snapshot.local_expedition.travel.duplicate(true)
	var old_epoch: int = GameState.operations.epoch
	check(GameState.reset_for_new_mission("C01",true) and GameState.operations.epoch==old_epoch+1,"explicit new expedition advances epoch with persistent vehicle ownership")
	SessionState.transition_to(SessionState.ConnectionState.LOADING)
	get_tree().reload_current_scene()
	await frames(30)
	player=get_tree().get_first_node_in_group("players")
	check(player.position.distance_to(preload("res://scripts/gameplay/arrival_area.gd").SPAWN)<0.3,"new expedition starts at arrival instead of restoring stale traveler")
	check(buggy().position.distance_to(Vector3(22,0,30))<0.2,"explicit new expedition resets parked vehicle to garage")
	print("TRAVEL_RESUME_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
