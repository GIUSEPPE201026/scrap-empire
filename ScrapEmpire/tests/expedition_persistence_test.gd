extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/expedition_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var source = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.entity_id=="metal_008")[0]
	await aim(player,source)
	Input.action_press("collect")
	await frames(200)
	Input.action_release("collect")
	await frames(3)
	check(GameState.player_inventories[1].metal==1 and "metal_008" in GameState.sector_consumed_ids,"actual hold collection records both bag and source identity")
	check(SaveService.save_checkpoint(85),"partially filled expedition saves")
	var snapshot: Dictionary = GameState.serialize().duplicate(true)
	check(SaveService._validate_save_schema(snapshot),"raw expedition checkpoint validates")
	player._do_quit_to_menu()
	await frames(12)
	check(get_tree().current_scene.name=="MainMenu" and not get_tree().paused,"return to menu completes and unpauses")
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	player = get_tree().get_first_node_in_group("players")
	check(GameState.player_inventories[1].metal==1,"menu round trip keeps ordinary raw bag")
	check(get_tree().get_nodes_in_group("scrap").size()==119 and get_tree().get_nodes_in_group("players").size()==1,"resume omits consumed object without duplicating player")
	check(not GameState.recover_world_scrap(1,"metal_008","metal",0),"saved source cannot be collected twice")
	player._do_quit_to_menu()
	await frames(12)
	GameState.player_inventories.clear()
	GameState.sector_consumed_ids.clear()
	check(SaveService.load_save(85),"cold runtime loads expedition from disk")
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	player = get_tree().get_first_node_in_group("players")
	check(GameState.player_inventories[1].metal==1 and get_tree().get_nodes_in_group("scrap").size()==119,"disk resume preserves carried material and depleted world together")
	await capture("expedition_resume")
	SaveService._autosave_elapsed=59.99
	player._open_pause_menu()
	await frames(6)
	check(is_equal_approx(SaveService._autosave_elapsed,59.99),"pause freezes automatic save countdown")
	player._close_pause_menu()
	await frames(3)
	check(SaveService._autosave_elapsed<1 and SaveService._find_latest_save(0).contains("_auto_"),"active world triggers rolling automatic checkpoint")
	check(SaveService.save_checkpoint(0,true) and SaveService.save_checkpoint(0,true),"subsequent rolling checkpoints promote successfully")
	var automatic: Array = SaveService.list_saves().filter(func(entry):return entry.filename.contains("_auto_"))
	check(automatic.size()==2 and SaveService.list_saves().any(func(entry):return entry.slot==85),"rolling history keeps two auto saves without deleting manual history")
	var corrupt_auto: String = SaveService.SAVE_DIR+"scrapempire_12_auto_slot0.json"
	var corrupt_file = FileAccess.open(corrupt_auto,FileAccess.WRITE)
	corrupt_file.store_string("broken save")
	corrupt_file.close()
	SaveService.save_checkpoint(0,true)
	check(FileAccess.file_exists(corrupt_auto),"automatic rotation preserves corrupt files for recovery")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.local_expedition.consumed.append("metal_008")
	check(not SaveService._validate_save_schema(bad),"duplicate consumed identity rejected")
	bad = snapshot.duplicate(true)
	bad.local_expedition.consumed=["copper_000"]
	check(not SaveService._validate_save_schema(bad),"locked expansion identity rejected")
	for value in [-1,0.5,100]:
		bad = snapshot.duplicate(true)
		bad.local_expedition.bag.metal=value
		check(not SaveService._validate_save_schema(bad),"negative fractional or overcapacity bag rejected: "+str(value))
	bad = snapshot.duplicate(true)
	bad.local_expedition.bag.unknown=1
	check(not SaveService._validate_save_schema(bad),"unknown bag material rejected")
	bad = snapshot.duplicate(true)
	bad.local_expedition.revision=0
	check(not SaveService._validate_save_schema(bad),"consumption revision cannot precede identities")
	var path: String = SaveService.SAVE_DIR+"scrapempire_123_slot87.json"
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	var logging: bool = Engine.print_error_messages
	Engine.print_error_messages=false
	var rejected: bool = not SaveService.load_save(87,123)
	Engine.print_error_messages=logging
	check(rejected and FileAccess.file_exists(path) and GameState.player_inventories[1].metal==1,"corrupt expedition remains preserved and does not mutate active bag")
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR="res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages=false
	var exit_blocked: bool = not SaveService.save_before_exit()
	player._do_quit_to_menu()
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	await frames(3)
	check(exit_blocked and not get_tree().auto_accept_quit,"OS close refuses to discard unsaved expedition on write failure")
	check(get_tree().get_first_node_in_group("players")==player and GameState.player_inventories[1].metal==1,"failed exit save leaves player and bag in world")
	check(SaveService.save_before_exit() and SaveService.last_save_notice=="Salvato","normal OS close preflight writes expedition before allowing exit")
	var epoch: int = GameState.operations.epoch
	check(not GameState.reset_for_new_mission("C01",true) and GameState.operations.epoch==epoch,"new expedition refuses nonempty bag")
	check(GameState.deposit_inventory(1)>0 and GameState.team_deposit_counts.metal==1,"restored bag deposits exactly once")
	check(GameState.deposit_inventory(1)==0 and GameState.team_deposit_counts.metal==1,"repeated deposit cannot duplicate saved material")
	check(GameState.reset_for_new_mission("C01",true) and GameState.sector_consumed_ids.is_empty() and GameState.team_deposit_counts.metal==1,"explicit new expedition renews sources while keeping stock")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.erase("local_expedition")
	check(SaveService._validate_save_schema(legacy) and GameState.deserialize(legacy),"legacy checkpoint remains loadable")
	check(GameState.get_inventory_mass(1)==0 and GameState.sector_consumed_ids.is_empty(),"legacy checkpoint starts clean raw expedition")
	print("EXPEDITION_PERSISTENCE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
