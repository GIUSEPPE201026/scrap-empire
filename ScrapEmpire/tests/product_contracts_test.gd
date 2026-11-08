extends "res://tests/fabrication_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/product_jobs_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	var craft = GameState.crafting
	var ops = GameState.ops
	check(GameState.delivery_defs.size()==6 and not ops.accept_delivery("town_square"),"six repeatable supplies include products but remain gated behind certification")
	GameState.yard_level=2
	GameState.team_upgrade_levels.tool=2
	GameState.completed_orders=GameState.order_defs.map(func(job):return job.id)
	GameState.workshop_modules.workbench=1
	GameState.press_owned=true
	GameState.press_bales=1
	for material in GameState.material_defs:
		GameState.team_deposit_counts[material]=100
	sector.apply_land_expansions()
	ops.seed_field_parts()
	check(not stock_component("battery").is_empty(),"town radio starts from an actual recovered repaired battery")
	for index in 3:
		check(craft.craft("desk_lamp",int(GameState.operations.serial)),"town lamps use existing real crafting recipe "+str(index))
	check(craft.craft("restored_radio",int(GameState.operations.serial)) and ops.accept_delivery("town_square"),"accept community supply while its radio is assembling")
	check(not ops.delivery_ready() and GameState.story.next_step().route=="fabrication","unfinished queued products never count as delivered and guidance names workbench")
	check(SaveService.save_checkpoint(94) and SaveService.load_save(94) and GameState.operations.active_delivery.id=="town_square" and GameState.fabrication.jobs().size()==1,"active product order and partial production survive disk reload together")
	GameState.fabrication.tick(30)
	check(ops.delivery_ready(),"finished products bale and materials jointly satisfy supply")
	var dispatch = get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("operation","")=="dispatch")[0]
	await look(player,dispatch.global_position+Vector3(0,0.05,2),dispatch.global_position+Vector3.UP*1.2)
	player._open_ops_service(dispatch)
	await capture("product_contract_dispatch")
	var ticket: int = GameState.operations.active_delivery.ticket
	await click(player,"CONSEGNA")
	check(GameState.team_credits==1100 and GameState.operations.deliveries==1 and int(craft.data().stock.desk_lamp)==0 and int(craft.data().stock.restored_radio)==0 and GameState.press_bales==0,"dispatch UI consumes exact finished products and bale with single reward")
	check(not ops.complete_delivery(ticket) and GameState.team_credits==1100,"old delivery ticket cannot duplicate product revenue")
	check(int(GameState.operations.delivery_history.town_square)==1,"delivery history proves which actual project was supplied")
	check(not stock_component("engine").is_empty() and not stock_component("engine").is_empty(),"workshop compressors use two distinct recovered engines")
	for index in 2:
		check(craft.craft("bench_compressor",int(GameState.operations.serial)),"compressor queued "+str(index))
	for index in 3:
		craft.craft("toolbox",int(GameState.operations.serial))
	check(ops.accept_delivery("workshop_relaunch"),"different finished product supply accepted after first receipt")
	GameState.fabrication.tick(100)
	check(ops.delivery_ready(),"two compressors three toolboxes and four raw metals are all required")
	ticket=GameState.operations.active_delivery.ticket
	var directory: String = SaveService.SAVE_DIR
	var output: bool = Engine.print_error_messages
	var metal: int = GameState.team_deposit_counts.metal
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed: bool = ops.complete_delivery(ticket)
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(not failed and GameState.operations.active_delivery.ticket==ticket and int(craft.data().stock.bench_compressor)==2 and GameState.team_credits==1100 and int(GameState.team_deposit_counts.metal)==metal,"failed product shipment restores goods raw stock active receipt and money together")
	check(ops.complete_delivery(ticket) and GameState.team_credits==3400 and GameState.operations.deliveries==2,"retried shipment succeeds with exact reward once")
	for entity in ["assembly_0","assembly_3"]:
		check(ops.claim_component(entity,"car",0,1,1,true).success and ops.store_held(),"garden furniture recovers distinct car panel: "+entity)
	check(ops.claim_component("assembly_2","appliance",0,1,2,true).success and ops.store_held(),"appliance shell has useful second life as third furniture panel")
	for index in 3:
		check(craft.craft("garden_bench",int(GameState.operations.serial)),"garden bench queued "+str(index))
	for index in 2:
		craft.craft("desk_lamp",int(GameState.operations.serial))
	check(ops.accept_delivery("neighborhood_gardens"),"garden restoration offers third endgame purpose")
	GameState.fabrication.tick(120)
	ticket=GameState.operations.active_delivery.ticket
	check(ops.delivery_ready() and ops.complete_delivery(ticket) and GameState.team_credits==5300 and GameState.operations.deliveries==3,"all three community supplies complete through actual fabrication and shipping services")
	check(GameState.operations.delivery_history.size()==3 and not ops.complete_delivery(ticket),"three distinct project receipts persist without replay")
	check(get_tree().get_first_node_in_group("town_projects").get_meta("completed_projects").size()==3 and preload("res://scripts/gameplay/yard_navigation.gd").points(player).has("square"),"real supplied projects transform town state and add square to navigation")
	if DisplayServer.get_name()!="headless":
		player._close_pause_menu()
		var camera = Camera3D.new()
		sector.add_child(camera)
		camera.position=Vector3(-54,4.5,26)
		camera.look_at(Vector3(-48,1,34))
		camera.make_current()
		await capture("town_square_completed")
		player.camera.make_current()
		camera.queue_free()
	check(ops.accept_delivery("town_square") and not ops.delivery_ready() and ops.cancel_delivery(),"repeatable jobs require newly manufactured goods and can be declined without loss")
	check(SaveService.save_checkpoint(95) and SaveService.load_save(95) and GameState.operations.delivery_history.size()==3 and GameState.team_credits==5300,"new town supply history and earned money survive loading")
	var bad: Dictionary = GameState.serialize().duplicate(true)
	bad.operations.delivery_history.unknown=1
	check(not SaveService._validate_save_schema(bad),"unknown town project cannot fabricate completion")
	bad=GameState.serialize().duplicate(true)
	bad.operations.delivery_history.town_square=50
	check(not SaveService._validate_save_schema(bad),"project history cannot exceed actual delivery total")
	var legacy: Dictionary = GameState.serialize().duplicate(true)
	legacy.operations.erase("delivery_history")
	check(SaveService._validate_save_schema(legacy),"older total-only supply saves remain valid without invented individual history")
	print("PRODUCT_CONTRACTS_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
