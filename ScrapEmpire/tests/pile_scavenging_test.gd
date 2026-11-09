extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/pile_scavenging_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player=get_tree().get_first_node_in_group("players")
	var items=get_tree().get_nodes_in_group("scrap")
	var hidden=get_tree().get_nodes_in_group("hidden_salvage")
	check(hidden.size()>=items.size()/3,"at least one third of loose salvage lies on piles")
	var ids: Dictionary={}
	for item in items: ids[item.entity_id]=true
	check(ids.size()==items.size(),"pile placement preserves unique collectible identities")
	var pile=get_tree().get_nodes_in_group("landfill_piles")[0]
	var point: Vector3=pile.global_position+Vector3(0,preload("res://scripts/gameplay/landfill_layout.gd").surface_height(Vector3.ZERO,0),0)
	await look(player,point+Vector3(0,0.15,1.2),point)
	player._process_collection(1.0/60.0)
	check(player._target_scrap!=pile,"aiming at pile does not start generic three-stage gathering")
	check(pile.layer_count()==0,"scavenging preserves old layer progress without granting rewards")
	print("PILE_SCAVENGING_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
