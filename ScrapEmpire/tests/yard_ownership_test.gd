extends "res://tests/fabrication_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/yard_ownership_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	for action in ["move_forward","move_back","move_left","move_right","jump","sprint"]:
		InputMap.action_erase_events(action)
	var sector=get_tree().get_first_node_in_group("sector")
	var space=player.get_world_3d().direct_space_state
	for gate in [Vector3(0,1,-80),Vector3(0,1,80),Vector3(-80,1,0),Vector3(80,1,0)]:
		var direction=Vector3.RIGHT if absf(gate.x)>1 else Vector3.BACK
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(gate-direction*2,gate+direction*2,1,[player.get_rid()]))
		check(hit.is_empty(),"visible gate has no invisible collision: "+str(gate))
	var fence=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(20,1,-78),Vector3(20,1,-82),1,[player.get_rid()]))
	check(not fence.is_empty() and fence.collider.is_in_group("yard_fence"),"solid fence still collides where its panels are visible")
	for site in GameState.logistics_def.outposts:
		var point=Vector3(site.position[0],0,site.position[2])
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*30,point-Vector3.UP*5,1,[player.get_rid()]))
		check(not hit.is_empty(),"expanded map has physical terrain at "+site.id)
	check(preload("res://scripts/save/travel_snapshot.gd").point_valid([500,10,-500]),"expanded-map travel remains saveable")
	check(not preload("res://scripts/save/travel_snapshot.gd").point_valid([700,0,0]),"travel outside the physical sector remains rejected")
	var craft=GameState.crafting
	check(not GameState.owns_tool(3) and not GameState.owns_tool(4),"constructed tools are not granted by ordinary hammer ownership")
	GameState.completed_orders=GameState.order_defs.slice(0,3).map(func(order):return order.id)
	GameState.team_upgrade_levels.tool=2
	GameState.yard_level=2
	GameState.vehicle_level=2
	GameState.workshop_modules.workbench=1
	for material in GameState.material_defs:
		GameState.team_deposit_counts[material]=100
	check(craft.craft("crowbar",int(GameState.operations.serial)) and GameState.owns_tool(3),"real recipe constructs permanent crowbar")
	check(not craft.craft("crowbar",int(GameState.operations.serial)),"one permanent crowbar cannot be duplicated")
	check(craft.craft("bolt_cutters",int(GameState.operations.serial)) and GameState.owns_tool(4),"real recipe constructs complementary cutters")
	player._equip_tool(3)
	check(player._active_tool()==3,"crowbar can be equipped without hammer-level clamping")
	player._open_inventory()
	await capture("ownership_tools")
	player._close_pause_menu()
	var crate=get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.definition_id=="sealed_crate")[0]
	check(not GameState.ops.claim_component(crate.entity_id,"sealed_crate",0,1,2,true).success,"hammer cannot substitute for the pry stage")
	check(GameState.ops.claim_component(crate.entity_id,"sealed_crate",0,1,3,true).success and GameState.ops.store_held(),"crowbar opens lid and recovers actual panel")
	check(not GameState.ops.claim_component(crate.entity_id,"sealed_crate",1,1,3,true).success,"crowbar cannot cut crate straps")
	check(GameState.ops.claim_component(crate.entity_id,"sealed_crate",1,1,4,true).success and GameState.ops.store_held(),"cutters separate straps and recover battery")
	check(not GameState.ops.claim_component(crate.entity_id,"sealed_crate",2,1,4,true).success,"cutters cannot replace precision screwdriver")
	check(GameState.ops.claim_component(crate.entity_id,"sealed_crate",2,1,1,true).success and GameState.ops.store_held(),"screwdriver completes sequential precision recovery")
	check(not GameState.ops.claim_component(crate.entity_id,"sealed_crate",0,1,3,true).success,"completed crate stage cannot award twice")
	GameState.ops.seed_field_parts()
	check(not stock_component("wheel").is_empty(),"actual recovered wheel available for suspension fabrication")
	var money: int=GameState.team_credits
	var metal: int=GameState.team_deposit_counts.metal
	var ticket: int=GameState.operations.serial
	check(craft.craft("suspension_kit",ticket) and GameState.team_deposit_counts.metal==metal-14,"upgrade kit consumes recipe materials and recovered wheel")
	check(not craft.craft("suspension_kit",ticket),"replayed fabrication ticket cannot consume ingredients twice")
	ticket=GameState.operations.serial
	check(craft.install("suspension_kit",ticket) and GameState.workshop_modules.suspension==1 and GameState.team_credits==money,"built kit installs actual suspension level without credit charge")
	check(not craft.install("suspension_kit",ticket),"installation replay cannot grant a second level")
	check(craft.craft("bag_frame",int(GameState.operations.serial)),"bag frame is constructed from free warehouse stock")
	var directory: String=SaveService.SAVE_DIR
	SaveService.SAVE_DIR="res://project.godot/"
	var output: bool=Engine.print_error_messages
	Engine.print_error_messages=false
	var failed: bool=craft.install("bag_frame",int(GameState.operations.serial))
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(not failed and GameState.team_upgrade_levels.bag==0 and int(craft.data().stock.bag_frame)==1,"failed installation checkpoint restores kit and capacity together")
	check(craft.install("bag_frame",int(GameState.operations.serial)) and GameState.get_inventory_capacity(1)==30,"bag construction changes carrying capacity")
	await look(player,Vector3(4,0.08,24.2),Vector3(4,1.3,26.4))
	player._open_crafting("bag_frame")
	await capture("ownership_build_upgrade")
	await click(player,"COSTRUISCI")
	await click(player,"Installa")
	check(GameState.get_inventory_capacity(1)==40 and GameState.team_credits==money,"real workshop buttons fabricate and install a bag upgrade without spending credits")
	player._close_pause_menu()
	GameState.completed_orders=GameState.order_defs.map(func(order):return order.id)
	GameState.workshop_modules.suspension=2
	GameState.operations.deliveries=0
	check(not GameState.module_requirement("suspension",false).is_empty(),"advanced tier requires repeatable delivery progression")
	GameState.operations.deliveries=2
	check(GameState.module_requirement("suspension",false).is_empty(),"two deliveries unlock third suspension tier")
	var identity=preload("res://scripts/economy/yard_identity.gd")
	check(not identity.apply("\n",1,2,GameState.operations.serial),"invalid empty/control-character sign rejected")
	ticket=GameState.operations.serial
	check(identity.apply("Officina delle Dune",3,2,ticket),"custom name and both vehicle paint choices save atomically")
	check(not identity.apply("Replay",0,0,ticket),"customization uses a fresh serial receipt")
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	failed=identity.apply("Non salvato",0,0,GameState.operations.serial)
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(not failed and identity.data().name=="Officina delle Dune","failed identity save preserves previous sign and colours")
	sector.spawn_owned_vehicles()
	await frames(4)
	check(sector.find_children("CustomYardName","Label3D",true,false)[0].text=="Officina delle Dune","entrance sign shows the saved player name")
	if DisplayServer.get_name()!="headless":
		var buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
		check(buggy.paint_panels[0].material_override.get_shader_parameter("paint_color")==identity.COLORS[3],"buggy body receives its own saved paint material")
		await look(player,Vector3(22,2,34),Vector3(20,1.1,30))
		await capture("ownership_custom_buggy")
	await look(player,preload("res://scripts/gameplay/hub_layout.gd").VEHICLES+Vector3(0,0.08,-1.5),preload("res://scripts/gameplay/hub_layout.gd").VEHICLES+Vector3.UP*1.3)
	player._open_personalization()
	await capture("ownership_personalization")
	var choices: Array=player._pause_menu.find_children("*","OptionButton",true,false)
	choices[0].select(4)
	var identity_ticket: int=GameState.operations.serial
	await click(player,"Salva")
	check(not player._is_paused and identity.data().buggy==4 and GameState.operations.serial==identity_ticket+1,"actual garage customization button applies and saves selected paint")
	player._close_pause_menu()
	await look(player,Vector3(0,0.08,70),Vector3(0,4.8,80))
	await capture("ownership_entrance_sign")
	check(GameState.ops.claim_component("depot_fixture","sealed_crate",0,1,3,true).success and GameState.ops.store_held(),"second real crate panel supports field construction")
	check(craft.craft("field_depot",int(GameState.operations.serial)),"field depot is crafted with panels rather than granted by a purchase")
	var spot=Vector3(350,preload("res://scripts/gameplay/desert_world.gd").height_at(Vector3(350,0,100))+0.05,100)
	check(craft.deploy("field_depot",spot,0),"constructed depot deploys on the expanded map")
	await frames(6)
	var objects: Array=craft.data().objects.keys()
	check(objects.size()==1,"one construction corresponds to one persistent placed identity")
	player.position=spot+Vector3(2,0,0)
	GameState.player_inventories[1].metal=3
	var before: int=GameState.team_deposit_counts.metal
	player._deposit_field()
	check(GameState.player_inventories[1].metal==0 and GameState.team_deposit_counts.metal==before+3,"player-built field depot transfers bag materials without sale or duplication")
	player._close_pause_menu()
	var save: Dictionary=GameState.serialize().duplicate(true)
	check(SaveService._validate_save_schema(save),"new tools projects identity and placed structure pass save validation")
	check(SaveService.save_checkpoint(95) and SaveService.load_save(95) and GameState.owns_tool(3) and identity.data().name=="Officina delle Dune" and craft.data().objects.size()==1,"all ownership progression survives an actual disk roundtrip")
	save.operations.identity.buggy=99
	check(not SaveService._validate_save_schema(save),"out-of-catalog paint cannot enter a loaded profile")
	player.position=Vector3(0,0.08,14)
	player._open_station("expedition")
	player._new_expedition()
	await frames(30)
	check(get_tree().get_nodes_in_group("players").size()==1 and GameState.owns_tool(3) and identity.data().name=="Officina delle Dune" and craft.data().objects.size()==1,"new expedition preserves constructed tools identity and player-placed infrastructure without duplicate players")
	print("YARD_OWNERSHIP_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
