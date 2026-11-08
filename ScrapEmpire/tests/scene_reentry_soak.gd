extends "res://tests/crafting_test.gd"

func take_one() -> bool:
	var sources: Array = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.entity_id=="metal_000" and not node.is_queued_for_deletion())
	if sources.is_empty() or not GameState.recover_world_scrap(1,"metal_000","metal",0):
		return false
	sources[0].collect()
	return true

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/reentry_soak_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	check(take_one(),"scene soak starts with one canonical raw object in bag")
	await frames(3)
	var baseline: int = 0
	var peak: int = 0
	var stored: int = 0
	var first_epoch: int = GameState.operations.epoch
	for cycle in 16:
		var player = get_tree().get_first_node_in_group("players")
		player._open_inventory()
		await frames(3)
		player._close_pause_menu()
		player._open_career("map")
		await frames(3)
		player._close_pause_menu()
		await frames(4)
		player._do_quit_to_menu()
		await frames(10)
		check(get_tree().current_scene.name=="MainMenu" and get_tree().get_nodes_in_group("players").is_empty() and get_tree().get_nodes_in_group("yard_audio").is_empty() and get_tree().get_nodes_in_group("world_interaction_prompt").is_empty(),"menu releases player audio and world prompt: "+str(cycle+1))
		get_tree().current_scene._on_single_pressed()
		await frames(25)
		player=get_tree().get_first_node_in_group("players")
		check(get_tree().get_nodes_in_group("players").size()==1 and get_tree().get_nodes_in_group("sector").size()==1 and get_tree().get_nodes_in_group("yard_clock").size()==1 and get_tree().get_nodes_in_group("yard_audio").size()==1,"reentry recreates exactly one live world: "+str(cycle+1))
		check(GameState.player_inventories[1].metal==1 and GameState.team_deposit_counts.metal==stored and get_tree().get_nodes_in_group("scrap").size()==119 and GameState.team_credits==0,"reentry preserves raw bag depletion stock and zero-bonus balance: "+str(cycle+1))
		if cycle==1:
			baseline=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if cycle>=2:
			peak=maxi(peak,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if cycle%4==3:
			check(GameState.deposit_inventory(1)>0,"actual deposit before periodic new expedition: "+str(cycle+1))
			stored+=1
			var epoch: int = GameState.operations.epoch
			player.position=Vector3(0,0.1,14)
			player._new_expedition()
			await frames(25)
			check(int(GameState.operations.epoch)==epoch+1 and take_one(),"fresh expedition renews source once with progression retained: "+str(cycle+1))
			await frames(3)
	check(baseline>0 and peak<=baseline+8,"steady scene node count remains bounded through repeated windows and reloads")
	check(GameState.operations.epoch==first_epoch+4 and GameState.team_deposit_counts.metal==4 and GameState.player_inventories[1].metal==1,"four fresh expeditions conserve five recovered units in total")
	check(SaveService.save_checkpoint(96) and SaveService.load_save(96) and GameState.team_deposit_counts.metal==4 and GameState.player_inventories[1].metal==1,"soaked world still checkpoints and loads exact combined materials")
	print("SCENE_SOAK_METRICS cycles=16 baseline_nodes=",baseline," peak_nodes=",peak," stored=",stored)
	print("SCENE_SOAK_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
