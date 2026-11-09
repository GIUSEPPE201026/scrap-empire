extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/pallet_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var service=GameState.crafting
	GameState.team_deposit_counts.metal=4
	GameState.team_deposit_counts.plastic=2
	GameState.press_owned=true
	GameState.press_bales=6
	check(service.craft("bale_pallet",int(GameState.operations.serial)),"pallet crafts from warehouse materials")
	check(GameState.team_deposit_counts.metal==2 and GameState.team_deposit_counts.plastic==1,"pallet consumes exact recipe once")
	check(service.deploy("bale_pallet",Vector3(0,0.08,17),0),"pallet deploys through persistent construction service")
	var id: String=service.data().objects.keys()[0]
	check(service.transfer_bales(id,true) and GameState.press_bales==2 and service.data().objects[id].bales==4,"loading reserves four bales without creating product")
	check(not service.transfer_bales(id,true) and not service.pack(id),"full pallet rejects another load and cannot be packed")
	var directory: String=SaveService.SAVE_DIR
	SaveService.SAVE_DIR="res://project.godot/"
	var errors: bool=Engine.print_error_messages
	Engine.print_error_messages=false
	var result: bool=service.transfer_bales(id,false)
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(not result and GameState.press_bales==2 and service.data().objects[id].bales==4,"failed checkpoint rolls back both warehouse and pallet")
	check(SaveService.save_checkpoint(98) and SaveService.load_save(98) and service.data().objects[id].bales==4,"reserved bales survive disk roundtrip")
	var invalid: Dictionary=GameState.serialize().duplicate(true)
	invalid.operations.crafting.objects[id].bales=5
	check(not SaveService._validate_save_schema(invalid),"overloaded saved pallet rejected")
	invalid=GameState.serialize().duplicate(true)
	invalid.press.owned=false
	invalid.press.bales=0
	check(not SaveService._validate_save_schema(invalid),"saved pallet cannot invent bales without a press")
	var player=get_tree().get_first_node_in_group("players")
	var object=player._craft_object(id)
	check(is_instance_valid(object),"pallet has a real interactive world object")
	await snapshot_prop(player,object,"industrial_pallet_loaded")
	await look(player,object.global_position+Vector3(1.8,0.08,-1),object.global_position+Vector3.UP*0.4)
	preload("res://scripts/ui/crafting_panel.gd").object_menu(player,object)
	await frames(3)
	check(player._pause_menu.find_children("*","Button",true,false).any(func(button):return str(button.get_meta("action_label",""))=="Riponi" and button.disabled),"loaded pallet menu disables packing")
	await capture("industrial_pallet_menu")
	await click(player,"Restituisci al deposito")
	check(GameState.press_bales==6 and int(service.data().objects[id].get("bales",0))==0,"world menu unload restores the same six total bales")
	check(not service.transfer_bales(id,false) and GameState.press_bales==6,"repeated unload cannot duplicate bales")
	check(service.transfer_bales(id,true),"pallet can be prepared for physical dispatch")
	var credits: int=GameState.team_credits
	var ticket: int=int(GameState.operations.serial)
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed_ship: bool=service.ship_pallet(id,ticket)
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(not failed_ship and GameState.team_credits==credits and service.data().objects[id].bales==4,"failed dispatch checkpoint rolls back cargo and payment")
	GameState.yard_level=2
	get_tree().get_first_node_in_group("sector").apply_land_expansions()
	var dispatch=get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("operation","")=="dispatch")[0]
	check(service.move_object(id,dispatch.global_position+Vector3(2,0.08,0),0),"physical pallet moved to dispatch fixture")
	await frames(3)
	object=player._craft_object(id)
	await look(player,dispatch.global_position+Vector3(2,0.08,2),object.global_position+Vector3.UP*0.4)
	preload("res://scripts/ui/crafting_panel.gd").object_menu(player,object)
	await capture("industrial_pallet_dispatch")
	await click(player,"Spedisci · +%d Bulloni" % (4*GameState.get_bale_value()))
	check(GameState.team_credits==credits+4*GameState.get_bale_value() and service.data().objects[id].bales==0,"dispatch menu consumes four loaded bales and credits existing unit price")
	check(not service.ship_pallet(id,ticket) and GameState.press_bales==2,"replayed shipping cannot credit twice or consume warehouse bales")
	check(service.pack(id),"empty pallet can be packed")
	print("BALE_PALLET_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
