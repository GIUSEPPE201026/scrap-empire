extends "res://tests/crafting_test.gd"

func hold_collect(count: int) -> void:
	# Keep the intended held state stable if Windows changes test-window focus.
	for index in count:
		hold_test_action("collect")
		await get_tree().physics_frame

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/disassembly_feedback_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	# This fixture tests a stationary ray/hold, not locomotion. Native desktop
	# keys must not move/jump the actor while the renderer is being captured.
	for action in ["move_forward","move_back","move_left","move_right","jump","sprint"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var car = get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.entity_id=="assembly_0")[0]
	GameState.team_upgrade_levels.tool=2
	player._recover_intact=true
	car.select_component(0)
	var step: Dictionary = car.get_step()
	var anchor = Vector3(step.anchor[0],step.anchor[1],step.anchor[2])
	await look(player,car.global_position+Vector3(0,0.08,-3),car.to_global(anchor))
	player.set_process_unhandled_input(false)
	check(player._target_scrap==car and car.selected_component==0,"actual ray selects front panel for disassembly feedback")
	var rest: Transform3D = car.parts[0].transform
	player._equip_tool(0)
	await hold_collect(25)
	release_test_action("collect")
	check(car.parts[0].transform.is_equal_approx(rest) and not car.is_processing(),"wrong tool cannot shake or loosen component")
	player._equip_tool(int(step.tool))
	await hold_collect(roundi(car.collection_seconds()*60.0*0.4))
	check(player._collecting and car.is_processing() and car._work_index==0,"held valid tool drives animation only on selected component")
	check(car.parts[0].position.distance_to(rest.origin)>0.005 and car.parts[0].visible and GameState.ops.completed_components(car.entity_id).is_empty(),"part loosens visually before economic claim or removal")
	check(car.parts[1].transform.is_equal_approx(Transform3D.IDENTITY),"other assembly components remain in place during work")
	var bounds: Rect2 = get_viewport().get_visible_rect()
	check(bounds.has_point(player.camera.unproject_position(player._interact_prompt.global_position)),"actual component popup stays inside view rather than above car offscreen")
	if DisplayServer.get_name()!="headless":
		for direction in [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT]:
			var anchor_test: Vector3 = player.camera.global_position-player.camera.global_basis.z*2+player.camera.global_basis*direction*8
			var fitted: Vector3 = player._fit_world_prompt(anchor_test)
			var half: Vector2 = player._prompt_backing.mesh.size*player._interact_prompt.scale.x*0.5
			var fits: bool = true
			for x in [-1,1]:
				for y in [-1,1]:
					var corner: Vector2 = player.camera.unproject_position(fitted+player.camera.global_basis.x*half.x*x+player.camera.global_basis.y*half.y*y)
					fits=fits and corner.x>15 and corner.y>15 and corner.x<bounds.end.x-15 and corner.y<bounds.end.y-15
			check(fits,"whole 3D popup remains inset near viewport edge: "+str(direction))
		player._fit_world_prompt(player.camera.global_position-player.camera.global_basis.z*0.25)
		check(player._interact_prompt.scale.x<1 and player._interact_prompt.scale.x>0,"very close world popup shrinks instead of exceeding viewport")
		player._update_hint()
	await capture("disassembly_work_in_progress")
	release_test_action("collect")
	await frames(3)
	check(car.parts[0].transform.is_equal_approx(rest) and not car.is_processing() and GameState.operations.held.is_empty(),"release restores exact pose without partially awarding component")
	await hold_collect(30)
	player._open_pause_menu()
	var paused_pose: Transform3D = car.parts[0].transform
	await frames(20)
	check(car.parts[0].transform.is_equal_approx(paused_pose) and GameState.ops.completed_components(car.entity_id).is_empty(),"pause stops disassembly visuals and economic progress")
	release_test_action("collect")
	player._close_pause_menu()
	await frames(3)
	check(car.parts[0].transform.is_equal_approx(rest),"resuming cancelled work leaves no displaced visual")
	var directory: String = SaveService.SAVE_DIR
	var output: bool = Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	await hold_collect(ceili(car.collection_seconds()*60.0)+8)
	release_test_action("collect")
	await frames(3)
	Engine.print_error_messages=output
	SaveService.SAVE_DIR=directory
	check(car.parts[0].visible and car.parts[0].transform.is_equal_approx(rest) and GameState.operations.held.is_empty(),"failed checkpoint restores visual and never detaches component")
	check(get_tree().get_nodes_in_group("salvage_effects").is_empty(),"failed disassembly does not create a false detached part")
	await hold_collect(ceili(car.collection_seconds()*60.0)+3)
	release_test_action("collect")
	await frames(2)
	check(not car.parts[0].visible and GameState.operations.held.get("kind","")==step.part and 0 in GameState.ops.completed_components(car.entity_id),"successful hold awards intact part once before hiding original")
	check(not car.is_processing(),"finished assembly stops work processing")
	if DisplayServer.get_name()!="headless":
		check(get_tree().get_nodes_in_group("salvage_effects").size()==1,"successful claim emits one detached visual")
	await frames(30)
	check(get_tree().get_nodes_in_group("salvage_effects").is_empty(),"detached visual frees itself after effect")
	check(GameState.ops.store_held() and SaveService.save_checkpoint(93) and SaveService.load_save(93),"visual feedback preserves normal component storage and save roundtrip")
	print("DISASSEMBLY_FEEDBACK_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
