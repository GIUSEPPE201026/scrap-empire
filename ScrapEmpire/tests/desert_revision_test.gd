extends "res://tests/crafting_test.gd"
const LAND=preload("res://scripts/gameplay/desert_landmarks.gd")
const MARKER=preload("res://scripts/ui/navigation_marker.gd")

func view_site(player: Node3D, id: String, offset: Vector3) -> void:
	var camera=Camera3D.new()
	get_tree().current_scene.add_child(camera)
	camera.position=LAND.point(id)+offset
	camera.look_at(LAND.point(id)+Vector3.UP*3)
	camera.make_current()
	await frames(5)
	await capture("desert_"+id)
	player.camera.make_current()
	camera.queue_free()

func run() -> void:
	get_window().size=Vector2i(1280,720)
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/desert_revision_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	var navigation=preload("res://scripts/gameplay/yard_navigation.gd")
	check(get_tree().get_nodes_in_group("desert_landmarks").size()==1,"one desert landmark system exists")
	check(navigation.points(player).has("crash") and not navigation.points(player).has("cave") and not navigation.points(player).has("anomaly"),"cargo destination known while hidden locations await exploration")
	check(get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.entity_id.begins_with("desert_")).size()==4,"four recoverable cargo caches use real salvage objects")
	var recovered: Array=get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.entity_id.begins_with("desert_"))
	check(recovered.map(func(node):return node.definition_id).has("aircraft_turbine") and recovered.any(func(node):return node.definition_id=="survey_rig") and recovered.any(func(node):return node.definition_id=="signal_receiver"),"landmarks contain distinct recoveries rather than identical caches")
	check(not GameState.ops.visit_site("invented"),"unknown landmark cannot enter persistent progress")
	var original: String=SaveService.SAVE_DIR
	var print_errors: bool=Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed: bool=GameState.ops.visit_site("anomaly")
	Engine.print_error_messages=print_errors
	SaveService.SAVE_DIR=original
	check(not failed and GameState.operations.get("visited_sites",[]).is_empty(),"failed discovery checkpoint rolls back the visit")
	var wallet: int=GameState.team_credits
	player.position=LAND.point("cave")+Vector3(0,1,8)
	player.velocity=Vector3.ZERO
	await frames(40)
	check("cave" in GameState.operations.get("visited_sites",[]) and navigation.points(player).has("cave"),"actually approaching cavern discovers and maps it")
	check(GameState.team_credits==wallet and not GameState.ops.visit_site("cave"),"repeat visit cannot award currency or duplicate discovery")
	var space=player.get_world_3d().direct_space_state
	var underground=preload("res://scripts/gameplay/subterranean_cave.gd")
	var roof: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(375,-11,-281),Vector3(375,1,-281),1,[player.get_rid()]))
	check(not roof.is_empty() and roof.position.y<0,"real underground chamber has a physical roof below the desert surface")
	var surface: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(375,30,-281),Vector3(375,0,-281),1,[player.get_rid()]))
	check(not surface.is_empty() and surface.position.y>0,"intact desert exists above the underground chamber")
	var cave_start=Vector3(375,LAND.TERRAIN.height_at(Vector3(375,0,-232))+0.1,-232)
	await look(player,cave_start,Vector3(375,-10,-281))
	hold_test_action("move_forward")
	await frames(720)
	release_test_action("move_forward")
	check(player.global_position.y< -10 and player.global_position.z< -270 and player.is_on_floor(),"ordinary walking descends through real opening into underground chamber")
	var below: Vector3=player.global_position
	player._open_inventory()
	await click(player,"Cacciavite")
	check(player.global_position.distance_to(below)<0.1,"underground menu interaction does not teleport player to surface or hub")
	player._close_pause_menu()
	check(SaveService.save_checkpoint(92) and SaveService.load_save(92),"underground player position is accepted by persistent travel schema")
	var found: Dictionary=preload("res://scripts/save/travel_snapshot.gd")._ground(player,below,[player.get_rid()])
	check(not found.is_empty() and found.position.y< -10,"resume ground probe selects cave floor instead of desert above")
	await look(player,Vector3(376,underground.floor_height(Vector3(376,0,-274))+0.08,-274),Vector3(371,-12.5,-281))
	await capture("desert_cave_interior")
	var cave_position: Vector3=player.global_position
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	player=get_tree().get_first_node_in_group("players")
	check(player.global_position.y< -10 and player.global_position.distance_to(cave_position)<0.4,"return to menu and continue restores player inside cave without surface teleport")
	await view_site(player,"cave",Vector3(26,17,35))
	player.position=LAND.point("anomaly")+Vector3(0,1,19)
	player.velocity=Vector3.ZERO
	await frames(40)
	check("anomaly" in GameState.operations.get("visited_sites",[]) and navigation.points(player).has("anomaly"),"remote anomaly becomes a mapped discovery")
	await view_site(player,"anomaly",Vector3(23,16,29))
	await view_site(player,"crash",Vector3(32,24,40))
	var crate=get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.entity_id=="desert_crash_0")[0]
	GameState.yard_level=1
	GameState.crafting.data().stock["crowbar"]=1
	GameState.crafting.data().stock["bolt_cutters"]=1
	GameState.team_upgrade_levels.tool=2
	for definition in ["aircraft_turbine","survey_rig","signal_receiver"]:
		var entity: String="closure_"+definition
		check(not GameState.ops.claim_component(entity,definition,2,1,1,true).success,"deep component requires opening and isolation first: "+definition)
		for index in 3:
			var tool: int=int(GameState.salvage_defs[definition].steps[index].tool)
			check(GameState.ops.claim_component(entity,definition,index,1,tool,true).success and GameState.ops.store_held(),"recover and store distinct stage: %s/%d" % [definition,index])
		check(not GameState.ops.claim_component(entity,definition,2,1,1,true).success,"completed landmark cannot duplicate its core: "+definition)
	check(GameState.ops.claim_component(crate.entity_id,"sealed_crate",0,1,3,true).success and GameState.ops.store_held(),"crash cargo yields a real storable recovered component")
	check(not GameState.ops.claim_component(crate.entity_id,"sealed_crate",0,1,3,true).success,"same crash cargo stage cannot be recovered twice")
	check(SaveService.save_checkpoint(91) and SaveService.load_save(91) and "cave" in GameState.operations.get("visited_sites",[]) and "anomaly" in GameState.operations.get("visited_sites",[]) and GameState.ops.completed_components(crate.entity_id)==[0],"discoveries and recovered cargo stage survive disk roundtrip")
	var invalid: Dictionary=GameState.serialize().duplicate(true)
	invalid.operations.visited_sites=["bad"]
	check(not SaveService._validate_save_schema(invalid),"invalid discovery identifiers rejected on load")
	var legacy: Dictionary=GameState.serialize().duplicate(true)
	legacy.operations.erase("visited_sites")
	check(SaveService._validate_save_schema(legacy),"existing saves without discoveries remain valid")
	await look(player,Vector3(0,0.1,65),Vector3(0,2,80))
	player._open_career("map")
	player._career_map_wide=true
	preload("res://scripts/ui/career_panel.gd").open(player,"map")
	await frames(5)
	await capture("desert_world_map")
	await click(player,"Volo 76")
	check(not player._is_paused and player._navigation_target.distance_to(LAND.point("crash"))<0.01,"map destination button closes menu and sets actual cargo target")
	await look(player,Vector3(0,0.1,65),player._navigation_target+Vector3.UP*2.5)
	var view: Vector2=player.get_viewport().get_visible_rect().size
	var marker=MARKER.marker(view,player.camera,player._navigation_target+Vector3.UP*2.5)
	check(marker.inside and Vector2(marker.position).distance_to(view*0.5)<3,"front destination projects to visible central world marker")
	await capture("desert_waypoint")
	var behind: Vector3=player.camera.global_position+player.camera.global_basis.z*30
	marker=MARKER.marker(view,player.camera,behind)
	check(not marker.inside and Rect2(Vector2.ZERO,view).has_point(marker.position),"destination behind camera has an on-screen directional arrow")
	player.position=Vector3(0,0.1,106)
	var entrance_camera=Camera3D.new()
	get_tree().current_scene.add_child(entrance_camera)
	entrance_camera.position=Vector3(21,10,109)
	entrance_camera.look_at(Vector3(0,3.5,80))
	entrance_camera.make_current()
	await frames(5)
	await capture("desert_new_entrance")
	player.camera.make_current()
	entrance_camera.queue_free()
	print("DESERT_REVISION_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
