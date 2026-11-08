extends "res://tests/crafting_test.gd"

func stock_component(kind: String) -> String:
	var items: Array = GameState.operations.field.values().filter(func(item):return item.kind==kind)
	if items.is_empty():
		return ""
	var item: Dictionary = items[0]
	if not GameState.ops.pickup_part(item.id) or not GameState.ops.store_held():
		return ""
	if int(item.quality)==0 and not GameState.ops.repair_part(item.id):
		return ""
	return item.id

func run() -> void:
	if OS.get_cmdline_user_args().has("--720"):
		get_window().size=Vector2i(1280,720)
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/fabrication_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	var fab = GameState.fabrication
	var craft = GameState.crafting
	check(craft.definitions().size()==18 and GameState.logistics_def.customers.size()==5,"eighteen recipes including three yard structures loaded alongside five customers")
	check(not craft.can_craft("restored_radio") and not fab.enqueue("restored_radio",int(GameState.operations.serial)),"advanced manufacturing unavailable before progression and component prerequisites")
	GameState.yard_level=2
	GameState.team_upgrade_levels.tool=2
	GameState.completed_orders=GameState.order_defs.slice(0,3).map(func(order):return order.id)
	GameState.workshop_modules.workbench=1
	GameState.team_credits=10000
	for material in GameState.material_defs:
		GameState.team_deposit_counts[material]=100
	sector.apply_land_expansions()
	GameState.ops.seed_field_parts()
	var battery: String = stock_component("battery")
	var second_battery: String = stock_component("battery")
	var engine: String = stock_component("engine")
	check(not battery.is_empty() and not second_battery.is_empty() and not engine.is_empty(),"real field identities recovered stored and repaired for manufacturing")
	check(GameState.ops.claim_component("assembly_0","car",0,1,1,true).success and GameState.ops.store_held(),"working panel recovered intact for garden furniture")
	var counts: Dictionary = GameState.team_deposit_counts.duplicate()
	var ticket: int = GameState.operations.serial
	await look(player,Vector3(4,0.05,24.2),Vector3(4,1.3,26.4))
	player._open_crafting("restored_radio")
	await capture("fabrication_radio_recipe")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=get_viewport().get_visible_rect().size.y-20,"categorized recipe menu fits viewport")
	await click(player,"METTI IN ASSEMBLAGGIO")
	check(fab.jobs().size()==1 and craft.count("restored_radio")==1 and int(craft.data().stock.get("restored_radio",0))==0,"UI queues real work without prematurely awarding finished product")
	check(GameState.team_deposit_counts.metal==int(counts.metal)-2 and GameState.team_deposit_counts.copper==int(counts.copper)-1 and GameState.ops.usable_parts("battery")==1,"manufacturing reserves exact recipe and one usable battery")
	check(not craft.craft("restored_radio",ticket),"replayed crafting ticket cannot reserve twice")
	var reserved_id: String = fab.jobs()[0].parts[0].id
	check(reserved_id in [battery,second_battery],"queue retains exact reserved component identity")
	player._open_fabrication_queue()
	var remaining: float = fab.jobs()[0].remaining
	await frames(40)
	check(is_equal_approx(float(fab.jobs()[0].remaining),remaining),"pause freezes actual manufacturing time")
	await capture("fabrication_queue")
	player._close_pause_menu()
	await frames(450)
	check(float(fab.jobs()[0].remaining)<remaining-5 and float(fab.jobs()[0].remaining)>0,"assembly progresses while player is free in world")
	if DisplayServer.get_name()!="headless":
		var camera = Camera3D.new()
		sector.add_child(camera)
		camera.position=Vector3(7.4,2.1,23.6)
		camera.look_at(Vector3(8.8,1.4,25.9))
		camera.make_current()
		await capture("fabrication_working_bench")
		player.camera.make_current()
		camera.queue_free()
	player._close_pause_menu()
	var bench = get_tree().get_first_node_in_group("fabrication_display")
	await look(player,bench.global_position+Vector3(0,0.05,-2),bench.global_position+Vector3.UP*1.2)
	var focused: Dictionary = preload("res://scripts/gameplay/interaction_focus.gd").resolve(player)
	check(focused.kind=="operation" and focused.service=="fabrication","assembly station has its own spatial interaction")
	player._activate_interaction(focused)
	check(player._is_paused,"E on assembly station opens live work queue")
	player._open_fabrication_queue()
	remaining=fab.jobs()[0].remaining
	check(SaveService.save_checkpoint(91) and SaveService.load_save(91) and is_equal_approx(float(fab.jobs()[0].remaining),remaining),"partly assembled product resumes exact work remaining from disk")
	var checkpoint: Dictionary = GameState.serialize().duplicate(true)
	var bad: Dictionary = checkpoint.duplicate(true)
	bad.operations.crafting.queue[0].materials.metal=200
	check(not SaveService._validate_save_schema(bad),"fabricated refund amounts rejected")
	bad=checkpoint.duplicate(true)
	bad.operations.crafting.queue[0].remaining=-1
	check(not SaveService._validate_save_schema(bad),"negative production time rejected")
	bad=checkpoint.duplicate(true)
	bad.operations.stored_parts.append(bad.operations.crafting.queue[0].parts[0].duplicate(true))
	check(not SaveService._validate_save_schema(bad),"reserved component cannot also exist in warehouse")
	bad=checkpoint.duplicate(true)
	bad.operations.crafting.queue.append(bad.operations.crafting.queue[0].duplicate(true))
	check(not SaveService._validate_save_schema(bad),"duplicate fabrication receipt rejected")
	bad=checkpoint.duplicate(true)
	bad.operations.crafting.queue[0].duration=22.4
	bad.operations.crafting.queue[0].remaining=10.0
	check(not SaveService._validate_save_schema(bad),"faster recipe duration requires actual saved assembly upgrade")
	bad=checkpoint.duplicate(true)
	bad.workshop_modules.assembly=1
	check(SaveService._validate_save_schema(bad),"buying upgrade keeps valid slower jobs already started")
	bad=checkpoint.duplicate(true)
	bad.operations.serial=100
	for index in 3:
		var extra: Dictionary = bad.operations.crafting.queue[0].duplicate(true)
		extra.id="build_%d" % (90+index)
		extra.parts[0].id="reserved_extra_%d" % index
		bad.operations.crafting.queue.append(extra)
	check(not SaveService._validate_save_schema(bad),"base checkpoint cannot contain four jobs without expanded assembly queue")
	var directory: String = SaveService.SAVE_DIR
	var output: bool = Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed: bool = fab.cancel(str(fab.jobs()[0].id))
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(not failed and fab.jobs().size()==1 and GameState.ops.usable_parts("battery")==1,"failed cancellation checkpoint restores job without refund duplication")
	await click(player,"ANNULLA")
	var restored: bool = counts.keys().all(func(material):return int(GameState.team_deposit_counts[material])==int(counts[material]))
	check(fab.jobs().is_empty() and GameState.ops.usable_parts("battery")==2 and GameState.operations.stored_parts.any(func(item):return item.id==reserved_id) and restored,"UI cancellation returns exact original component and all materials")
	check(not fab.cancel("build_"+str(ticket+1)),"cancel receipt cannot refund again")
	player._close_pause_menu()
	check(craft.craft("restored_radio",int(GameState.operations.serial)) and craft.craft("bench_compressor",int(GameState.operations.serial)) and craft.craft("garden_bench",int(GameState.operations.serial)),"three different material and component filieres queue together")
	check(not craft.craft("restored_radio",int(GameState.operations.serial)) and fab.jobs().size()==3,"base work queue capacity prevents unbounded reservations")
	var job_before: Dictionary = fab.jobs()[0].duplicate(true)
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	fab.tick(60)
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(fab.jobs()[0].id==job_before.id and int(craft.data().stock.get("restored_radio",0))==0,"completion write failure restores reserved job and does not award product")
	fab.tick(120)
	check(fab.jobs().is_empty() and craft.data().stock.restored_radio==1 and craft.data().stock.bench_compressor==1 and craft.data().stock.garden_bench==1,"three real recipes finish with time spillover and one product each")
	fab.tick(120)
	check(craft.data().stock.restored_radio==1,"idle production cannot duplicate completed products")
	var money: int = GameState.team_credits
	check(craft.sell_product("nina",1,int(GameState.operations.serial)) and GameState.team_credits==money+520,"restored radio sells once to own customer at data price")
	check(not craft.sell_product("nina",1,int(GameState.operations.serial)) and GameState.team_credits==money+520,"missing finished product cannot sell twice")
	check(craft.sell_product("bruno",1,int(GameState.operations.serial)) and craft.sell_product("ada",1,int(GameState.operations.serial)),"other complex products have useful distinct buyers")
	check(GameState.purchase_module("assembly") and is_equal_approx(fab.duration("restored_radio"),22.4),"assembly jig upgrade reduces actual future recipe time")
	GameState.completed_orders=GameState.order_defs.slice(0,4).map(func(order):return order.id)
	check(GameState.purchase_module("assembly") and fab.capacity()==6 and is_equal_approx(fab.duration("restored_radio"),16.8),"second jig upgrade provides six jobs and stronger time benefit")
	var nina = get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("customer","")=="nina")[0]
	await look(player,nina.position+Vector3(0,0.05,-2),nina.position+Vector3.UP*1.2)
	player._open_ops_service(nina)
	await capture("fabrication_nina")
	check(player._is_paused and player._panel_box.find_children("*","Label",true,false).any(func(label):return label.text.to_upper().contains("NINA")),"new buyer has accessible physical customer menu")
	check(SaveService.save_checkpoint(92) and SaveService.load_save(92) and fab.jobs().is_empty() and craft.demand("nina")==1,"manufacturing receipts upgrades and daily customer quota persist")
	print("FABRICATION_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
