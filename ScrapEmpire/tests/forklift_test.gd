extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/forklift_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var mobility=preload("res://scripts/economy/extra_mobility.gd")
	GameState.team_credits=5000
	check(not mobility.purchase("forklift"),"forklift requires industrial land")
	GameState.yard_level=1
	var player=get_tree().get_first_node_in_group("players")
	await look(player,Vector3(15,0.08,23.2),Vector3(15,1.2,25))
	player._select_vehicle(4)
	await capture("industrial_forklift_catalog")
	await click(player,"Acquista")
	check(mobility.owned("forklift") and GameState.team_credits==1800,"garage forklift purchase debits configured price")
	player._close_pause_menu()
	check(not mobility.purchase("forklift"),"forklift cannot be purchased twice")
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var vehicle=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="forklift")[0]
	vehicle.global_position=Vector3(43,0.08,57)
	player.global_position=vehicle.global_position+Vector3(1.4,0,0)
	GameState.team_deposit_counts.metal=2
	GameState.team_deposit_counts.plastic=1
	GameState.press_owned=true
	GameState.press_bales=4
	var service=GameState.crafting
	check(service.craft("bale_pallet",int(GameState.operations.serial)) and service.deploy("bale_pallet",Vector3(43,0.08,55.1),0),"industrial pallet prepared through real crafting service")
	var id: String=service.data().objects.keys()[0]
	check(service.transfer_bales(id,true),"four real bales reserved on pallet")
	check(player._mount_vehicle(vehicle),"forklift mounts through normal vehicle action")
	await frames(30)
	vehicle.lift=0.8
	check(not vehicle.toggle_load(player),"raised forks cannot grab a pallet from distance")
	vehicle.lift=0.12
	check(vehicle.toggle_load(player),"lowered aligned forks pick up pallet")
	vehicle.lift=0.8
	await frames(10)
	check(is_instance_valid(vehicle.carried) and vehicle.carried.global_position.y>0.7,"forks lift actual pallet collider")
	GameState.operations_changed.emit()
	await frames(3)
	check(get_tree().get_nodes_in_group("crafted_objects").filter(func(o):return o.craft_id==id).size()==1,"warehouse refresh cannot duplicate carried pallet")
	var start: Vector3=player.global_position
	hold_test_action("move_forward")
	await frames(120)
	release_test_action("move_forward")
	print("FORKLIFT_DRIVE speed=",player._vehicle_speed," position=",player.position," carry=",is_instance_valid(vehicle.carried)," brake=",player._vehicle_motion.parking_brake," heading=",player._vehicle_heading," floor=",player.is_on_floor()," wall=",player.is_on_wall()," travel=",player.position-start)
	check(player._vehicle_speed>0.4 and player.position.distance_to(start)>0.5 and is_instance_valid(vehicle.carried),"forklift drives with loaded pallet")
	player._vehicle_motion.parking_brake=true
	await frames(50)
	check(absf(player._vehicle_speed)<0.2,"forklift parking brake stops loaded vehicle")
	await snapshot_prop(player,vehicle,"industrial_forklift_loaded")
	vehicle.lift=0.12
	await frames(3)
	check(vehicle.release_load(player),"pallet drops onto free ground with checkpoint")
	check(GameState.press_bales==0 and service.data().objects[id].bales==4,"transport preserves four reserved bales")
	check(SaveService.save_checkpoint(99) and SaveService.load_save(99),"forklift pose and ownership pass disk validation")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(35)
	player=get_tree().get_first_node_in_group("players")
	check(get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="forklift").size()==1,"resume spawns one purchased forklift")
	check(is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.vehicle_kind=="forklift","resume restores forklift driver")
	vehicle=player._mounted_vehicle
	check(vehicle.restore_load(player,id,0.8),"saved pallet can be safely restored onto forks")
	await frames(5)
	check(is_instance_valid(vehicle.load_collision),"loaded pallet contributes a swept driver collision shape")
	check(SaveService.save_checkpoint(100) and SaveService.load_save(100),"attached pallet identity and lift survive schema validation")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(40)
	player=get_tree().get_first_node_in_group("players")
	vehicle=player._mounted_vehicle
	check(is_instance_valid(vehicle) and is_instance_valid(vehicle.carried) and vehicle.carried.craft_id==id,"resume restores the same carried pallet without duplication")
	if is_instance_valid(vehicle) and is_instance_valid(vehicle.carried):
		var bad: Dictionary=GameState.serialize().duplicate(true)
		bad.local_expedition.travel.forklift.pallet="craft_missing"
		check(not SaveService._validate_save_schema(bad),"save rejects attachment to nonexistent pallet")
		var wall=StaticBody3D.new()
		var shape=CollisionShape3D.new()
		shape.shape=BoxShape3D.new()
		shape.shape.size=Vector3(5,4,0.2)
		wall.add_child(shape)
		get_tree().current_scene.add_child(wall)
		var forward: Vector3=-player.global_basis.z
		wall.global_position=vehicle.carried.global_position+forward*1.5+Vector3.UP
		wall.rotation.y=player.rotation.y
		var origin: Vector3=player.global_position
		player._vehicle_motion.parking_brake=false
		hold_test_action("move_forward")
		await frames(180)
		release_test_action("move_forward")
		check(player.global_position.distance_to(origin)<1.2,"carried pallet stops forklift before wall instead of clipping through")
		check(get_tree().get_nodes_in_group("crafted_objects").filter(func(o):return o.craft_id==id).size()==1 and GameState.crafting.data().objects[id].bales==4,"blocked movement preserves one pallet and its four bales")
		await snapshot_prop(player,vehicle,"industrial_forklift_blocked")
		wall.queue_free()
	print("FORKLIFT_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
