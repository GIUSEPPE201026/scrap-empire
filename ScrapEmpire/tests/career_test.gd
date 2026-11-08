extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/career_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var story = GameState.story
	check(story.chapter().sender=="Marta" and story.chapter().title=="Un cancello da riaprire","new campaign begins with named story chapter")
	check(story.next_step().route=="salvage" and story.next_step().material=="metal","first objective identifies actually missing material")
	var key = InputEventKey.new()
	key.keycode = KEY_J
	key.pressed = true
	player._unhandled_input(key)
	await frames(5)
	check(player._is_paused and is_instance_valid(player._pause_menu),"J opens purpose journal and pauses single-player")
	await capture("career_story")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=800 and player._pause_menu.position.y>=0,"story page fits rendered window")
	await click(player,"SEGUI IL PROSSIMO PASSO")
	check(player._career_tracking and player._navigation_label.begins_with("OBIETTIVO"),"journal sets actionable navigation without moving player")
	GameState.player_inventories[1].metal = 8
	check(story.next_step().route=="depot","objective notices required batch in bag and recommends deposit")
	GameState.ops.store_bag(1)
	check(story.next_step().material=="plastic","deposit advances guidance to next missing family")
	GameState.team_deposit_counts.plastic = 6
	GameState.team_deposit_counts.electronics = 2
	check(story.next_step().route=="tools","ready order points to office instead of more harvesting")
	check(GameState.complete_order("yard_restart") and story.chapter().sender=="Enzo","actual first delivery advances story chapter")
	check(story.next_step().route=="tools","second chapter recommends prerequisite tool before locked land")
	GameState.team_upgrade_levels.tool = 1
	GameState.team_deposit_counts.electronics = 4
	check(story.next_step().route=="land","expansion guidance respects deposited project supplies")
	var consumed_before: Array[String] = GameState.sector_consumed_ids.duplicate()
	for index in int(GameState.sector_initial_counts.electronics):
		GameState.mark_scrap_consumed("electronics_%03d" % index)
	GameState.team_deposit_counts.electronics = 0
	check(story.next_step().route=="depot","depleted family guidance suggests renewing sector instead of searching forever")
	GameState.sector_consumed_ids = consumed_before
	GameState.team_deposit_counts.electronics = 4
	player._open_career("map")
	await frames(5)
	await capture("career_map")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.x<=1280 and player._pause_menu.size.y<=800,"scaled map and service list fit rendered window")
	await click(player,"Banco costruzione")
	check(not player._is_paused and player._navigation_target.distance_to(Vector3(4,0,26.4))<0.1,"map selection routes to actual garage bench")
	check(not story.claim("unknown") and not story.claim("community"),"unknown and incomplete projects cannot grant rewards")
	GameState.completed_orders.append(GameState.order_defs[1].id)
	GameState.team_deposit_counts.metal = 100
	GameState.team_deposit_counts.plastic = 100
	GameState.team_deposit_counts.electronics = 100
	for index in 6:
		check(GameState.crafting.craft("desk_lamp",int(GameState.operations.serial)),"craft community lamp "+str(index))
	for index in 4:
		check(GameState.crafting.craft("toolbox",int(GameState.operations.serial)),"craft community toolbox "+str(index))
	check(GameState.crafting.sell_product("marta",3,int(GameState.operations.serial)) and GameState.crafting.sell_product("enzo",2,int(GameState.operations.serial)),"first day customer sales register actual products")
	GameState.operations.world_seconds = float(GameState.logistics_def.day_seconds)
	check(GameState.crafting.sell_product("marta",3,int(GameState.operations.serial)) and GameState.crafting.sell_product("enzo",2,int(GameState.operations.serial)),"second day sales accumulate rather than overwrite career proof")
	check(story.metric("marta_sales")==6 and story.metric("enzo_sales")==4 and story.ready("community"),"proof totals match real sale transactions")
	var directory: String = SaveService.SAVE_DIR
	var balance: int = GameState.team_credits
	SaveService.SAVE_DIR = "res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var failed: bool = story.claim("community")
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(not failed and not story.has_project("community") and GameState.team_credits==balance,"failed recognition checkpoint rolls back reward and benefit")
	player._open_career("projects")
	await frames(3)
	await capture("career_projects_ready")
	await click(player,"OTTIENI RICONOSCIMENTO")
	check(story.has_project("community") and GameState.team_credits==balance+1200,"journal recognition grants exact project reward")
	check(GameState.crafting.customer_limit("marta")==4 and GameState.crafting.customer_limit("enzo")==3,"community project increases actual daily customer demand")
	check(not story.claim("community") and GameState.team_credits==balance+1200,"recognition receipt blocks replay")
	check(GameState.crafting.craft("desk_lamp",int(GameState.operations.serial)) and GameState.crafting.sell_product("marta",1,int(GameState.operations.serial)) and GameState.crafting.demand("marta")==0,"expanded daily quota accepts one additional real sale and valid checkpoint")
	player._close_pause_menu()
	GameState.completed_orders = GameState.order_defs.map(func(order):return order.id)
	GameState.workshop_modules.workbench = 1
	GameState.workshop_modules.press_drive = 2
	GameState.operations.deliveries = 3
	var old_cycle: float = GameState.press_cycle_seconds()
	check(story.claim("production") and is_equal_approx(GameState.press_cycle_seconds(),old_cycle*0.9),"production project reduces actual press recipe cycle")
	GameState.operations.scrap_album = []
	for family in 5:
		for variant in 5:
			GameState.operations.scrap_album.append("%d_%d" % [family,variant])
	GameState.operations.specific_completed = ["radio_lab","workshop_parts"]
	GameState.workshop_modules.scanner = 1
	check(story.ready("archive") and story.claim("archive") and story.complete(),"collection proof closes third promise and unlocks epilogue")
	GameState.operations.scrap_album.erase("0_1")
	var target = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.scrap_type==0 and preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(node.entity_id)==1)[0]
	for item in get_tree().get_nodes_in_group("scrap"):
		item.position = Vector3(150,0,150)
	player.position = Vector3(30,0.1,10)
	target.position = Vector3(60,0.1,10)
	await frames(3)
	player._scan_scrap(true)
	check(player._navigation_label.begins_with("SCANNER") and player._navigation_target.distance_to(target.position)<0.1,"archive recognition extends actual scanner detection beyond stock twenty-five metres")
	player._open_career("story")
	await capture("career_epilogue")
	player._close_pause_menu()
	var invalid: Dictionary = GameState.serialize().duplicate(true)
	invalid.operations.career.claimed.append("archive")
	check(not SaveService._validate_save_schema(invalid),"duplicate career receipt rejected on load")
	invalid = GameState.serialize().duplicate(true)
	invalid.operations.career.stats.marta_sales = -1
	check(not SaveService._validate_save_schema(invalid),"negative lifetime proof rejected on load")
	check(SaveService.save_checkpoint(92) and SaveService.load_save(92) and story.complete() and GameState.crafting.customer_limit("marta")==4,"career proof rewards and benefits survive save/load")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	check(story.complete() and get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("operation")=="career").size()==1,"returning restores completed story without duplicate board")
	print("CAREER_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
