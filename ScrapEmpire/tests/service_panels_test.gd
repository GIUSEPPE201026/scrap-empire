extends "res://tests/crafting_test.gd"

func labels(player: Node) -> String:
	var result: PackedStringArray=[]
	for label in player._pause_menu.find_children("*","Label",true,false): result.append(label.text)
	return " ".join(result)

func run() -> void:
	get_window().size=Vector2i(1280,720)
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/service_panels_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	player.position=Vector3(0,0,12)
	player.velocity=Vector3.ZERO
	GameState.player_inventories[1].plastic=2
	GameState.team_deposit_counts.plastic=3
	player._open_cargo()
	await click(player,"Plastica")
	check(player._material_selection=="plastic" and labels(player).contains("PLASTICA"),"material selector opens the clicked material")
	if DisplayServer.get_name()!="headless":
		var tiles=player._pause_menu.find_children("*","Button",true,false).filter(func(button):return button.has_meta("material_id") and not button.has_meta("source"))
		var scroll: ScrollContainer=tiles[0].get_parent().get_parent()
		check(tiles.size()==7 and tiles.all(func(button):return scroll.get_global_rect().encloses(button.get_global_rect())),"all seven material selectors fit without scrolling at 720p")
	var wallet: int=GameState.team_credits
	var unit: int=GameState.material_defs.plastic.credits
	await click(player,"Vendi 1 Plastica dalla sacca")
	check(GameState.player_inventories[1].plastic==1 and GameState.team_deposit_counts.plastic==3 and GameState.team_credits==wallet+unit,"bag sale consumes only selected bag unit and credits once")
	check(player._material_selection=="plastic" and labels(player).contains("PLASTICA"),"selected material survives transactional panel refresh")
	await click(player,"Vendi 1 Plastica dalla scorta")
	check(GameState.player_inventories[1].plastic==1 and GameState.team_deposit_counts.plastic==2 and GameState.team_credits==wallet+2*unit,"stock sale consumes only selected deposit unit")
	await capture("service_materials")
	await click(player,"Vendi 1 Plastica dalla sacca")
	var empty: Button=player._pause_menu.find_children("*","Button",true,false).filter(func(button):return button.get_meta("source","")=="bag")[0]
	check(empty.disabled,"empty source disables sale")
	player._close_pause_menu()
	player.position=Vector3(0,0,115)
	player._open_cargo("plastic")
	check(player._pause_menu.find_children("*","Button",true,false).filter(func(button):return button.has_meta("source")).all(func(button):return button.disabled),"remote material inspection cannot sell")
	player._close_pause_menu()
	player._open_journal()
	check(not labels(player).contains(GameState.secret_defs[0].name) and labels(player).contains(GameState.secret_defs[0].hint),"undiscovered album shows hint without revealing relic name")
	await click(player,"Indizio 02")
	check(labels(player).contains(GameState.secret_defs[1].hint),"album changes actual selected hint")
	player._close_pause_menu()
	check(GameState.discover_secret(GameState.secret_defs[1].id),"real discovery service awards relic once")
	wallet=GameState.team_credits
	player._open_journal()
	check(labels(player).contains(GameState.secret_defs[1].name.to_upper()) and labels(player).contains("premio già assegnato"),"album automatically selects latest discovery and displays prior reward status")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.find_children("*","Button",true,false).filter(func(button):return button.has_meta("curiosity_index")).all(func(button):return button.find_children("*","Label",true,false).all(func(label):return button.get_global_rect().encloses(label.get_global_rect()))),"curiosity card names and badges stay inside their tile")
	await capture("service_curiosities_found")
	player._open_journal(1)
	check(GameState.team_credits==wallet and not GameState.discover_secret(GameState.secret_defs[1].id),"reopening album never duplicates discovery reward")
	player._close_pause_menu()
	var press=get_tree().get_first_node_in_group("industrial_press")
	player.position=press.interaction_position()+Vector3(0,0,-1.8)
	GameState.team_credits=1000
	GameState.team_deposit_counts.metal=20
	player._open_press()
	check(not player._station_buy.disabled and player._press_start_button.disabled,"press purchase and production ownership states are distinct")
	await click(player,"Acquista")
	check(GameState.press_owned and GameState.team_credits==1000-int(GameState.press_def.cost),"purchase button buys and charges exact balance price")
	await click(player,"Produzione")
	await click(player,"ACCODA 1 LOTTO")
	check(GameState.team_deposit_counts.metal==15 and GameState.press_remaining>0,"queue button reserves one actual lot")
	player._open_production_queue()
	await click(player,"ACCODA 1 LOTTO")
	check(GameState.team_deposit_counts.metal==10 and GameState.operations.press_queue==1,"second click queues waiting lot separately")
	player._open_production_queue()
	await capture("service_press_queued")
	await click(player,"Annulla coda")
	check(GameState.team_deposit_counts.metal==15 and GameState.operations.press_queue==0 and GameState.press_remaining>0,"cancel refunds waiting lot while active lot remains reserved")
	player._close_pause_menu()
	var credits_before: int=GameState.team_credits
	check(SaveService.save_checkpoint(95) and SaveService.load_save(95) and GameState.press_owned and GameState.press_remaining>0 and GameState.team_credits==credits_before and GameState.secret_defs[1].id in GameState.secrets_found,"UI transactions and discovery survive disk roundtrip")
	print("SERVICE_PANELS_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
