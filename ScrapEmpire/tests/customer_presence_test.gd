extends "res://tests/crafting_test.gd"

func customer(id: String) -> Node3D:
	return get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("customer","")==id)[0]

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/presence_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var marta = customer("marta")
	check(not marta.get_meta("customer_active") and marta._shape.disabled,"unopened stand has no invisible human collider")
	await look(player,marta.position+Vector3(0,0.05,-2),marta.position+Vector3.UP*1.2)
	var approach: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("move_forward")
	check(player.position.distance_to(approach)<0.8 and not player._is_paused,"solid counter stops walking through stand without opening a menu automatically")
	var focus: Dictionary = preload("res://scripts/gameplay/interaction_focus.gd").resolve(player)
	check(focus.kind=="operation" and focus.node==marta and player._interact_prompt.text.contains("POSTAZIONE"),"closed stand remains inspectable without pretending absent vendor is speaking")
	player._activate_interaction(focus)
	check(player._is_paused and GameState.crafting.demand("marta")==0,"preview shows locked demand and no free sale")
	await capture("customer_closed_stand")
	player._close_pause_menu()
	GameState.team_deposit_counts.metal=8
	GameState.team_deposit_counts.plastic=6
	GameState.team_deposit_counts.electronics=2
	check(GameState.complete_order("yard_restart"),"actual first campaign delivery opens neighborhood commerce")
	await frames(3)
	check(marta.get_meta("customer_active") and not marta._shape.disabled and not customer("enzo").get_meta("customer_active"),"first vendor arrives while later vendors remain gated")
	if DisplayServer.get_name()!="headless":
		check(marta._person.visible and not customer("nina")._person.visible,"rendered people appear only with their actual progression milestone")
		await look(player,marta.position+Vector3(2.3,0.05,-3),marta.position+Vector3.UP*1.3)
		var original: Vector3 = marta.position
		await frames(80)
		check(absf(marta._head.rotation.y)>0.1 and marta.position==original,"vendor tracks nearby player with head without moving collision body")
	GameState.team_upgrade_levels.tool=1
	GameState.team_deposit_counts.metal=2
	GameState.team_deposit_counts.plastic=1
	GameState.team_deposit_counts.electronics=1
	check(GameState.crafting.craft("desk_lamp",int(GameState.operations.serial)) and GameState.crafting.sell_product("marta",1,int(GameState.operations.serial)),"first sale uses a genuinely crafted object")
	check(marta._wave>2,"first real customer sale triggers visible acknowledgement")
	player._open_pause_menu()
	var timer: float = marta._wave
	await frames(30)
	check(is_equal_approx(marta._wave,timer),"customer animation timers obey single-player pause")
	player._close_pause_menu()
	await frames(40)
	if DisplayServer.get_name()!="headless":
		check(marta._arm.rotation.z>0.5,"sale feedback moves actual vendor arm")
		await capture("customer_marta_acknowledgement")
	GameState.yard_level=1
	GameState.team_deposit_counts.copper=4
	GameState.team_deposit_counts.aluminum=4
	GameState.team_deposit_counts.electronics=3
	check(GameState.complete_order("precision_supply"),"actual second campaign delivery advances commerce")
	await frames(3)
	check(customer("enzo").get_meta("customer_active") and customer("nina").get_meta("customer_active") and not customer("ada").get_meta("customer_active"),"second chapter visibly adds maintenance and restoration customers")
	check(SaveService.save_checkpoint(96),"commerce milestone and sale receipt save")
	player._do_quit_to_menu()
	await frames(12)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	player=get_tree().get_first_node_in_group("players")
	check(customer("nina").get_meta("customer_active") and customer("marta")._wave==0 and GameState.crafting.demand("marta")==2,"scene reentry restores presence and quota without replaying sale gesture")
	if DisplayServer.get_name()!="headless":
		var nina = customer("nina")
		await look(player,nina.position+Vector3(1.6,0.05,-2.3),nina.position+Vector3.UP*1.25)
		await capture("customer_nina_stand")
	print("CUSTOMER_PRESENCE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
