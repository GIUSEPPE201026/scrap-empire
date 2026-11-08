extends "res://tests/crafting_test.gd"

func run() -> void:
	if OS.get_cmdline_user_args().has("--720"):
		get_window().size=Vector2i(1280,720)
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/garage_recovery_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	var ops = GameState.ops
	GameState.yard_level=1
	GameState.vehicle_level=2
	GameState.team_credits=500
	sector.spawn_owned_vehicles()
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
	var slot: Array = GameState.logistics_def.buggy_parking
	var parking = Vector3(slot[0],slot[1],slot[2])
	var cost: int = GameState.logistics_def.buggy_recovery_cost
	GameState.player_inventories[1].metal=2
	check(ops.transfer_bag_to_cargo(1),"raw stock placed in actual buggy cargo before rescue")
	var wheel: Dictionary = GameState.operations.field.values().filter(func(item):return item.kind=="wheel")[0]
	check(ops.pickup_part(wheel.id) and ops.load_held() and ops.cargo_mass()==16,"identified bulky part shares loaded cargo with raw material")
	buggy.position=Vector3(70,0.05,40)
	buggy.rotation.y=1
	buggy.visual.rotation.x=0.3
	buggy.wheels[0].position.y=0.25
	buggy.wheels[1].position.y=0.55
	buggy.wheels[0].rotation.y=0.3
	var compressed: Vector3 = buggy.wheels[0].position
	var original: Transform3D = buggy.global_transform
	var epoch: int = GameState.operations.epoch
	check(not GameState.reset_for_new_mission("C01",true) and GameState.operations.epoch==epoch and ops.cargo_mass()==16,"renewing sector cannot teleport a loaded buggy to base for free")
	GameState.team_credits=cost-1
	check(not ops.recover_buggy(buggy) and buggy.global_transform==original,"rescue rejects insufficient funds without moving vehicle")
	GameState.team_credits=500
	buggy.set_parked(false)
	check(not ops.recover_buggy(buggy) and GameState.team_credits==500,"rescue cannot move occupied or active buggy")
	buggy.set_parked(true)
	var blocker = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(2,2,2)
	blocker.add_child(shape)
	sector.add_child(blocker)
	blocker.position=parking+Vector3.UP
	await frames(3)
	check(not ops.recover_buggy(buggy) and buggy.global_transform==original and GameState.team_credits==500,"blocked parking refuses rescue and charges nothing")
	blocker.queue_free()
	await frames(3)
	var directory: String = SaveService.SAVE_DIR
	var output: bool = Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed: bool = ops.recover_buggy(buggy)
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(not failed and buggy.global_transform==original and is_equal_approx(buggy.visual.rotation.x,0.3) and GameState.team_credits==500 and ops.cargo_mass()==16,"failed rescue checkpoint restores money actual vehicle transform suspension pose and cargo")
	check(buggy.wheels[0].position.is_equal_approx(compressed) and is_equal_approx(buggy.wheels[0].rotation.y,0.3),"failed rescue preserves original wheel compression and steering")
	await look(player,Vector3(15,0.05,23),Vector3(15,1.3,25))
	player._select_vehicle(1)
	await frames(4)
	await capture("garage_recovery_service")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=get_viewport().get_visible_rect().size.y-20,"owned vehicle service panel fits viewport")
	await click(player,"SOCCORSO")
	check(GameState.team_credits==500-cost and buggy.position.distance_to(parking)<0.01 and buggy.visual.rotation.length()<0.01,"garage UI charges data-defined fee and places buggy in free parking")
	check(buggy.wheels.all(func(pivot):return pivot.position.is_equal_approx(pivot.get_meta("rest_position")) and absf(pivot.rotation.y)<0.001),"successful flat parking resets asymmetric wheel compression and centers steering")
	check(ops.cargo_mass()==16 and GameState.operations.cargo_parts[0].id==wheel.id and int(GameState.operations.cargo.metal)==2,"rescue conserves exact identified and raw load")
	check(not ops.recover_buggy(buggy) and GameState.team_credits==500-cost,"repeated callback at existing parking cannot charge twice")
	check(SaveService.save_checkpoint(97) and SaveService.load_save(97) and GameState.local_travel.buggy.position==[parking.x,parking.y,parking.z],"recovered parking pose and charge persist in same checkpoint")
	player._do_quit_to_menu()
	await frames(12)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
	check(buggy.position.distance_to(parking)<0.2 and ops.cargo_mass()==16 and GameState.team_credits==500-cost,"scene reentry retains successful rescue and full load without duplicate fee")
	check(ops.unload_cargo() and GameState.team_deposit_counts.metal==2 and GameState.operations.stored_parts[0].id==wheel.id,"rescued load can be unloaded once through normal logistics")
	check(GameState.reset_for_new_mission("C01",true) and GameState.operations.epoch==epoch+1,"unloaded vehicle permits intended fresh expedition")
	print("GARAGE_RECOVERY_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
