extends "res://tests/single_player_cycle.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/specific_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var service = GameState.specifics
	check(not service.accept("radio_lab"),"specific request respects campaign prerequisite")
	GameState.completed_orders = [GameState.order_defs[0].id]
	GameState.team_upgrade_levels.tool = 1
	GameState.workshop_modules.scanner = 1
	player.position = Vector3(-18,0,22.2)
	player._open_development()
	player._upgrade_monitor._set_page("specific")
	await frames(4)
	await capture("specific_requests_offers")
	var buttons = player._upgrade_monitor.display_viewport.find_children("*","Button",true,false)
	var accept: Button
	for button in buttons:
		if button.text=="Accetta" and not button.disabled:
			accept = button
	check(accept!=null,"monitor exposes unlocked targeted request")
	if DisplayServer.get_name()=="headless":
		accept.pressed.emit()
	else:
		await click_physical_button(player._upgrade_monitor,accept)
	check(service.payload().get("id","")=="radio_lab","monitor action accepts specific request")
	player._close_pause_menu()
	check(not service.accept("workshop_parts"),"only one targeted request can be active")
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	var target = get_tree().get_nodes_in_group("scrap").filter(func(item):return item.scrap_type==2 and catalog.variant_for(item.entity_id)==3)[0]
	target.position = Vector3(40,0.1,10)
	await frames(3)
	await aim(player,target)
	player._scan_scrap()
	check(player._navigation_label.contains("RICHIESTA"),"scanner targets requested variant independently of book state")
	GameState.player_inventories[1].metal = 10
	Input.action_press("collect")
	await frames(200)
	Input.action_release("collect")
	check(service.units("bag")==0 and is_instance_valid(target),"full bag preserves requested object in world")
	GameState.player_inventories[1].metal = 0
	var initial_directory: String = SaveService.SAVE_DIR
	var initial_output: bool = Engine.print_error_messages
	SaveService.SAVE_DIR = "res://project.godot/"
	Engine.print_error_messages = false
	var failed_capture: bool = GameState.recover_world_scrap(1,target.entity_id,"electronics",1)
	Engine.print_error_messages = initial_output
	SaveService.SAVE_DIR = initial_directory
	check(not failed_capture and service.units("bag")==0 and target.entity_id not in GameState.sector_consumed_ids,"failed reservation checkpoint leaves source and request untouched")
	await aim(player,target)
	Input.action_press("collect")
	await frames(200)
	Input.action_release("collect")
	await frames(3)
	check(service.units("bag")==1 and GameState.player_inventories[1].electronics==0 and GameState.get_inventory_mass(1)==3,"actual radio collection reserves intact variant with real bag mass")
	check(SaveService.save_checkpoint(98) and SaveService.load_save(98) and service.units("bag")==1 and GameState.get_inventory_mass(1)==3,"reserved bag identity and mass survive disk roundtrip")
	check(not service.capture("2_3","electronics_999") and service.units("bag")==1,"unknown source cannot fabricate request stock")
	var ticket: int = service.payload().ticket
	check(not service.deliver(ticket),"request cannot deliver from bag before deposit")
	GameState.yard_level = 1
	GameState.vehicle_level = 2
	GameState.operations.cargo.metal = 59
	check(not GameState.ops.transfer_bag_to_cargo(1) and service.units("bag")==1,"reserved variant respects combined cargo capacity")
	GameState.operations.cargo.clear()
	SaveService.SAVE_DIR = "res://project.godot/"
	Engine.print_error_messages = false
	var failed_transfer: bool = GameState.ops.transfer_bag_to_cargo(1)
	Engine.print_error_messages = initial_output
	SaveService.SAVE_DIR = initial_directory
	check(not failed_transfer and service.units("bag")==1 and service.units("cargo")==0,"failed cargo checkpoint restores reserved variant custody")
	check(GameState.ops.transfer_bag_to_cargo(1) and service.units("cargo")==1 and service.units("bag")==0 and GameState.ops.cargo_mass()==3,"cargo transfer preserves variant and mass")
	check(SaveService.save_checkpoint(99) and SaveService.load_save(99) and service.units("cargo")==1 and GameState.ops.cargo_mass()==3,"reserved cargo identity and mass survive disk roundtrip")
	check(GameState.ops.unload_cargo() and service.units("stock")==1 and GameState.ops.cargo_mass()==0,"cargo unload reserves exact variant in request stock")
	check(GameState.sell_material("electronics")==0 and service.units("stock")==1,"ordinary material sale cannot consume reserved radio")
	for variant in [0,4]:
		var item = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.scrap_type==2 and catalog.variant_for(node.entity_id)==variant)[0]
		check(GameState.recover_world_scrap(1,item.entity_id,"electronics",1),"requested piece reserves through shared collection service: "+str(variant))
		item.collect()
	var invalid: Dictionary = GameState.serialize().duplicate(true)
	invalid.operations.specific_request.bag["2_0"] = 2
	check(not SaveService._validate_save_schema(invalid),"overfilled request rejected on load")
	invalid = GameState.serialize().duplicate(true)
	invalid.operations.specific_request.bag["0_0"] = 1
	check(not SaveService._validate_save_schema(invalid),"unrequested variant rejected on load")
	check(GameState.ops.store_bag(1) and service.units("stock")==3 and GameState.get_inventory_mass(1)==0,"warehouse deposits remaining variants without sale")
	player._scan_scrap()
	check(player._navigation_label.contains("CONSEGNA AL MONITOR"),"scanner guides completed request back to delivery point")
	player.position = Vector3(-18,0,22.2)
	player._open_development()
	player._upgrade_monitor._set_page("specific")
	await frames(3)
	await capture("specific_requests_ready")
	player._close_pause_menu()
	check(SaveService.save_checkpoint(97),"request stock checkpoint saves")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	player = get_tree().get_first_node_in_group("players")
	check(service.units("stock")==3 and service.ready(),"scene reentry restores exact request stock")
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR = "res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var balance: int = GameState.team_credits
	var failed: bool = service.deliver(ticket)
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(not failed and service.ready() and GameState.team_credits==balance,"failed delivery checkpoint restores stock and reward together")
	if DisplayServer.get_name()=="headless":
		service.deliver(ticket)
	else:
		player.position = Vector3(-18,0,22.2)
		player._open_development()
		player._upgrade_monitor._set_page("specific")
		await frames(3)
		var deliver: Button
		for button in player._upgrade_monitor.display_viewport.find_children("*","Button",true,false):
			if button.text.begins_with("CONSEGNA") and not button.disabled:
				deliver = button
		await click_physical_button(player._upgrade_monitor,deliver)
	check(GameState.team_credits==balance+450 and service.payload().is_empty(),"targeted delivery consumes exact objects and credits once")
	check(not service.deliver(ticket) and not service.accept("radio_lab") and GameState.team_credits==balance+450,"receipt blocks duplicate reward and completed request replay")
	GameState.completed_orders.append(GameState.order_defs[1].id)
	check(service.accept("workshop_parts"),"next targeted request unlocks with campaign progress")
	var metals = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.scrap_type==0 and catalog.variant_for(node.entity_id)==0)
	check(GameState.recover_world_scrap(1,metals[0].entity_id,"metal",0) and GameState.recover_world_scrap(1,metals[1].entity_id,"metal",0) and GameState.ops.transfer_bag_to_cargo(1),"second request transfers two exact objects into cargo")
	var radiator = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.scrap_type==0 and catalog.variant_for(node.entity_id)==1)[0]
	check(GameState.recover_world_scrap(1,radiator.entity_id,"metal",0) and GameState.ops.store_bag(1),"second request stores a distinct variant")
	var valve = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.scrap_type==0 and catalog.variant_for(node.entity_id)==4)[0]
	check(GameState.recover_world_scrap(1,valve.entity_id,"metal",0) and service.units("bag")==1,"second request keeps last variant in bag")
	check(service.cancel() and service.payload().is_empty() and GameState.player_inventories[1].metal==1 and GameState.operations.cargo.metal==2 and GameState.team_deposit_counts.metal==1,"cancelling preserves exact mass across bag cargo and stock")
	var malformed: Dictionary = GameState.serialize().duplicate(true)
	malformed.operations.specific_completed = ["radio_lab","radio_lab"]
	check(not SaveService._validate_save_schema(malformed),"duplicate targeted receipts rejected on load")
	print("SPECIFIC_ORDERS_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
