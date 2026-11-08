extends "res://tests/single_player_cycle.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/layers_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var plastic = get_tree().get_nodes_in_group("scrap").filter(func(item):return item.scrap_type==1)[0]
	var engine = get_tree().get_nodes_in_group("bulk_parts").filter(func(item):return item.kind=="engine")[0]
	var light_distance: float = await pull_trial(player,plastic)
	plastic.position = Vector3(70,0,20)
	var heavy_distance: float = await pull_trial(player,engine)
	check(light_distance>heavy_distance*1.3,"plastic moves farther than heavy engine under identical pull input")
	check(absf(engine.rotation.y)>0.05,"ground pull turns object progressively instead of snapping its yaw")
	var engine_id: String = engine.part_id
	var saved_yaw: float = engine.rotation.y
	check(is_equal_approx(float(GameState.operations.loose_rotations[engine_id]),saved_yaw),"drag release checkpoints orientation")
	var before_drag: Dictionary = GameState.operations.duplicate(true)
	var original_position: Vector3 = engine.position
	player._dragged = engine
	player._drag_origin = engine.position
	player._drag_original_yaw = engine.rotation.y
	engine.position.x += 1
	engine.rotation.y += 0.1
	var drag_directory: String = SaveService.SAVE_DIR
	var drag_output: bool = Engine.print_error_messages
	SaveService.SAVE_DIR = "res://project.godot/"
	Engine.print_error_messages = false
	player._finish_drag()
	Engine.print_error_messages = drag_output
	SaveService.SAVE_DIR = drag_directory
	check(engine.position==original_position and is_equal_approx(engine.rotation.y,saved_yaw) and GameState.operations==before_drag,"failed drag save restores position rotation and all logistics together")
	engine.position = Vector3(40,0.015,10)
	engine.rotation.y = 0
	await frames(3)
	await aim(player,engine)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	inject_input(press)
	await frames(3)
	check(player._dragged==engine,"collision trial acquires the repositioned engine before adding obstacle")
	var wall = StaticBody3D.new()
	var wall_shape = CollisionShape3D.new()
	wall_shape.shape = BoxShape3D.new()
	wall_shape.shape.size = Vector3(3,2,0.2)
	wall.add_child(wall_shape)
	get_tree().current_scene.add_child(wall)
	wall.position = Vector3(40,1,10.8)
	Input.action_press("move_back")
	await frames(60)
	Input.action_release("move_back")
	check(engine.position.z<10.6,"weighted drag cannot pull engine through a solid wall")
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = false
	inject_input(press)
	await frames(3)
	wall.queue_free()
	saved_yaw = engine.rotation.y
	var pile = get_tree().get_nodes_in_group("landfill_piles")[0]
	var entity: String = "searched_"+str(pile.name)
	player._equip_tool(0)
	await aim(player,pile)
	await capture("pile_layers_before")
	var initial_parts: int = GameState.operations.field.size()
	Input.action_press("collect")
	await frames(260)
	Input.action_release("collect")
	check(pile.layer_count()==1 and GameState.get_inventory_mass(1)==3,"held recovery completes one layer and transfers exact material batch")
	check(GameState.operations.field.size()==initial_parts+1,"first layer reveals exactly one physical component")
	check(not GameState.ops.claim_pile(entity,"pile",0,1,0,pile.global_position).success,"old layer receipt cannot grant twice")
	await frames(3)
	check(pile.can_start_collection(),"release exposes next recoverable layer")
	await capture("pile_layers_first")
	var snapshot: Dictionary = GameState.operations.duplicate(true)
	GameState.player_inventories[1].metal = 10
	GameState.player_inventories[1].plastic = 0
	check(not GameState.ops.claim_pile(entity,"pile",1,1,0,pile.global_position).success and GameState.operations==snapshot,"full bag keeps next layer and hidden component untouched")
	GameState.player_inventories[1].metal = 0
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR = "res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var failed: Dictionary = GameState.ops.claim_pile(entity,"pile",1,1,0,pile.global_position)
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(not failed.success and GameState.get_inventory_mass(1)==0 and GameState.operations==snapshot,"failed layer checkpoint rolls back materials component and layer receipt")
	for layer in [1,2]:
		var point: Vector3 = pile.global_position+Vector3(layer,1.3,0)
		var result: Dictionary = GameState.ops.claim_pile(entity,"pile",layer,1,0,point)
		check(result.success,"subsequent layer commits: "+str(layer))
		player._notify(result.message)
	check(pile.layer_count()==3 and not pile.can_start_collection() and GameState.get_inventory_mass(1)==6,"last two layers conserve their exact materials and finish the pile")
	check(GameState.operations.field.size()==initial_parts+3,"three layers issue exactly three distinct components")
	check(not GameState.ops.claim_pile(entity,"pile",3,1,0,pile.global_position).success,"exhausted pile cannot generate a fourth layer")
	await capture("pile_layers_complete")
	if DisplayServer.get_name()!="headless":
		var batch: MultiMeshInstance3D
		for child in pile.get_children():
			if child is MultiMeshInstance3D:
				batch = child
				break
		check(batch!=null and batch.multimesh.visible_instance_count<batch.multimesh.instance_count/2,"surface debris is visibly reduced after excavation")
	check(GameState.ops.store_bag(1) and SaveService.save_checkpoint(98),"recovered material deposits before changing scene")
	player._do_quit_to_menu()
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	pile = get_tree().get_nodes_in_group("landfill_piles")[0]
	var restored_engine = get_tree().get_nodes_in_group("bulk_parts").filter(func(item):return item.part_id==engine_id)[0]
	check(pile.layer_count()==3 and GameState.operations.field.size()==initial_parts+3,"menu reentry preserves recovered layers and components without duplication")
	check(absf(wrapf(restored_engine.rotation.y-saved_yaw,-PI,PI))<0.001,"scene reentry restores dragged component rotation")
	var malformed: Dictionary = GameState.serialize().duplicate(true)
	malformed.operations.pile_layers[entity] = 4
	check(not SaveService._validate_save_schema(malformed),"corrupt layer counts rejected")
	malformed = GameState.serialize().duplicate(true)
	malformed.operations.loose_rotations[engine_id] = INF
	check(not SaveService._validate_save_schema(malformed),"corrupt rotations rejected")
	print("RECOVERY_LAYERS_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func pull_trial(player: Node3D, item: Node3D) -> float:
	item.position = Vector3(40,0.12,10)
	item.rotation.y = 0
	await aim(player,item)
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	inject_input(mouse)
	await frames(3)
	check(player._dragged==item,"aimed object acquires physical pull: "+str(item.name))
	var start: Vector3 = item.position
	Input.action_press("move_back")
	await frames(60)
	Input.action_release("move_back")
	await capture("weighted_drag")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = false
	inject_input(mouse)
	await frames(3)
	return item.position.distance_to(start)
