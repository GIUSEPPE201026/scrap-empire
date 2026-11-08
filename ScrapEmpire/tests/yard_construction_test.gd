extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/yard_construction_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	var craft=GameState.crafting
	GameState.team_upgrade_levels.tool=1
	for material in GameState.material_defs: GameState.team_deposit_counts[material]=50
	var wallet: int=GameState.team_credits
	for kind in preload("res://scripts/gameplay/yard_structures.gd").KINDS:
		var metal: int=GameState.team_deposit_counts.metal
		check(craft.craft(kind,int(GameState.operations.serial)) and GameState.team_deposit_counts.metal==metal-int(craft.definitions()[kind].materials.metal),"building consumes defined materials once: "+kind)
	await look(player,Vector3(43,0.08,62.1),Vector3(43,0,60))
	player._open_crafted_gear()
	await click(player,"POSIZIONA TETTOIA")
	await confirm_placement(player)
	check(craft.data().objects.size()==1 and craft.data().stock.yard_canopy==0,"equipment tile places a real persistent shelter")
	if craft.data().objects.is_empty():
		print("YARD_CONSTRUCTION_RESULT: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1)
		return
	var id: String=craft.data().objects.keys()[0]
	var shelter=player._craft_object(id)
	var at: Vector3=shelter.global_position
	var space=player.get_world_3d().direct_space_state
	var roof=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*5,at+Vector3.UP,1,[player.get_rid()]))
	check(not roof.is_empty() and roof.collider==shelter and roof.position.y>at.y+2.5,"shelter has a real roof collider")
	var crossing=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3(0,1.2,2),at+Vector3(0,1.2,-2),1,[player.get_rid()]))
	check(crossing.is_empty(),"shelter centre remains walkable rather than a solid invisible box")
	var before: Dictionary=craft.data().duplicate(true)
	var directory: String=SaveService.SAVE_DIR
	var errors: bool=Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var deployed: bool=craft.deploy("yard_wall",Vector3(70,0.04,60),0)
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(not deployed and craft.data()==before,"failed structure checkpoint returns module to stock without a ghost building")
	check(craft.deploy("yard_wall",Vector3(70,0.04,60),PI/2),"wall permits a persistent rotated layout")
	check(craft.deploy("yard_platform",Vector3(75,0.04,60),0),"platform deploys from constructed stock")
	await frames(3)
	check(SaveService.save_checkpoint(84) and SaveService.load_save(84) and craft.data().objects.size()==3,"all three module types survive validated save roundtrip")
	check(GameState.team_credits==wallet,"yard construction cannot create money")
	await look(player,at+Vector3(4,0.08,5),at+Vector3.UP)
	await capture("closure_personal_yard")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	player=get_tree().get_first_node_in_group("players")
	check(get_tree().get_nodes_in_group("crafted_objects").size()==3,"scene re-entry restores a single copy of each structure")
	check(GameState.crafting.pack(id) and int(GameState.crafting.data().stock.yard_canopy)==1 and not GameState.crafting.pack(id),"packing is reversible once without duplicating a module")
	print("YARD_CONSTRUCTION_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
