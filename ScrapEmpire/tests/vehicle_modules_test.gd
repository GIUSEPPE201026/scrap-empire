extends "res://tests/single_player_cycle.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/vehicle_modules_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	GameState.team_credits = 10000
	GameState.completed_orders = [GameState.order_defs[0].id]
	check(not GameState.purchase_module("brakes"),"reinforced brakes require owned buggy")
	GameState.yard_level = 1
	GameState.vehicle_level = 2
	for id in ["brakes","tyres"]:
		check(GameState.purchase_module(id),"first vehicle module installs: "+id)
		check(not GameState.purchase_module(id),"second vehicle module waits for three orders: "+id)
	GameState.completed_orders = [GameState.order_defs[0].id,GameState.order_defs[1].id,GameState.order_defs[2].id]
	for id in ["brakes","tyres"]:
		check(GameState.purchase_module(id),"second vehicle module installs: "+id)
	check(GameState.team_credits==6950,"two vehicle module lines debit exact 3050 Bulloni")
	check(not GameState.purchase_module("tyres") and GameState.team_credits==6950,"maxed tyre module cannot charge again")
	check(SaveService.save_checkpoint(95) and SaveService.load_save(95) and GameState.workshop_modules.brakes==2 and GameState.workshop_modules.tyres==2,"new vehicle modules persist")
	sector.spawn_owned_vehicles()
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.level==2)[0]
	buggy.position = Vector3(40,0,10)
	player.position = Vector3(42,0,10)
	check(buggy.headlights.size()==2 and buggy.headlights[0].spot_range==26,"buggy owns two real headlights without personal lamp upgrade")
	check(player._mount_vehicle(buggy),"owned buggy mounts for real braking trials")
	var light_key = InputEventKey.new()
	light_key.pressed = true
	light_key.keycode = KEY_L
	player._unhandled_input(light_key)
	check(not buggy.headlights_enabled and not buggy.headlights[0].visible,"mounted L switches vehicle headlights off")
	player._unhandled_input(light_key)
	check(buggy.headlights_enabled and buggy.headlights[1].visible,"mounted L switches vehicle headlights back on")
	await frames(8)
	player.set_physics_process(false)
	var stock_distance: float = await braking_run(player,buggy,0)
	var upgraded_distance: float = await braking_run(player,buggy,2)
	print("BRAKING_DISTANCE: stock=%.3fm upgraded=%.3fm" % [stock_distance,upgraded_distance])
	check(stock_distance>0.5 and upgraded_distance<stock_distance*0.8,"upgraded brakes shorten actual stopping distance from same speed")
	var drive = player._vehicle_motion
	GameState.workshop_modules.tyres = 0
	drive.reset(0,Vector3.ZERO,GameState.vehicle_defs[1])
	drive.speed = 4
	player.velocity = Vector3(4,0,-4)
	for i in 20:
		drive.step(player,buggy,0,0,false,1.0/60)
	var stock_slip: float = absf(player.velocity.x)
	GameState.workshop_modules.tyres = 2
	drive.reset(0,Vector3.ZERO,GameState.vehicle_defs[1])
	drive.speed = 4
	player.velocity = Vector3(4,0,-4)
	for i in 20:
		drive.step(player,buggy,0,0,false,1.0/60)
	check(absf(player.velocity.x)<stock_slip*0.7,"dune tyres reduce measured lateral slip")
	var brake_key = InputEventKey.new()
	brake_key.pressed = true
	brake_key.keycode = KEY_P
	player._unhandled_input(brake_key)
	check(drive.parking_brake,"P engages persistent parking brake")
	drive.speed = 4
	for i in 60:
		drive.step(player,buggy,1,0,false,1.0/60)
		player.move_and_slide()
	var parked_position: Vector3 = player.position
	for i in 60:
		drive.step(player,buggy,1,0,false,1.0/60)
		player.move_and_slide()
	check(drive.speed==0 and player.position.distance_to(parked_position)<0.05,"parking brake holds stopped buggy even with throttle pressed")
	player._unhandled_input(brake_key)
	check(not drive.parking_brake,"P releases parking brake")
	drive.speed = 0
	drive.step(player,buggy,1,0,false,1.0/60)
	check(drive.speed>0,"released brake permits acceleration")
	drive.speed = 4
	for i in 180:
		drive.step(player,buggy,0,0,true,1.0/60)
		player.move_and_slide()
	check(absf(drive.speed)<0.1 and not drive.parking_brake,"held handbrake decelerates to rest without latching parking mode")
	player.set_physics_process(true)
	GameState.operations.world_seconds = 700.0
	get_tree().get_first_node_in_group("yard_clock").refresh_visuals()
	await frames(4)
	await capture("buggy_night_headlights")
	drive.speed = 0
	player._vehicle_speed = 0
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(5)
	player._dismount_vehicle()
	GameState.team_upgrade_levels.tool = 1
	GameState.workshop_modules.scanner = 2
	GameState.completed_orders.clear()
	for order in GameState.order_defs:
		GameState.completed_orders.append(order.id)
	check(GameState.ops.accept_delivery("garage_spares"),"certified yard accepts component supply for scanner trial")
	player.position = Vector3(0,0.1,0)
	var parts: Array = get_tree().get_nodes_in_group("bulk_parts")
	for part in parts:
		part.position = Vector3(160,0,160)
	var battery = parts.filter(func(part):return part.kind=="battery")[0]
	battery.position = Vector3(10,0,0)
	player._scan_scrap()
	check(player._navigation_target==battery.global_position and player._navigation_label.contains("FORNITURA"),"scanner prioritizes nearby missing supply component over collection")
	check(player._feedback.text.contains("riparare"),"scanner explains when detected component needs repair")
	GameState.operations.cargo_parts.append({"id":"test_battery","kind":"battery","quality":0})
	player._scan_scrap()
	check(player._navigation_label.is_empty(),"scanner counts pending cargo and does not request duplicate battery")
	GameState.operations.cargo_parts.clear()
	player._scan_scrap(true)
	check(not player._navigation_label.contains("FORNITURA"),"collection-only scan bypasses active supply search")
	await capture("supply_scanner")
	player.position = Vector3(-18,0,22.2)
	GameState.workshop_modules.tyres = 1
	player._open_development()
	player._upgrade_monitor._set_page("modules")
	await frames(3)
	var monitor = player._upgrade_monitor
	check(monitor.buy_buttons.has("brakes") and monitor.buy_buttons.has("tyres"),"physical monitor exposes vehicle upgrades")
	for scroll in monitor.display_viewport.find_children("*","ScrollContainer",true,false):
		scroll.ensure_control_visible(monitor.buy_buttons.tyres)
	await frames(3)
	await capture("vehicle_upgrade_shop")
	if DisplayServer.get_name()!="headless":
		var before: int = GameState.team_credits
		await click_physical_button(monitor,monitor.buy_buttons.tyres)
		check(GameState.workshop_modules.tyres==2 and GameState.team_credits==before-950,"physical monitor installs second tyre level for exact cost")
	player._close_pause_menu()
	print("VEHICLE_MODULES_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func braking_run(player: Node3D, buggy: Node3D, level: int) -> float:
	GameState.workshop_modules.brakes = level
	player.position = Vector3(40,0,10)
	player.velocity = Vector3(0,-0.1,0)
	player.move_and_slide()
	var drive = player._vehicle_motion
	drive.reset(0,Vector3.ZERO,GameState.vehicle_defs[1])
	drive.speed = 8
	drive.last_speed = 8
	player.velocity = Vector3(0,0,-8)
	var distance: float = 0
	for i in 180:
		var before: Vector3 = player.position
		drive.step(player,buggy,-1,0,false,1.0/60)
		player.move_and_slide()
		distance += Vector2(player.position.x-before.x,player.position.z-before.z).length()
		if drive.speed<=0:
			break
		await frames(1)
	return distance
