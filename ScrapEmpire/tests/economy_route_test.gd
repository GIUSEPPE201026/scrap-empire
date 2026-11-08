extends "res://tests/crafting_test.gd"
var recovered: int = 0
var trips: int = 0
var expeditions: int = 1

func harvest(sector: Node) -> int:
	var obtained: int = 0
	for item in get_tree().get_nodes_in_group("scrap"):
		if item.is_queued_for_deletion():
			continue
		var material: String = ["metal","plastic","electronics","copper","aluminum","glass","rubber"][item.scrap_type]
		var allowed: Array = GameState.material_defs[material].tools
		var tool: int = -1
		for candidate in allowed:
			if GameState.owns_tool(int(candidate)):
				tool = int(candidate)
				break
		if tool<0:
			continue
		if not GameState.can_add_to_inventory(1,material):
			if GameState.get_inventory_mass(1)>0:
				GameState.ops.store_bag(1)
				trips += 1
		if GameState.recover_world_scrap(1,item.entity_id,material,tool):
			GameState.ops.record_discovery(item.scrap_type,preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(item.entity_id))
			item.collect()
			obtained += 1
			recovered += 1
	if GameState.get_inventory_mass(1)>0:
		GameState.ops.store_bag(1)
		trips += 1
	return obtained

func advance(sector: Node) -> bool:
	var changed: bool = false
	for attempt in 10:
		if GameState.can_complete_order():
			GameState.complete_order(GameState.current_order().id)
			changed = true
			continue
		var stage: int = GameState.completed_orders.size()
		if stage>=1 and GameState.team_upgrade_levels.tool<1:
			if GameState.purchase_upgrade("tool",1):
				changed = true
				continue
		var desired: int = 0 if stage==0 else (1 if stage==1 else 2)
		if desired>GameState.yard_level:
			var required: int = int(GameState.land_defs[GameState.yard_level].requires_tool)
			if int(GameState.team_upgrade_levels.tool)<required:
				if GameState.purchase_upgrade("tool",required):
					changed = true
					continue
			if GameState.purchase_land():
				sector.apply_land_expansions()
				changed = true
				continue
		if stage>=2 and not GameState.press_owned:
			if GameState.purchase_press():
				changed = true
				continue
		var order: Dictionary = GameState.current_order()
		if not order.is_empty() and int(order.bales)>GameState.press_bales and GameState.press_owned:
			var needed: int = int(order.bales)-GameState.press_bales
			if GameState.ops.enqueue_press(needed):
				GameState._process(GameState.press_cycle_seconds()*needed+0.1)
				changed = true
				continue
		if stage>=3 and GameState.vehicle_level<2:
			if GameState.purchase_vehicle():
				changed = true
				continue
		break
	return changed

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/zero_bonus_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	check(GameState.team_credits==0 and GameState.applied_local_grants.is_empty(),"economic route starts with zero money and no owner grants")
	for cycle in 8:
		var new_items: int = harvest(sector)
		advance(sector)
		var revenue: int = EconomyService.sell_surplus()
		advance(sector)
		# Opening land introduces genuinely new canonical sources in same expedition.
		new_items += harvest(sector)
		advance(sector)
		revenue += EconomyService.sell_surplus()
		advance(sector)
		print("ECONOMY_ROUTE expedition=",expeditions," recovered=",recovered," deposits=",trips," orders=",GameState.completed_orders.size()," land=",GameState.yard_level," tool=",GameState.team_upgrade_levels.tool," vehicle=",GameState.vehicle_level," cash=",GameState.team_credits," sale=",revenue)
		if GameState.completed_orders.size()==GameState.order_defs.size():
			break
		check(GameState.get_inventory_mass(1)==0,"expedition finishes with empty bag and no material loss")
		player.position = Vector3(0,0.1,14)
		player._new_expedition()
		await frames(25)
		player = get_tree().get_first_node_in_group("players")
		sector = get_tree().get_first_node_in_group("sector")
		expeditions += 1
	check(GameState.completed_orders.size()==5,"zero-bonus route reaches five-order certification from actual finite scrap sources")
	check(GameState.vehicle_level==2 and GameState.yard_level==2 and GameState.press_owned,"certification route buys both lots complementary tools press and buggy")
	check(GameState.operations.get("scrap_album",[]).size()>=25,"honest resource route discovers enough variants for archive project")
	check(GameState.team_credits>=0 and GameState.get_inventory_mass(1)==0,"route never borrows money or exceeds bag at completion")
	check(SaveService.save_checkpoint(90) and SaveService.load_save(90) and GameState.completed_orders.size()==5,"earned certification and equipment survive checkpoint roundtrip")
	if OS.get_cmdline_user_args().has("--reuse-route"):
		await verify_reuse_route()
	print("ECONOMY_ROUTE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func renew_and_harvest() -> void:
	var player = get_tree().get_first_node_in_group("players")
	var epoch: int = GameState.operations.epoch
	player.position=Vector3(0,0.1,14)
	player._new_expedition()
	await frames(25)
	check(int(GameState.operations.epoch)>epoch,"reuse route renews genuinely depleted sources through expedition service")
	expeditions+=1
	var obtained: int = harvest(get_tree().get_first_node_in_group("sector"))
	check(obtained>0 and GameState.get_inventory_mass(1)==0,"reuse route gathers finite canonical scrap into normal capacity bag and deposits it")

func recover_working(kind: String) -> void:
	var found: Array = GameState.operations.field.values().filter(func(item):return item.kind==kind)
	if found.is_empty():
		await renew_and_harvest()
		found=GameState.operations.field.values().filter(func(item):return item.kind==kind)
	check(not found.is_empty(),"actual field supplies component for reuse: "+kind)
	if found.is_empty():
		return
	var item: Dictionary = found[0]
	check(GameState.ops.pickup_part(item.id) and GameState.ops.store_held(),"component carried intact and stored: "+kind)
	if int(item.quality)==0:
		check(GameState.ops.repair_part(item.id),"damaged reuse component repaired with earned warehouse materials: "+kind)

func manufacture(kind: String, amount: int) -> void:
	for index in amount:
		if not GameState.crafting.can_craft(kind):
			await renew_and_harvest()
		check(GameState.crafting.craft(kind,int(GameState.operations.serial)),"finite earned stock manufactures "+kind+" #"+str(index+1))

func verify_reuse_route() -> void:
	check(GameState.purchase_module("workbench"),"certification earnings buy precision workbench with normal price")
	check(GameState.purchase_module("assembly") and GameState.purchase_module("assembly"),"earned money buys both assembly upgrades through actual purchase service")
	var cash: int = GameState.team_credits
	await renew_and_harvest()
	await recover_working("battery")
	await recover_working("engine")
	await recover_working("engine")
	for entity in ["assembly_0","assembly_3","assembly_2"]:
		var definition: String = "appliance" if entity=="assembly_2" else "car"
		var tool: int = int(GameState.salvage_defs[definition].steps[0].tool)
		check(GameState.ops.claim_component(entity,definition,0,1,tool,true).success and GameState.ops.store_held(),"furniture panel dismantled intact from actual assembly: "+entity)
	for id in ["town_square","workshop_relaunch","neighborhood_gardens"]:
		check(GameState.ops.accept_delivery(id),"earned certification unlocks product supply: "+id)
		var job: Dictionary = GameState.ops.delivery_definition()
		for kind in job.products:
			await manufacture(kind,int(job.products[kind]))
		if int(job.bales)>GameState.press_bales:
			var missing: int = int(job.bales)-GameState.press_bales
			check(GameState.ops.enqueue_press(missing),"product supply bale uses real recovered metal")
			GameState._process(GameState.press_cycle_seconds()*missing+0.1)
		GameState.fabrication.tick(200)
		check(GameState.ops.delivery_ready(),"actual finite resources satisfy finished supply: "+id)
		check(GameState.ops.complete_delivery(int(GameState.operations.active_delivery.ticket)),"finished community goods ship exactly once: "+id)
	check(GameState.team_credits==cash+5300 and GameState.operations.delivery_history.size()==3,"all three reuse supplies earn exactly 5300 without grants or injected stock")
	check(SaveService.save_checkpoint(91) and SaveService.load_save(91) and GameState.operations.delivery_history.size()==3 and GameState.applied_local_grants.is_empty(),"complete zero-bonus industrial route survives save and reload")
	print("REUSE_ROUTE recovered=",recovered," deposits=",trips," expeditions=",expeditions," cash=",GameState.team_credits," deliveries=",GameState.operations.deliveries)
