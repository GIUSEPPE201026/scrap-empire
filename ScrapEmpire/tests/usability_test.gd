extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/usability_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var story = GameState.story
	GameState.team_deposit_counts.metal = 20
	GameState.team_deposit_counts.plastic = 20
	GameState.team_deposit_counts.electronics = 20
	check(story.surplus_value()==608,"surplus valuation preserves exact first-order requirements")
	player.position = Vector3(0,0.1,14)
	await frames(3)
	player._open_station()
	await frames(4)
	await capture("scale_surplus")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=800 and player._pause_menu.size.x<=1280,"reorganized scale fits rendered viewport")
	var balance: int = GameState.team_credits
	await click(player,"VENDI SOLO GLI AVANZI")
	check(GameState.team_credits==balance+608 and GameState.team_deposit_counts.metal==8 and GameState.team_deposit_counts.plastic==6 and GameState.team_deposit_counts.electronics==2,"scale surplus button pays only excess and retains ready order")
	check(story.surplus_value()==0 and EconomyService.sell_surplus()==0,"repeated surplus sale cannot duplicate credits")
	check(player._panel_wallet.text.contains(str(GameState.team_credits)),"panel wallet stays synchronized after sale")
	player._close_pause_menu()
	check(GameState.complete_order("yard_restart"),"retained stock still completes actual first order")
	GameState.team_deposit_counts.electronics = 8
	var reserve: Dictionary = story.reserves()
	check(reserve.materials.electronics==7 and reserve.materials.copper==4,"future land project and active order reserve cumulative material needs")
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR = "res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	balance = GameState.team_credits
	var failed: int = EconomyService.sell_surplus()
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(failed==0 and GameState.team_credits==balance and GameState.team_deposit_counts.electronics==8,"failed surplus checkpoint restores resources and money")
	SaveService.SAVE_DIR = "res://project.godot/"
	Engine.print_error_messages = false
	failed = GameState.sell_deposit()
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(failed==0 and GameState.team_credits==balance and GameState.team_deposit_counts.electronics==8,"full sale now also rolls back failed checkpoint")
	GameState.player_inventories[1].metal = 1
	var previous_stock: int = GameState.team_deposit_counts.metal
	SaveService.SAVE_DIR = "res://project.godot/"
	Engine.print_error_messages = false
	var failed_deposit: int = InventoryService.deposit_all(1)
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(failed_deposit==0 and GameState.player_inventories[1].metal==1 and GameState.team_deposit_counts.metal==previous_stock,"ordinary deposit checkpoint failure restores bag and warehouse together")
	check(InventoryService.deposit_all(1)>0 and GameState.player_inventories[1].metal==0 and GameState.team_deposit_counts.metal==previous_stock+1,"ordinary deposit succeeds through shared atomic transfer")
	GameState.completed_orders.append(GameState.order_defs[1].id)
	GameState.yard_level = 2
	GameState.press_owned = true
	GameState.press_bales = 0
	GameState.operations.press_queue = 0
	GameState.press_remaining = 0
	check(story.reserves().materials.metal==13,"surplus sale also preserves metal input for pending order bale")
	var legacy: Dictionary = GameState.serialize().duplicate(true)
	legacy.operations.erase("career")
	legacy.operations.crafting.sales = {"marta":{"day":0,"units":2},"enzo":{"day":0,"units":1}}
	check(SaveService._validate_save_schema(legacy) and GameState.deserialize(legacy) and story.metric("marta_sales")==2 and story.metric("enzo_sales")==1,"old proven customer receipts migrate into career without invented lifetime sales")
	check(SaveService.save_checkpoint(91) and SaveService.load_save(91) and story.metric("marta_sales")==2,"migration persists without repeating proof")
	var malformed_album: Dictionary = GameState.serialize().duplicate(true)
	malformed_album.operations.scrap_album = ["unknown"]
	check(not SaveService._validate_save_schema(malformed_album),"noncanonical collection identity cannot fabricate archive proof")
	player._open_career()
	player._close_pause_menu()
	await frames(3)
	check(not player._is_paused,"immediate popup close leaves world usable without deferred reopen")
	if DisplayServer.get_name()!="headless":
		var warehouse = get_tree().get_first_node_in_group("sector").get_node("StockWarehouse")
		GameState.operations_changed.emit()
		await frames(6)
		var node_id: int = warehouse.stock.get_child(0).get_instance_id()
		for index in 20:
			GameState.operations_changed.emit()
		await frames(4)
		check(warehouse.stock.get_child(0).get_instance_id()==node_id,"unchanged logistics notifications retain warehouse meshes instead of rebuilding")
		GameState.team_deposit_counts.metal += 5
		GameState.deposit_changed.emit(GameState.team_credits,GameState.team_deposit_counts)
		await frames(3)
		check(warehouse.stock.get_child(0).get_instance_id()!=node_id,"warehouse still updates after actual material changes")
		var monitor = get_tree().get_first_node_in_group("upgrade_monitor")
		await frames(6)
		check(monitor.display_viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS,"inactive monitor stops continuous offscreen rendering")
		var monitor_id: int = monitor.display_viewport.get_child(0).get_instance_id()
		GameState.operations_changed.emit()
		await frames(4)
		check(monitor.display_viewport.get_child(0).get_instance_id()==monitor_id,"unchanged state does not rebuild inactive monitor controls")
		player.position = Vector3(-18,0.1,22.2)
		monitor.open(player)
		await frames(3)
		check(monitor.display_viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"active monitor still renders interactive UI continuously")
		monitor._set_page("career")
		await capture("career_monitor")
		player._close_pause_menu()
		GameState.vehicle_level = 2
		get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
		await frames(3)
		var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
		var child_id: int = buggy.cargo_visual.get_child(0).get_instance_id()
		for index in 20:
			GameState.operations_changed.emit()
		await frames(3)
		check(buggy.cargo_visual.get_child(0).get_instance_id()==child_id,"unrelated operations retain buggy cargo meshes")
	player._close_pause_menu()
	var forward_bindings: Array[InputEvent] = InputMap.action_get_events("move_forward")
	InputMap.action_erase_events("move_forward")
	var shortcut = InputEventKey.new()
	shortcut.keycode=KEY_I
	shortcut.pressed=true
	InputMap.action_add_event("move_forward",shortcut.duplicate())
	player._unhandled_input(shortcut)
	check(not player._is_paused,"remapped I movement takes priority over inventory shortcut")
	player._update_inventory_hud()
	check(player._hotbar.text.contains("PAUSA → ATTREZZATURA") and not player._hotbar.text.contains("[I]"),"HUD offers pause alternative when I is assigned to movement")
	InputMap.action_erase_events("move_forward")
	for binding in forward_bindings:
		InputMap.action_add_event("move_forward",binding)
	var mode_bindings: Array[InputEvent] = InputMap.action_get_events("recovery_mode")
	InputMap.action_erase_events("recovery_mode")
	shortcut.keycode=KEY_1
	InputMap.action_add_event("recovery_mode",shortcut.duplicate())
	GameState.team_upgrade_levels.tool=2
	player._equip_tool(2)
	var mode: bool = player._recover_intact
	player._unhandled_input(shortcut)
	check(player._active_tool()==2 and player._recover_intact!=mode,"remapped recovery key wins over numbered tool shortcut")
	player._update_inventory_hud()
	check(player._hotbar_slots[0].text.begins_with("—"),"HUD does not advertise a tool shortcut claimed by gameplay")
	InputMap.action_erase_events("recovery_mode")
	for binding in mode_bindings:
		InputMap.action_add_event("recovery_mode",binding)
	shortcut.keycode=KEY_I
	player._unhandled_input(shortcut)
	await frames(3)
	check(player._is_paused,"inventory shortcut still opens normally with free key")
	inject_input(shortcut.duplicate())
	await frames(3)
	check(not player._is_paused,"inventory window receives I again to close and resume")
	shortcut.keycode=KEY_J
	player._unhandled_input(shortcut)
	await frames(3)
	shortcut.keycode=KEY_M
	inject_input(shortcut.duplicate())
	await frames(3)
	check(player._is_paused and player._career_current_page=="map","M switches open diary to map without unpausing world")
	inject_input(shortcut.duplicate())
	await frames(3)
	check(not player._is_paused,"pressing M again closes map through actual window input")
	print("USABILITY_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
