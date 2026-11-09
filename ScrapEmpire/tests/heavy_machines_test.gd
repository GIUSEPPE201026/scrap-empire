extends "res://tests/crafting_test.gd"
func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/heavy_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var mobility=preload("res://scripts/economy/extra_mobility.gd")
	GameState.team_credits=20000
	check(not mobility.purchase("crane"),"crane respects land requirement")
	GameState.yard_level=2
	var player=get_tree().get_first_node_in_group("players")
	await look(player,Vector3(15,0.08,23.2),Vector3(15,1.2,25))
	player._select_vehicle(5)
	await capture("crane_garage_catalog")
	await click(player,"Acquista")
	player._select_vehicle(6)
	await click(player,"Acquista")
	player._close_pause_menu()
	check(mobility.owned("crane") and mobility.owned("loader") and GameState.team_credits==9300,"industrial garage purchases debit their individual prices")
	check(not mobility.purchase("crane"),"duplicate crane purchase cannot debit money")
	var jobs=preload("res://scripts/economy/industrial_jobs.gd")
	var work: bool=OS.get_cmdline_user_args().has("--industrial-work")
	if work:
		player._select_vehicle(5)
		player._pause_menu.get_meta("vehicle_job_tabs").current_tab=1
		await click(player,"Accetta incarico")
		check(jobs.progress("crane").active,"garage accepts crane recovery contract")
		player._select_vehicle(6)
		player._pause_menu.get_meta("vehicle_job_tabs").current_tab=1
		await click(player,"Accetta incarico")
		check(jobs.progress("loader").active,"garage accepts loader bulk contract")
		player._close_pause_menu()
	var sector=get_tree().get_first_node_in_group("sector")
	sector.spawn_owned_vehicles()
	GameState.ops.seed_field_parts()
	var crane=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="crane")[0]
	var loader=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="loader")[0]
	var engine=get_tree().get_nodes_in_group("bulk_parts").filter(func(p):return p.kind=="engine")[0]
	var engine_id: String=engine.part_id
	GameState.operations.field[engine.part_id].position=[43,0.12,57.2]
	GameState.operations_changed.emit()
	crane.position=Vector3(43,0.08,60)
	player.position=crane.position+Vector3(1.4,0,0)
	check(player._mount_vehicle(crane),"crane boards through standard vehicle path")
	await frames(30)
	var origin: Vector3=engine.global_position
	engine.global_position+=Vector3(0,0,-10)
	var incompatible=preload("res://scripts/gameplay/haul_part.gd").new()
	incompatible.kind="battery"
	incompatible.part_id="fixture_incompatible"
	get_tree().current_scene.add_child(incompatible)
	incompatible.global_position=origin
	check(not crane.pickup(player),"magnet rejects incompatible battery instead of collecting all components")
	incompatible.queue_free()
	engine.global_position=origin
	GameState.logistics_def.mobility.crane.capacity_kg=1
	check(not crane.pickup(player),"magnet rejects payload over configured capacity")
	GameState.logistics_def.mobility.crane.capacity_kg=300
	check(crane.pickup(player) and crane.load_items.has(engine),"magnet attaches real ferrous engine")
	crane.lift=1.3
	await frames(10)
	check(engine.global_position.y>0.7,"crane hoists actual heavy component")
	await snapshot_prop(player,crane,"mobile_crane_loaded")
	crane.lift=0.3
	await frames(5)
	check(crane.release_load(player) and GameState.operations.field.has(engine.part_id),"crane release checkpoints existing component without consuming it")
	player._dismount_vehicle()
	loader.position=Vector3(43,0.08,35)
	var pieces=get_tree().get_nodes_in_group("scrap")
	for index in 2: pieces[index].position=Vector3(42.6+index*0.8,0.12,32.8)
	player.position=loader.position+Vector3(1.4,0,0)
	check(player._mount_vehicle(loader),"loader boards independently from crane")
	await frames(25)
	check(loader.pickup(player) and loader.load_items.has(pieces[0]) and loader.load_items.has(pieces[1]),"bucket carries multiple actual loose scraps")
	loader.lift=0.8
	await frames(5)
	check(pieces[0].position.y>0.5,"loader lifts physical contents without inventory credit")
	await snapshot_prop(player,loader,"mini_loader_loaded")
	loader.lift=0.2
	await frames(5)
	check(loader.release_load(player) and GameState.operations.loose_positions.has(pieces[0].entity_id),"loader release persists original scrap identities")
	check(GameState.get_inventory_mass(1)==0 and not pieces[0].is_queued_for_deletion(),"mechanical transport never credits or consumes loose scrap")
	await frames(3)
	check(loader.pickup(player),"loader can pick the same released scraps again")
	loader.lift=0.8
	await frames(5)
	var invalid: Dictionary=GameState.serialize().duplicate(true)
	invalid.local_expedition.travel.loader.load.append(invalid.local_expedition.travel.loader.load[0])
	check(not SaveService._validate_save_schema(invalid),"duplicated suspended load identity rejected on disk")
	check(SaveService.save_checkpoint(104) and SaveService.load_save(104),"both industrial machines pass save validation")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(40)
	player=get_tree().get_first_node_in_group("players")
	check(is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.vehicle_kind=="loader","resume restores loader driver")
	loader=player._mounted_vehicle
	check(loader.load_items.size()>=2 and loader.proxies.size()==loader.load_items.size(),"resume restores actual loader contents and collision proxies")
	check(get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind in ["loader","crane"]).size()==2,"resume never duplicates industrial purchases")
	loader.lift=0.2
	await frames(5)
	player._dismount_vehicle()
	await frames(3)
	crane=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="crane")[0]
	player.position=crane.position+Vector3(1.4,0,0)
	check(player._mount_vehicle(crane),"crane can resume work after loader session")
	await frames(20)
	print("CRANE_REATTACH point=",crane.payload_point()," lift=",crane.lift," field=",GameState.operations.field.get(engine_id,{})," pose=",crane.global_position," player=",player.global_position)
	check(crane.pickup(player),"released ferrous component remains available")
	crane.lift=1.3
	await frames(5)
	check(SaveService.save_checkpoint(105),"suspended crane payload checkpoints successfully")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(40)
	player=get_tree().get_first_node_in_group("players")
	crane=player._mounted_vehicle
	check(is_instance_valid(crane) and crane.vehicle_kind=="crane" and crane.load_items.size()==1 and crane.load_items[0].part_id==engine_id,"resume restores the same suspended engine on magnet")
	var unload=preload("res://scripts/economy/industrial_unload.gd")
	var depot=get_tree().get_first_node_in_group("sector").get_node("DepositZone")
	check(not unload.unload(crane,player),"industrial unload is rejected away from storage")
	player.global_position=depot.global_position+Vector3(0,0.08,5)
	await frames(5)
	var directory: String=SaveService.SAVE_DIR
	var errors: bool=Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed: bool=unload.unload(crane,player)
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(not failed and crane.load_items.size()==1 and GameState.operations.field.has(engine_id),"failed industrial unload preserves suspended component and field receipt")
	if work: check(jobs.progress("crane").units==0,"failed cargo checkpoint awards no job progress")
	var credits: int=GameState.team_credits
	check(unload.unload(crane,player) and not GameState.operations.field.has(engine_id) and GameState.ops._part_index(engine_id)>=0,"crane unload transfers actual component into warehouse atomically")
	if work: check(jobs.progress("crane").units==1,"real magnet deposit advances crane purpose")
	check(not unload.unload(crane,player) and GameState.team_credits==credits,"unload never sells or duplicates stored component")
	if work: check(jobs.progress("crane").units==1,"replayed crane unload never advances contract twice")
	await frames(3)
	player._dismount_vehicle()
	await frames(3)
	loader=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="loader")[0]
	player.position=loader.position+Vector3(1.4,0,0)
	check(player._mount_vehicle(loader),"loader available after crane warehouse unload")
	await frames(20)
	check(loader.pickup(player),"loader can collect remaining loose pieces for direct unload")
	var count: int=loader.load_items.size()
	var stored_before: int=GameState.team_deposit_counts.values().reduce(func(total,n):return int(total)+int(n),0)
	GameState.player_inventories[1].metal=10
	loader.lift=0.9
	player.global_position=depot.global_position+Vector3(0,0.08,5)
	player._vehicle_motion.parking_brake=true
	await frames(60)
	var command=InputEventKey.new()
	command.physical_keycode=KEY_G
	command.pressed=true
	inject_input(command)
	await frames(2)
	command=command.duplicate()
	command.pressed=false
	inject_input(command)
	check(loader.load_items.is_empty(),"G unloads loader directly despite full personal bag")
	check(GameState.team_deposit_counts.values().reduce(func(total,n):return int(total)+int(n),0)==stored_before+count and GameState.get_inventory_mass(1)==20,"direct unload conserves exact pieces and leaves bag unchanged")
	check(not unload.unload(loader,player) and GameState.team_credits==credits,"repeated bucket unload grants no duplicate stock or money")
	if work: check(jobs.progress("loader").units==count,"real bucket deposit advances exact units once")
	print("HEAVY_MACHINES_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
