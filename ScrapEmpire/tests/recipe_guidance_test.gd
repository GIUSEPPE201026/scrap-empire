extends "res://tests/fabrication_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/recipe_guidance_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var craft = GameState.crafting
	var nav = preload("res://scripts/gameplay/yard_navigation.gd")
	check(craft.next_requirement("unknown").is_empty(),"unknown recipe cannot create a navigation objective")
	check(craft.next_requirement("restored_radio").route=="tools","locked product guides player to current campaign orders")
	GameState.completed_orders=GameState.order_defs.slice(0,2).map(func(job):return job.id)
	check(craft.next_requirement("restored_radio").detail.contains("Cacciavite"),"recipe explains complementary tool requirement")
	GameState.team_upgrade_levels.tool=1
	check(craft.next_requirement("restored_radio").route=="land","recipe sends missing land requirement to planimetry")
	GameState.yard_level=1
	get_tree().get_first_node_in_group("sector").apply_land_expansions()
	check(craft.next_requirement("restored_radio").route=="tools","recipe sends missing workbench to physical upgrade monitor")
	GameState.workshop_modules.workbench=1
	GameState.ops.seed_field_parts()
	var step: Dictionary = craft.next_requirement("restored_radio")
	check(step.get("part","")=="battery","missing working component gets a specific recovery objective")
	var destination: Dictionary = nav.objective(player,step)
	check(get_tree().get_nodes_in_group("bulk_parts").any(func(node):return node.kind=="battery" and node.global_position.distance_to(destination.position)<0.01),"component route targets a real available world source")
	await look(player,Vector3(4,0.05,24.2),Vector3(4,1.3,26.4))
	var before: Dictionary = GameState.serialize().duplicate(true)
	get_window().size=Vector2i(1280,720)
	player._open_crafting("restored_radio")
	await frames(4)
	var guidance: Button = player._pause_menu.find_children("*","Button",true,false).filter(func(control):return str(control.get_meta("action_label",control.text))=="Trova risorse")[0]
	check(not guidance.disabled and guidance.get_global_rect().size.y>30,"recipe guidance remains an enabled prominent action even when crafting is blocked")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=get_viewport().get_visible_rect().size.y-20,"construction and recipe navigation fit 720p viewport")
	await capture("recipe_guidance_720")
	destination=nav.objective(player,step)
	await click(player,"TROVA REQUISITI")
	check(not player._is_paused and player._navigation_target.distance_to(destination.position)<0.01,"actual recipe button resumes play and marks matching component destination")
	check(GameState.team_credits==before.team_credits and GameState.team_deposit_counts==before.team_deposit_counts and craft.data().stock.is_empty(),"guidance does not grant stock money or bypass crafting")
	var damaged: Array = GameState.operations.field.values().filter(func(item):return item.kind=="battery" and int(item.quality)==0)
	check(not damaged.is_empty(),"fixture uses an actual damaged field battery")
	if not damaged.is_empty():
		var item: Dictionary = damaged[0]
		check(GameState.ops.pickup_part(item.id) and craft.next_requirement("restored_radio").route=="warehouse","carried component routes to storage before assembly")
		check(GameState.ops.store_held(),"carried battery deposits through real component service")
		step=craft.next_requirement("restored_radio")
		check(step.route=="salvage" and not step.material.is_empty(),"repair guidance first identifies missing repair ingredients")
		craft.data().stock.repair_kit=1
		check(craft.next_requirement("restored_radio").route=="craft" and craft.next_requirement("restored_radio").title.contains("kit"),"ready repair kit guides to usable garage action instead of an unfunded recovery bench")
		craft.data().stock.repair_kit=0
		for material in GameState.logistics_def.repair_materials:
			GameState.team_deposit_counts[material]=GameState.logistics_def.repair_materials[material]
		check(craft.next_requirement("restored_radio").route=="recovery","available repair ingredients route to recovery bench")
		check(GameState.ops.repair_part(item.id),"actual repair makes recovered component usable")
	step=craft.next_requirement("restored_radio")
	check(step.route=="salvage" and not step.material.is_empty(),"working component reveals next raw recipe shortage")
	var material: String = step.material
	var missing: int = int(craft.definitions().restored_radio.materials[material])-int(GameState.team_deposit_counts.get(material,0))
	GameState.player_inventories[1][material]=missing
	check(craft.next_requirement("restored_radio").route=="depot","ingredients already in bag route to deposit rather than unnecessary collection")
	GameState.player_inventories[1][material]=0
	GameState.operations.cargo[material]=missing
	check(craft.next_requirement("restored_radio").route=="warehouse","ingredients in buggy route to cargo unloading")
	GameState.operations.cargo.clear()
	for ingredient in craft.definitions().restored_radio.materials:
		GameState.team_deposit_counts[ingredient]=craft.definitions().restored_radio.materials[ingredient]
	check(craft.next_requirement("restored_radio").route=="craft" and craft.can_craft("restored_radio"),"fully satisfied recipe directs player back to real construction confirmation")
	check(craft.craft("restored_radio",int(GameState.operations.serial)),"guided actual ingredients assemble successfully")
	for node in get_tree().get_nodes_in_group("bulk_parts"):
		if node.kind=="panel":
			node.queue_free()
	await frames(3)
	var panel: Dictionary = nav.objective(player,{"route":"salvage","material":"","part":"panel"})
	check(get_tree().get_nodes_in_group("salvage_assemblies").any(func(node):return node.global_position.distance_to(panel.position)<0.01),"missing loose component falls back to an actual dismantlable assembly")
	print("RECIPE_GUIDANCE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
