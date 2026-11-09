extends "res://tests/crafting_test.gd"
const VAC=preload("res://scripts/gameplay/vacuum_tool.gd")
func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/vacuum_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player=get_tree().get_first_node_in_group("players")
	var item=get_tree().get_nodes_in_group("scrap").filter(func(s):return s.scrap_type==1)[0]
	item.global_position=Vector3(43,0.08,50)
	await look(player,Vector3(43,0.08,52),item.global_position+Vector3.UP*0.33)
	check(not VAC.eligible(player,item),"unowned vacuum cannot collect")
	GameState.completed_orders=[GameState.order_defs[0].id,GameState.order_defs[1].id]
	GameState.team_upgrade_levels.tool=1
	GameState.team_credits=2000
	check(GameState.purchase_module("vacuum") and GameState.team_credits==900,"vacuum purchase debits configured cost")
	check(VAC.eligible(player,item),"light plastic within cone is eligible")
	GameState.player_inventories[1].plastic=int(GameState.get_inventory_capacity(1)/GameState.material_defs.plastic.mass_kg)
	check(not VAC.recover(player,item) and not item.is_queued_for_deletion(),"full bag preserves scrap in world")
	GameState.player_inventories[1].plastic=0
	var wall=StaticBody3D.new()
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(2,3,0.2)
	wall.add_child(shape)
	get_tree().current_scene.add_child(wall)
	wall.global_position=(player.camera.global_position+item.global_position)*0.5
	await frames(3)
	check(not VAC.recover(player,item),"vacuum cannot collect through wall")
	wall.queue_free()
	await frames(3)
	player._toggle_vacuum()
	check(player._vacuum_active,"equipment toggle equips vacuum")
	var id: String=item.entity_id
	check(VAC.recover(player,item) and GameState.player_inventories[1].plastic==1 and id in GameState.sector_consumed_ids,"successful intake commits one piece before removing object")
	check(not VAC.recover(player,item),"queued collectible cannot be recovered twice")
	await frames(2)
	var second=get_tree().get_nodes_in_group("scrap").filter(func(s):return s.scrap_type==1)[0]
	second.global_position=Vector3(43,0.08,50)
	await look(player,Vector3(43,0.08,52),second.global_position+Vector3.UP*0.33)
	hold_test_action("collect")
	await frames(15)
	release_test_action("collect")
	await frames(3)
	check(GameState.player_inventories[1].plastic==1,"releasing suction before completion preserves target and inventory")
	hold_test_action("collect")
	await frames(45)
	release_test_action("collect")
	check(GameState.player_inventories[1].plastic==2,"holding actual collection action completes vacuum intake")
	await capture("vacuum_equipped")
	check(SaveService.save_checkpoint(103) and SaveService.load_save(103) and int(GameState.workshop_modules.get("vacuum",0))==1,"vacuum ownership and intake persist")
	print("VACUUM_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
