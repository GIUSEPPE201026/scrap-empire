extends "res://tests/crafting_test.gd"

func write_fixture(path: String, content: String) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(content)
	file.close()

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/save_recovery_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
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
	check(GameState.player_inventories[1].metal==1,"recovery fixture actually collects one raw object")
	GameState.team_credits=17
	check(SaveService.save_checkpoint(0,true),"automatic checkpoint writes valid bag and consumed identity")
	var automatic: Dictionary = SaveService.list_saves()[0]
	var valid_count: int = SaveService.list_saves().size()
	GameState.team_credits=0
	check(SaveService.load_save(0,int(automatic.timestamp)) and GameState.team_credits==17,"explicit timestamp loads automatic filename as well as manual format")
	var clock_floor: int = int(automatic.timestamp)+1000000
	SaveService._last_checkpoint_timestamp=clock_floor
	check(SaveService.save_checkpoint(0,true) and SaveService.save_checkpoint(0,true),"rapid automatic checkpoints still promote successfully with clock behind loaded sequence")
	var rolling: Array = SaveService.list_saves().filter(func(entry):return entry.filename.contains("_auto_"))
	check(rolling.size()==2 and int(rolling[0].timestamp)>int(rolling[1].timestamp) and int(rolling[1].timestamp)>clock_floor,"checkpoint names strictly increase even when wall clock is behind previous save")
	automatic=rolling[0]
	SaveService._last_checkpoint_timestamp=0
	check(SaveService.load_save(0,int(automatic.timestamp)) and SaveService._last_checkpoint_timestamp>=int(automatic.timestamp),"cold explicit load anchors subsequent checkpoint sequence to loaded timestamp")
	valid_count=SaveService.list_saves().size()
	var snapshot: Dictionary = GameState.serialize().duplicate(true)
	for field in ["timestamp","save_slot"]:
		for invalid in [{},[],"100",-1,0.5,INF]:
			var bad: Dictionary = snapshot.duplicate(true)
			bad[field]=invalid
			check(not SaveService._validate_save_schema(bad),"invalid checkpoint metadata rejected: "+field+" / "+str(invalid))
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed.schema_version="unknown"
	check(not SaveService._validate_save_schema(malformed),"unknown schema fails validation without formatting errors")
	malformed=snapshot.duplicate(true)
	malformed.timestamp={"broken":"sort key"}
	var broken_metadata: String = SaveService.SAVE_DIR+"scrapempire_%d_slot0.json" % (int(automatic.timestamp)+1000)
	write_fixture(broken_metadata,JSON.stringify(malformed))
	var broken_json: String = SaveService.SAVE_DIR+"scrapempire_%d_slot0.json" % (int(automatic.timestamp)+2000)
	write_fixture(broken_json,"{unfinished checkpoint")
	check(SaveService.list_saves().size()==valid_count,"save enumeration ignores malformed metadata without crashing sort")
	# Return to menu without writing over the deliberately arranged recovery history.
	SessionState._cleanup_and_return_to_menu()
	await frames(12)
	GameState.team_credits=0
	GameState.player_inventories.clear()
	GameState.sector_consumed_ids.clear()
	SessionState.progression_loaded=false
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	check(GameState.team_credits==17 and GameState.player_inventories[1].metal==1 and "metal_008" in GameState.sector_consumed_ids,"normal single player startup falls back to valid autosave with bag and world atomically")
	check(get_tree().get_nodes_in_group("scrap").size()==119 and get_tree().get_nodes_in_group("players").size()==1,"recovered world omits consumed source and never duplicates player")
	check(FileAccess.get_file_as_string(broken_json)=="{unfinished checkpoint" and FileAccess.get_file_as_string(broken_metadata)==JSON.stringify(malformed),"both corrupt files remain byte for byte available for recovery")
	check(SessionState.progression_notice.contains("non valido"),"startup explains that corrupt checkpoint was preserved")
	print("SAVE_RECOVERY_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
