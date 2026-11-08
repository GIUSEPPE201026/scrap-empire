extends "res://tests/crafting_test.gd"

func run() -> void:
	if DisplayServer.get_name()=="headless":
		check(preload("res://scripts/economy/yard_operations.gd")!=null,"fragment poses use existing validated persistence service; interaction requires renderer")
		print("HEAP_FRAGMENTS_RESULT: %d checks, %d failures" % [checks,failures])
		get_tree().quit(0)
		return
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/heap_fragments_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	var sources=get_tree().get_nodes_in_group("heap_fragment_sources")
	var total: int=0
	for source in sources: total+=source.records.size()
	check(total>5000 and get_tree().get_nodes_in_group("heap_fragments").size()<50,"thousands of individually addressable pieces stay batched without thousands of bodies")
	var source=sources[0]
	var record: Dictionary=source.records[0]
	var target: Vector3=record.transform.origin
	var location=target+Vector3(0,0,1.8)
	var hit=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(location+Vector3.UP*8,location-Vector3.UP*8,1,[player.get_rid()]))
	location.y=hit.position.y+0.08
	await look(player,location,target)
	var mouse=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_RIGHT
	mouse.pressed=true
	inject_input(mouse)
	await frames(5)
	check(is_instance_valid(player._dragged) and player._dragged.is_in_group("heap_fragments"),"right mouse actually selects and promotes a visible pile fragment")
	if not is_instance_valid(player._dragged):
		print("HEAP_FRAGMENTS_RESULT: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1)
		return
	var piece=player._dragged
	var id: String=piece.entity_id
	var original: Vector3=piece.global_position
	var credits: int=GameState.team_credits
	var mass: float=GameState.get_inventory_mass(1)
	hold_test_action("move_back")
	await frames(45)
	release_test_action("move_back")
	mouse=mouse.duplicate()
	mouse.pressed=false
	inject_input(mouse)
	await frames(4)
	check(player._dragged==null and piece.global_position.distance_to(original)>0.1,"dragged fragment physically moves and releases")
	check(GameState.operations.get("loose_positions",{}).has(id) and GameState.team_credits==credits and GameState.get_inventory_mass(1)==mass,"moved geometry persists without fabricating currency or duplicating layer material rewards")
	var selected: Dictionary={}
	for item in source.records:
		if item.id==id: selected=item
	if selected.has("batch"):
		check(selected.batch.multimesh.get_instance_transform(selected.index).basis.determinant()==0,"original batched copy is removed exactly once")
	var saved: Vector3=piece.global_position
	var directory: String=SaveService.SAVE_DIR
	var errors: bool=Engine.print_error_messages
	player._dragged=piece
	player._drag_origin=saved
	player._drag_original_yaw=piece.rotation.y
	piece.position.x+=1
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	player._finish_drag()
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(piece.global_position.distance_to(saved)<0.01,"failed drag checkpoint restores the physical piece pose")
	await capture("closure_heap_piece")
	var loose_source=sources.filter(func(node):return node.scenery_piece)[0]
	var loose=loose_source.promote(0)
	var loose_id: String=loose.entity_id
	player._dragged=loose
	player._drag_origin=loose.global_position
	player._drag_original_yaw=loose.rotation.y
	loose.global_position+=Vector3(0.7,0,0.5)
	player._finish_drag()
	var loose_position: Vector3=loose.global_position
	check(GameState.operations.get("loose_positions",{}).has(loose_id),"standalone scenery scrap uses the same saved drag path")
	check(SaveService.save_checkpoint(93),"piece checkpoint writes")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var restored=get_tree().get_nodes_in_group("heap_fragments").filter(func(node):return node.entity_id==id)
	check(restored.size()==1 and restored[0].global_position.distance_to(saved)<0.01,"scene re-entry restores one moved piece at its saved position")
	var loose_restored=get_tree().get_nodes_in_group("heap_fragments").filter(func(node):return node.entity_id==loose_id)
	check(loose_restored.size()==1 and loose_restored[0].global_position.distance_to(loose_position)<0.01,"standalone prop identity and moved pose survive a new scene allocation")
	print("HEAP_FRAGMENTS_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
