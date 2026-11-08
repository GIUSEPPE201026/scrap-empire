extends "res://tests/crafting_test.gd"
const SITES=preload("res://scripts/gameplay/leisure_sites.gd")

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/leisure_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	var site=get_tree().get_first_node_in_group("leisure_sites")
	var navigation: Dictionary=preload("res://scripts/gameplay/yard_navigation.gd").points(player)
	check(navigation.has("oasis") and navigation.has("dune_park"),"both playable destinations appear on actual map")
	check(get_tree().get_nodes_in_group("park_ramps").size()==3,"park contains three real collision ramps")
	var terrain=preload("res://scripts/gameplay/desert_world.gd")
	check(is_equal_approx(terrain.height_at(SITES.PARK),4.0) and terrain.height_at(SITES.OASIS)<1.85,"park has a physical level pad and oasis a shallow basin")
	check(terrain.height_at(Vector3(638,0,0))>38 and terrain.height_at(Vector3(638,0,0))<95,"outer dunes conceal the old flat perimeter within saveable height")
	var space=player.get_world_3d().direct_space_state
	var raised=preload("res://scripts/save/travel_snapshot.gd")._ground(player,Vector3(570,0,0),[player.get_rid()])
	check(not raised.is_empty() and raised.position.y>8,"older checkpoint altitude resolves the real surface of a raised outer dune")
	var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(SITES.PARK+Vector3(-38,8,0),SITES.PARK+Vector3(-38,0,0),1,[player.get_rid()]))
	check(not hit.is_empty() and hit.position.y>6,"tabletop has a matching raised collision surface")
	player.position=navigation.oasis.position+Vector3(2,0.1,0)
	GameState.player_inventories[1].metal=3
	var count: int=GameState.team_deposit_counts.metal
	player._deposit_field()
	check(GameState.player_inventories[1].metal==0 and GameState.team_deposit_counts.metal==count+3,"oasis satellite is useful and conserves materials")
	player._close_pause_menu()
	await look(player,SITES.OASIS+Vector3(-35,8,-30),SITES.OASIS+Vector3(0,3,0))
	await capture("leisure_oasis")
	GameState.vehicle_level=2
	GameState.yard_level=1
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
	site.set_process(false)
	var serial: int=GameState.operations.serial
	site._last_position=SITES.PARK+SITES.GATES[0]
	site.advance(site._last_position,buggy,0.1)
	check(site.checkpoint==1,"mounted vehicle starts timed circuit at start gate")
	site._last_position=SITES.PARK+SITES.GATES[3]
	site.advance(site._last_position,buggy,2.0)
	check(site.checkpoint==1,"out of order checkpoint cannot finish or skip circuit")
	for index in range(1,7):
		site._last_position=SITES.PARK+SITES.GATES[index%6]
		site.advance(site._last_position,buggy,3.0)
	check(site.checkpoint==-1 and float(site.best.get(2,0))>0,"complete ordered circuit records buggy session time")
	var record: float=float(site.best[2])
	check(SaveService.save_checkpoint(82) and SaveService.load_save(82) and is_equal_approx(float(GameState.operations.park_records["2"]),record),"completed park record survives disk roundtrip")
	check(not GameState.ops.record_lap(2,record+1) and not GameState.ops.record_lap(5,10) and not GameState.ops.record_lap(1,NAN),"slower laps invalid vehicles and nonfinite times cannot replace records")
	var invalid: Dictionary=GameState.serialize().duplicate(true)
	invalid.operations.park_records={"2":-1}
	check(not SaveService._validate_save_schema(invalid),"malformed park records rejected on loading")
	var original: String=SaveService.SAVE_DIR
	SaveService.SAVE_DIR="res://project.godot/"
	var print_errors: bool=Engine.print_error_messages
	Engine.print_error_messages=false
	var failed: bool=GameState.ops.record_lap(2,record-1)
	Engine.print_error_messages=print_errors
	SaveService.SAVE_DIR=original
	check(not failed and is_equal_approx(float(GameState.operations.park_records["2"]),record),"failed park checkpoint restores previous valid best time")
	site.advance(SITES.PARK+SITES.GATES[0],buggy,0.1)
	check(site.checkpoint==-1,"standing in finish gate cannot restart or farm laps")
	check(GameState.operations.serial==serial,"time trial does not mutate economy or grant farmable money")
	site._last_position=SITES.PARK+SITES.GATES[0]+Vector3(15,0,0)
	site.advance(site._last_position,buggy,0.1)
	site.advance(SITES.PARK+SITES.GATES[0],buggy,0.1)
	site.advance(SITES.PARK+SITES.GATES[0],null,1.0)
	check(site.checkpoint==-1,"leaving the vehicle cancels incomplete lap")
	if DisplayServer.get_name()!="headless":
		check(site.markers[0].material_override.albedo_color==Color("#ffd166"),"cancelled lap visibly points back to start gate")
	var slip: Array[float]=[]
	for handbrake in [false,true]:
		buggy.position=SITES.PARK+Vector3(-9,0.08,29)
		buggy.rotation.y=0
		player.position=buggy.position+Vector3(2,0,0)
		player.velocity=Vector3.ZERO
		check(player._mount_vehicle(buggy),"buggy enters for measured steering comparison")
		await frames(20)
		hold_test_action("move_forward")
		await frames(130)
		hold_test_action("move_right")
		if handbrake: hold_test_action("jump")
		var peak: float=0
		for index in 55:
			await get_tree().physics_frame
			peak=maxf(peak,player._vehicle_motion.drift_angle)
		slip.append(peak)
		release_test_action("jump")
		release_test_action("move_right")
		release_test_action("move_forward")
		if handbrake:
			check(player._vehicle_motion.drift_blend>0.8 and absf(player._vehicle_speed)>2,"held handbrake unlocks lateral grip without instant stopping")
			player._vehicle_third_person=true
			player._update_vehicle_camera()
			await capture("leisure_buggy_drift")
			await frames(150)
			check(player._vehicle_motion.drift_blend<0.01,"releasing handbrake restores tyre grip progressively")
		player._vehicle_motion.parking_brake=true
		await frames(120)
		player._dismount_vehicle()
		await frames(4)
	print("DRIFT_METRICS normal=",slip[0]," handbrake=",slip[1])
	check(slip[1]>slip[0]*1.8 and slip[1]>0.15,"actual handbrake curve has materially more lateral slip than normal curve")
	buggy.position=SITES.PARK+Vector3(-38,0.08,32)
	buggy.rotation.y=0
	player.position=buggy.position+Vector3(2,0,0)
	check(player._mount_vehicle(buggy),"buggy mounts for real ramp crossing")
	await frames(20)
	hold_test_action("move_forward")
	var peak_height: float=player.position.y
	for index in 480:
		await get_tree().physics_frame
		if absf(player.position.z-SITES.PARK.z)<18: peak_height=maxf(peak_height,player.position.y)
	release_test_action("move_forward")
	print("RAMP_METRICS peak=",peak_height," end=",player.position," speed=",player._vehicle_speed)
	await capture("leisure_ramp_end")
	check(peak_height>5.5 and player.position.z<SITES.PARK.z-15 and player.position.is_finite(),"actual buggy climbs and clears the tabletop through normal controller collision")
	player._vehicle_motion.parking_brake=true
	await frames(120)
	player._dismount_vehicle()
	await frames(5)
	var scooter=get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==1)[0]
	scooter.position=SITES.PARK+Vector3(0,0.08,28)
	scooter.show()
	player.position=scooter.position+Vector3(1,0,0)
	check(player._mount_vehicle(scooter),"scooter enters the same recreation park")
	await frames(20)
	var start_y: float=player.position.y
	hold_test_action("move_forward")
	await frames(35)
	hold_test_action("jump")
	await frames(1)
	release_test_action("jump")
	await frames(15)
	check(player.position.y>start_y+0.5,"scooter retains actual jump in park after drivetrain changes")
	release_test_action("move_forward")
	await frames(75)
	player._dismount_vehicle()
	await frames(4)
	await look(player,SITES.PARK+Vector3(63,25,62),SITES.PARK)
	await capture("leisure_park")
	player._open_inventory()
	await frames(5)
	var tiles: Array=player._panel_box.find_children("*","Button",true,false).filter(func(button):return button.has_meta("tool_slot"))
	check(tiles.size()==5 and tiles.all(func(button):return button.find_children("*","TextureRect",true,false).any(func(rect):return rect.texture!=null) and not button.tooltip_text.is_empty()),"five equipment slots are actual illustrated controls with identifying tooltips")
	await capture("leisure_icon_inventory")
	player._close_pause_menu()
	print("LEISURE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
