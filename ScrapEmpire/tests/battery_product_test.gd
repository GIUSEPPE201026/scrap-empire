extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/battery_product_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	GameState.yard_level=1
	GameState.team_upgrade_levels.tool=1
	GameState.workshop_modules.workbench=1
	GameState.completed_orders=[GameState.order_defs[0].id,GameState.order_defs[1].id]
	GameState.team_credits=1000
	GameState.team_deposit_counts.metal=10
	GameState.team_deposit_counts.plastic=10
	GameState.team_deposit_counts.electronics=10
	GameState.team_deposit_counts.copper=10
	GameState.ops.seed_field_parts()
	var battery: String=""
	for id in GameState.operations.field:
		if GameState.operations.field[id].kind=="battery": battery=id; break
	check(not battery.is_empty(),"industrial sector provides recoverable battery")
	if battery.is_empty(): get_tree().quit(1); return
	GameState.operations.field[battery].quality=0
	check(GameState.ops.pickup_part(battery) and GameState.ops.store_held(),"damaged recovered battery enters warehouse through component services")
	check(not GameState.crafting.can_craft("battery_pack"),"damaged battery cannot be installed in a finished accumulator")
	check(GameState.ops.repair_part(battery),"existing recovery bench repairs battery")
	var initial_plastic: int=GameState.team_deposit_counts.plastic
	var service=GameState.crafting
	check(service.can_craft("battery_pack") and service.craft("battery_pack",int(GameState.operations.serial)),"repaired battery starts accumulator assembly")
	check(GameState.ops.usable_parts("battery")==0 and GameState.team_deposit_counts.plastic==initial_plastic-2,"assembly reserves battery and exact materials once")
	check(SaveService.save_checkpoint(101) and SaveService.load_save(101),"queued accumulator survives disk validation")
	var job: String=GameState.fabrication.jobs()[0].id
	check(GameState.fabrication.cancel(job) and GameState.ops.usable_parts("battery")==1 and GameState.team_deposit_counts.plastic==initial_plastic,"cancellation returns the same battery and materials")
	check(service.craft("battery_pack",int(GameState.operations.serial)),"returned component can be assembled again")
	GameState.fabrication.tick(30)
	check(int(service.data().stock.get("battery_pack",0))==1 and GameState.ops.usable_parts("battery")==0,"completion creates one accumulator and consumes recovered component")
	var player=get_tree().get_first_node_in_group("players")
	var customer=get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("customer","")=="luca")[0]
	await snapshot_prop(player,customer,"battery_customer")
	var credits: int=GameState.team_credits
	var ticket: int=int(GameState.operations.serial)
	await look(player,customer.global_position+Vector3(0,0.08,2.2),customer.global_position+Vector3.UP*1.2)
	player._open_ops_service(customer)
	await capture("battery_customer_menu")
	await click(player,"CONSEGNA 1 · +380 BULLONI")
	check(GameState.team_credits==credits+380 and int(service.data().stock.get("battery_pack",0))==0,"dedicated customer menu consumes product and pays configured price")
	check(not service.sell_product("luca",1,ticket),"replayed receipt cannot pay twice")
	check(SaveService.save_checkpoint(102) and SaveService.load_save(102) and service.demand("luca")==1,"sale receipt and daily demand persist")
	print("BATTERY_PRODUCT_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
