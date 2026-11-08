extends "res://tests/fabrication_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/production_reserves_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var sector = get_tree().get_first_node_in_group("sector")
	GameState.yard_level=2
	GameState.team_upgrade_levels.tool=2
	GameState.completed_orders=GameState.order_defs.map(func(job):return job.id)
	GameState.workshop_modules.workbench=1
	GameState.press_owned=true
	GameState.press_bales=1
	sector.apply_land_expansions()
	GameState.ops.seed_field_parts()
	check(GameState.ops.accept_delivery("town_square"),"community product supply accepted before manufacturing")
	var keep: Dictionary = GameState.story.reserves()
	check(keep.materials.get("metal",0)==8 and keep.materials.get("plastic",0)==5 and keep.materials.get("electronics",0)==5 and keep.materials.get("copper",0)==1 and keep.bales==1,"surplus reserves exact ingredients for three lamps and one radio plus delivered bale")
	for material in GameState.material_defs:
		GameState.team_deposit_counts[material]=100
	var snapshot: Dictionary = GameState.team_deposit_counts.duplicate()
	var output: bool = Engine.print_error_messages
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	var failed: int = EconomyService.sell_surplus()
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(failed==0 and GameState.team_deposit_counts==snapshot and GameState.team_credits==0,"failed surplus checkpoint restores every ingredient and money")
	var value: int = GameState.story.surplus_value()
	check(EconomyService.sell_surplus()==value and GameState.team_credits==value and GameState.press_bales==1,"surplus sells only unneeded raw stock and keeps required bale")
	check(GameState.team_deposit_counts.metal==8 and GameState.team_deposit_counts.plastic==5 and GameState.team_deposit_counts.electronics==5 and GameState.team_deposit_counts.copper==1,"all product ingredients survive actual surplus sale")
	for index in 3:
		check(GameState.crafting.craft("desk_lamp",int(GameState.operations.serial)),"reserved stock manufactures required lamp "+str(index))
	keep=GameState.story.reserves()
	check(keep.materials.metal==2 and keep.materials.plastic==2 and keep.materials.electronics==2 and keep.materials.copper==1,"finished products release their ingredient reservation without double counting")
	check(not stock_component("battery").is_empty(),"radio battery recovered through real salvage and repair services")
	# Repair kit consumed some raw stock; restore the exact radio inputs as a fixture.
	for material in GameState.crafting.definitions().restored_radio.materials:
		GameState.team_deposit_counts[material]=GameState.crafting.definitions().restored_radio.materials[material]
	check(GameState.crafting.craft("restored_radio",int(GameState.operations.serial)),"radio production reserves inputs atomically")
	keep=GameState.story.reserves()
	check(keep.materials.metal==0 and keep.materials.electronics==0 and EconomyService.sell_surplus()==0,"queued products do not hold a second set of ingredients")
	var id: String = GameState.fabrication.jobs()[0].id
	check(GameState.fabrication.cancel(id),"unfinished radio can be cancelled with ingredient refund")
	keep=GameState.story.reserves()
	check(keep.materials.metal==2 and keep.materials.copper==1 and EconomyService.sell_surplus()==0,"refunded ingredients remain protected for the still active delivery")
	check(GameState.ops.cancel_delivery() and GameState.story.surplus_value()>0,"declining supply releases its raw stock reservation")
	print("PRODUCTION_RESERVES_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
