extends "res://tests/crafting_test.gd"
const TERMINAL=preload("res://scripts/gameplay/forklift_terminal.gd")

func key_h() -> void:
	var command=InputEventKey.new()
	command.physical_keycode=KEY_H
	command.pressed=true
	inject_input(command)
	await frames(3)
	command=command.duplicate()
	command.pressed=false
	inject_input(command)
	await frames(3)

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/forklift_terminal_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	if OS.get_cmdline_user_args().has("--english"): Localization.set_language("en")
	GameState.yard_level=2
	GameState.team_credits=5000
	var sector=get_tree().get_first_node_in_group("sector")
	sector.apply_land_expansions()
	check(preload("res://scripts/economy/extra_mobility.gd").purchase("forklift"),"terminal uses purchased forklift")
	sector.spawn_owned_vehicles()
	var machine=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="forklift")[0]
	var player=get_tree().get_first_node_in_group("players")
	var jobs=preload("res://scripts/economy/industrial_jobs.gd")
	var work: bool=OS.get_cmdline_user_args().has("--industrial-work")
	if work: check(jobs.start("forklift",int(GameState.operations.serial)),"forklift shipping contract accepted")
	machine.position=Vector3(43,0.08,57)
	player.position=machine.position+Vector3(1.4,0,0)
	GameState.team_deposit_counts.metal=2
	GameState.team_deposit_counts.plastic=1
	GameState.press_owned=true
	GameState.press_bales=6
	var service=GameState.crafting
	check(service.craft("bale_pallet",int(GameState.operations.serial)) and service.deploy("bale_pallet",Vector3(43,0.08,55.1),0),"empty pallet prepared with real construction recipe")
	var id: String=service.data().objects.keys()[0]
	check(player._mount_vehicle(machine),"driver boards forklift")
	await frames(25)
	check(machine.toggle_load(player),"forklift picks empty pallet before loading")
	check(not TERMINAL.execute(machine,player,"load",0,int(GameState.operations.serial)),"cannot load warehouse bales remotely")
	machine.lift=0.7
	player.position=sector.get_node("DepositZone").global_position+Vector3(0,0.08,5)
	player._vehicle_motion.parking_brake=true
	await frames(60)
	check(TERMINAL.station(machine,player)=="warehouse","carried pallet connects to warehouse in range with clear line")
	player._vehicle_speed=2.0
	check(not TERMINAL.execute(machine,player,"load",0,int(GameState.operations.serial)),"moving forklift cannot operate pallet terminal")
	player._vehicle_speed=0.0
	var wall=StaticBody3D.new()
	var wall_shape=CollisionShape3D.new()
	wall_shape.shape=BoxShape3D.new()
	wall_shape.shape.size=Vector3(3,3,0.15)
	wall.add_child(wall_shape)
	get_tree().current_scene.add_child(wall)
	wall.position=(machine.carried.global_position+sector.get_node("DepositZone").global_position)*0.5+Vector3.UP*1.3
	await frames(3)
	check(TERMINAL.station(machine,player)=="" and not TERMINAL.execute(machine,player,"load",0,int(GameState.operations.serial)),"terminal cannot transfer through a wall")
	wall.queue_free()
	await frames(3)
	var roof=StaticBody3D.new()
	var collider=CollisionShape3D.new()
	collider.shape=BoxShape3D.new()
	collider.shape.size=Vector3(2,0.12,2)
	roof.add_child(collider)
	get_tree().current_scene.add_child(roof)
	roof.position=machine.carried.global_position+Vector3.UP*0.8
	await frames(3)
	check(not TERMINAL.execute(machine,player,"load",0,int(GameState.operations.serial)) and GameState.press_bales==6,"overhead obstruction prevents creating a loaded pallet inside geometry")
	roof.queue_free()
	await frames(3)
	var directory: String=SaveService.SAVE_DIR
	var errors: bool=Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed: bool=TERMINAL.execute(machine,player,"load",0,int(GameState.operations.serial))
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(not failed and GameState.press_bales==6 and int(service.data().objects[id].get("bales",0))==0,"failed loading checkpoint restores warehouse and pallet")
	await key_h()
	check(player._is_paused and is_instance_valid(player._pause_menu),"H opens seated terminal and pauses single player")
	check(player._pause_menu.find_children("*","Button",true,false).filter(func(button):return button.visible and button.text in ["CARICA BALLE","RESTITUISCI"]).size()==2 and not player._pause_menu.find_children("*","Button",true,false).any(func(button):return button.visible and button.text.begins_with(Localization.text("SPEDISCI"))),"warehouse shows transfers and hides sale action")
	await capture("forklift_terminal_warehouse_"+Localization.language)
	var popup=player._pause_menu
	await click(player,"CARICA BALLE")
	check(GameState.press_bales==2 and service.data().objects[id].bales==4,"terminal button loads four bales without dismounting")
	check(player._pause_menu==popup and player._is_paused and player._mounted_vehicle==machine,"terminal action keeps same popup and seated driver")
	check(is_equal_approx(machine.load_collision.shape.size.y,1.18),"loaded pallet driver proxy grows with reserved bales")
	check(not TERMINAL.execute(machine,player,"return",0,int(GameState.operations.serial)),"stale pallet manifest cannot execute a different transfer")
	await click(player,"RESTITUISCI")
	check(GameState.press_bales==6 and service.data().objects[id].bales==0 and is_equal_approx(machine.load_collision.shape.size.y,0.22),"return restores bales and shrinks collision proxy")
	await click(player,"CARICA BALLE")
	var credits: int=GameState.team_credits
	var ticket: int=int(GameState.operations.serial)
	check(not TERMINAL.execute(machine,player,"ship",4,ticket) and GameState.team_credits==credits,"warehouse terminal cannot sell bales")
	player._close_pause_menu()
	var dispatch=get_tree().get_nodes_in_group("operations_service").filter(func(n):return n.get_meta("operation","")=="dispatch")[0]
	player.position=dispatch.global_position+Vector3(0,0.08,5)
	await frames(60)
	check(TERMINAL.station(machine,player)=="dispatch","pallet connects to physical dispatch dock")
	await key_h()
	check(not player._pause_menu.find_children("*","Button",true,false).any(func(button):return button.visible and button.text in ["CARICA BALLE","RESTITUISCI"]),"dock hides warehouse transfers")
	await capture("forklift_terminal_dispatch_"+Localization.language)
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	failed=TERMINAL.execute(machine,player,"ship",4,int(GameState.operations.serial))
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(not failed and GameState.team_credits==credits and service.data().objects[id].bales==4,"failed seated dispatch checkpoint preserves payment and cargo")
	if work: check(jobs.progress("forklift").units==0,"failed shipment creates no job progress")
	await click(player,Localization.text("SPEDISCI"))
	check(GameState.team_credits==credits+4*GameState.get_bale_value() and service.data().objects[id].bales==0 and machine.carried.craft_id==id,"explicit shipping pays once and retains reusable pallet on forks")
	check(not TERMINAL.execute(machine,player,"ship",4,ticket),"replayed dispatch manifest cannot credit twice")
	if work:
		check(jobs.progress("forklift").units==4,"four physically shipped bales complete first forklift job")
		var payment: int=int(jobs.tier("forklift").reward)
		var balance: int=GameState.team_credits
		var reward_ticket: int=int(GameState.operations.serial)
		SaveService.SAVE_DIR="res://project.godot/"
		Engine.print_error_messages=false
		var paid: bool=jobs.claim("forklift",reward_ticket)
		Engine.print_error_messages=errors
		SaveService.SAVE_DIR=directory
		check(not paid and GameState.team_credits==balance and jobs.progress("forklift").units==4,"failed reward checkpoint preserves ready job and balance")
		check(jobs.claim("forklift",reward_ticket) and GameState.team_credits==balance+payment,"job reward pays configured amount exactly once")
		check(not jobs.claim("forklift",reward_ticket) and jobs.progress("forklift").tier==1,"repeated claim cannot pay again")
		check(jobs.start("forklift",int(GameState.operations.serial)) and jobs.tier("forklift").goal==8,"next logistics job provides a larger goal")
		var forged: Dictionary=GameState.serialize().duplicate(true)
		forged.operations.industrial_jobs.forklift.units=1000
		check(not SaveService._validate_save_schema(forged),"invalid saved industrial job progress rejected")
	player._close_pause_menu()
	check(SaveService.save_checkpoint(109) and SaveService.load_save(109),"seated empty pallet and payment pass disk validation")
	print("FORKLIFT_TERMINAL_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
