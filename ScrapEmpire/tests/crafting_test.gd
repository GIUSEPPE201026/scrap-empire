extends "res://tests/single_player_cycle.gd"

func confirm_placement(_player: Node) -> void:
	var event=InputEventAction.new()
	event.action="interact"
	event.pressed=true
	inject_input(event)
	await frames(2)
	event=event.duplicate()
	event.pressed=false
	inject_input(event)
	await frames(2)

func look(player: Node3D, location: Vector3, target: Vector3) -> void:
	player.position = location
	player.velocity = Vector3.ZERO
	player.look_rotation = Vector2(0,0)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(target)
	player.look_rotation = Vector2(player.camera.rotation.x,player.camera.rotation.y)
	player.camera.rotation.y = 0
	await frames(4)

func click(player: Node, prefix: String) -> void:
	await frames(4)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
	for button in player._pause_menu.find_children("*","Button",true,false):
		if (str(button.get_meta("action_label",button.text)).to_upper().begins_with(prefix.to_upper()) or button.tooltip_text.to_upper().begins_with(prefix.to_upper())) and not button.disabled:
			var ancestor: Node = button.get_parent()
			while ancestor!=null and not ancestor is Window:
				if ancestor is ScrollContainer:
					ancestor.ensure_control_visible(button)
				ancestor.queue_sort()
				ancestor = ancestor.get_parent()
			await frames(3)
			if DisplayServer.get_name()=="headless":
				button.pressed.emit()
			else:
				var event = InputEventMouseButton.new()
				event.position = button.get_global_rect().get_center()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = true
				var viewport: Viewport = button.get_viewport()
				var motion = InputEventMouseMotion.new()
				motion.position = event.position
				motion.global_position = event.position
				viewport.push_input(motion)
				await frames(1)
				await RenderingServer.frame_post_draw
				event.global_position = event.position
				event.button_mask = MOUSE_BUTTON_MASK_LEFT
				viewport.push_input(event)
				await frames(1)
				await RenderingServer.frame_post_draw
				event = event.duplicate()
				event.pressed = false
				event.button_mask = 0
				viewport.push_input(event)
			await frames(3)
			return
	check(false,"enabled button found: "+prefix)

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/crafting_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var craft = GameState.crafting
	check(not craft.can_craft("repair_kit") and not craft.craft("unknown",0),"crafting rejects locked and unknown recipes")
	GameState.team_upgrade_levels.tool = 1
	check(not craft.can_craft("repair_kit"),"recipe cannot use missing warehouse stock")
	GameState.player_inventories[1].metal = 2
	GameState.player_inventories[1].plastic = 1
	GameState.player_inventories[1].electronics = 1
	check(GameState.ops.store_bag(1),"bag materials deposited for actual recipe")
	await look(player,Vector3(4,0.1,24.2),Vector3(4,1.3,26.4))
	check(player._near_ops_service()=="craft","garage bench is reachable with clear line of sight")
	var interact = InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	player._unhandled_input(interact)
	await frames(3)
	check(is_instance_valid(player._pause_menu) and get_tree().paused,"E opens garage bench and pauses world")
	player._open_crafting("repair_kit")
	await capture("crafting_kit_recipe")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=800 and player._pause_menu.position.y>=0,"crafting recipe panel fits rendered window")
	var ticket: int = GameState.operations.serial
	await click(player,"COSTRUISCI")
	check(int(craft.data().stock.get("repair_kit",0))==1 and GameState.team_deposit_counts.metal==0 and GameState.team_deposit_counts.electronics==0,"UI crafting consumes exact warehouse ingredients")
	check(not craft.craft("repair_kit",ticket),"replayed craft ticket cannot consume twice")
	player._close_pause_menu()
	var wheel: Dictionary = GameState.operations.field.values().filter(func(item):return item.kind=="wheel")[0]
	check(GameState.ops.pickup_part(wheel.id) and GameState.ops.store_held(),"actual field wheel transferred into component warehouse")
	player._open_crafting("repair_kit")
	await click(player,"RIPARA")
	check(int(craft.data().stock.repair_kit)==0 and GameState.ops.usable_parts("wheel")==1,"crafted kit repairs real stored wheel without advanced workbench")
	check(not craft.repair(wheel.id),"already repaired component cannot consume another kit")
	player._close_pause_menu()
	GameState.team_deposit_counts.metal = 20
	GameState.team_deposit_counts.plastic = 10
	GameState.team_deposit_counts.electronics = 5
	check(not craft.can_craft("handcart"),"cart requires two working recovered wheels")
	# A second real wheel from a dismantled car, issued through existing recovery service.
	var car = get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.definition_id=="car")[0]
	var issued: Dictionary = GameState.ops.claim_component(car.entity_id,"car",1,1,1,true)
	check(issued.get("success",false),"second wheel recovered through existing component transaction")
	if issued.get("success",false):
		check(GameState.ops.store_held(),"second wheel stored intact")
	check(craft.can_craft("handcart"),"cart unlocked with free materials and two usable wheels")
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR = "res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var failed: bool = craft.craft("handcart",int(GameState.operations.serial))
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(not failed and craft.count("handcart")==0 and GameState.ops.usable_parts("wheel")==2 and GameState.team_deposit_counts.metal==20,"failed craft checkpoint restores ingredients and both components")
	check(craft.craft("handcart",int(GameState.operations.serial)) and craft.count("handcart")==1 and GameState.ops.usable_parts("wheel")==0 and GameState.team_deposit_counts.metal==14,"cart consumes six metals three plastics and two wheels")
	check(not craft.can_craft("handcart"),"unique cart limit prevents redundant construction")
	await look(player,Vector3(12,0.1,-18),Vector3(12,0,-20))
	var ground: Dictionary = player._craft_ground("handcart")
	check(not ground.is_empty(),"placement finds unobstructed flat ground within three metres")
	var blocked = StaticBody3D.new()
	get_tree().current_scene.add_child(blocked)
	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(1,2,1)
	blocked.add_child(collision)
	blocked.position = ground.point+Vector3.UP
	await frames(3)
	check(player._craft_ground("handcart").is_empty() and craft.data().stock.handcart==1,"blocked placement preserves equipment in stock")
	blocked.queue_free()
	await frames(3)
	player._open_crafted_gear()
	await click(player,"POSIZIONA CARRELLO")
	await confirm_placement(player)
	check(craft.data().objects.size()==1 and craft.data().stock.handcart==0,"inventory placement creates persistent cart")
	await frames(3)
	var cart = get_tree().get_nodes_in_group("crafted_objects")[0]
	var id: String = cart.craft_id
	GameState.player_inventories[1].metal = 10
	SaveService.SAVE_DIR = "res://project.godot/"
	Engine.print_error_messages = false
	var failed_load: bool = craft.load_cart(id)
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(not failed_load and GameState.player_inventories[1].metal==10 and craft.cart_mass(id)==0,"failed cart loading restores both bag and cart contents")
	check(craft.load_cart(id) and craft.cart_mass(id)==20 and GameState.get_inventory_mass(1)==0,"cart load conserves all bag material and exact weight")
	GameState.player_inventories[1].metal = 21
	check(not craft.load_cart(id) and GameState.player_inventories[1].metal==21 and craft.cart_mass(id)==20,"overweight transfer rejected without partial loss")
	GameState.player_inventories[1].metal = 0
	check(not craft.pack(id),"loaded cart cannot disappear into equipment inventory")
	check(SaveService.save_checkpoint(95) and SaveService.load_save(95) and craft.cart_mass(id)==20,"loaded cart survives save and load with exact materials")
	var overloaded: Dictionary = GameState.serialize().duplicate(true)
	overloaded.operations.crafting.objects[id].cargo.metal = 31
	check(not SaveService._validate_save_schema(overloaded),"overweight cart payload rejected on load")
	await look(player,cart.position+Vector3(0,0.05,2.4),cart.position+Vector3.UP*0.55)
	check(player._near_crafted()==cart,"cart interaction targets actual cart body")
	preload("res://scripts/ui/crafting_panel.gd").object_menu(player,cart)
	await capture("crafting_cart_menu")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=800 and player._pause_menu.position.y>=0,"cart manifest fits rendered window")
	await click(player,"TRAINA")
	var start: Vector3 = cart.position
	if player._towed_cart!=cart:
		print("CART_TOW_DIAG near=",player._near_crafted()," distance=",player.position.distance_to(cart.position)," held=",GameState.operations.held," mounted=",player._mounted_vehicle," feedback=",player._feedback.text," paused=",player._is_paused)
	check(player._towed_cart==cart,"cart menu attaches physical towing")
	Input.action_press("move_back")
	await frames(60)
	Input.action_release("move_back")
	check(cart.position.distance_to(start)>0.5,"walking moves the loaded cart through real collision motion")
	await snapshot_prop(player,cart,"crafted_cart_loaded")
	GameState.yard_level=1
	GameState.vehicle_level=2
	var prior_orders: Array=GameState.completed_orders.duplicate()
	GameState.completed_orders=[GameState.order_defs[0].id]
	GameState.team_credits=1000
	check(GameState.purchase_module("tow_package") and GameState.team_credits==450,"reinforced tow upgrade purchases at configured price")
	GameState.completed_orders.assign(prior_orders)
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.level==2)[0]
	buggy.position=cart.position+Vector3(0,0,-3.4)
	player.global_position=buggy.global_position+Vector3(1.3,0.1,0)
	await look(player,player.global_position,buggy.global_position+Vector3(0,1.2,0.15))
	var mount_focus: Dictionary=preload("res://scripts/gameplay/interaction_focus.gd").resolve(player)
	check(mount_focus.kind=="vehicle","looking at buggy seat while towing offers boarding rather than uncoupling")
	player._activate_interaction(mount_focus)
	check(player._mounted_vehicle==buggy and player._towed_cart==cart,"buggy mount retains attached loaded cart")
	var before_tow: Vector3=cart.position
	hold_test_action("move_forward")
	await frames(60)
	release_test_action("move_forward")
	check(cart.position.distance_to(before_tow)>0.5 and player._towed_cart==cart,"buggy physically tows cart without losing attachment")
	player._vehicle_motion.parking_brake=true
	await frames(40)
	player._vehicle_motion.parking_brake=false
	hold_test_action("move_back")
	await frames(18)
	release_test_action("move_back")
	check(is_instance_valid(player._towed_cart) and absf(player._vehicle_speed)<4.0,"loaded trailer reverses slowly without teleport or detachment")
	check(craft.cart_mass(id)==20,"vehicle towing and reverse preserve exact cargo mass")
	player._vehicle_motion.parking_brake=true
	await frames(40)
	player._dismount_vehicle()
	check(cart.tow_vehicle==buggy and player._towed_cart==cart,"dismount keeps the physical vehicle hitch")
	player._stop_cart()
	buggy.global_position=Vector3(40,0.08,30)
	player._towed_cart=cart
	cart.towing=player
	cart.add_collision_exception_with(player)
	player._open_pause_menu()
	check(player._towed_cart==null and Vector3(craft.data().objects[id].position[0],craft.data().objects[id].position[1],craft.data().objects[id].position[2]).distance_to(cart.position)<0.1,"opening menu releases cart and checkpoints position")
	player._close_pause_menu()
	var depot = get_tree().get_first_node_in_group("sector").get_node("DepositZone")
	await look(player,cart.position+Vector3(0,0.05,2.4),cart.position+Vector3.UP*0.55)
	player._craft_action("unload",id,0)
	check(craft.cart_mass(id)==20,"remote cart unload is rejected by actual interaction")
	check(craft.move_object(id,depot.global_position+Vector3(1.8,0.05,0),0),"cart moved to depot for interaction fixture")
	await frames(3)
	await look(player,depot.global_position+Vector3(0,0.1,0),cart.position+Vector3.UP*0.55)
	preload("res://scripts/ui/crafting_panel.gd").object_menu(player,cart)
	await click(player,"SCARICA NEL DEPOSITO")
	check(craft.cart_mass(id)==0 and GameState.team_deposit_counts.metal==24,"cart UI unload transfers materials into depot without sale")
	check(not craft.unload_cart(id),"empty cart cannot duplicate deposited cargo")
	check(craft.pack(id) and craft.count("handcart")==1 and craft.data().objects.is_empty(),"empty cart repacks without loss")
	check(not craft.can_craft("work_lamp"),"field lamp waits for first campaign order")
	GameState.completed_orders = [GameState.order_defs[0].id]
	check(craft.craft("work_lamp",int(GameState.operations.serial)),"field lamp crafted after campaign prerequisite")
	await look(player,Vector3(12,0.1,-18),Vector3(12,0,-20))
	player._open_crafted_gear()
	await click(player,"POSIZIONA FARO")
	await confirm_placement(player)
	await frames(3)
	var lamps = get_tree().get_nodes_in_group("crafted_objects").filter(func(node):return node.kind=="work_lamp")
	check(lamps.size()==1 and lamps[0].find_children("*","OmniLight3D",true,false).size()==1,"crafted lamp creates an actual world light")
	check(lamps.size()==1 and lamps[0].find_children("*","OmniLight3D",true,false)[0].omni_range==20,"field lamp applies configured twenty metre range")
	await snapshot_prop(player,lamps[0],"crafting_lamp_world")
	player._open_inventory()
	await capture("crafting_inventory_access")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=800 and player._pause_menu.position.y>=0,"inventory construction access fits rendered window")
	player._close_pause_menu()
	check(SaveService.save_checkpoint(96) and SaveService.load_save(96) and craft.count("handcart")==1 and craft.count("work_lamp")==1,"crafted equipment and placed lamp survive disk roundtrip")
	var invalid: Dictionary = GameState.serialize().duplicate(true)
	invalid.operations.crafting.stock.handcart = 2
	check(not SaveService._validate_save_schema(invalid),"over-limit crafted equipment rejected on load")
	invalid = GameState.serialize().duplicate(true)
	var lamp_id: String = craft.data().objects.keys()[0]
	invalid.operations.crafting.objects[lamp_id].cargo.metal = 1
	check(not SaveService._validate_save_schema(invalid),"lamp cannot forge a cargo container on load")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	check(get_tree().get_nodes_in_group("crafted_objects").size()==1 and craft.count("handcart")==1,"scene reentry restores placed equipment once")
	print("CRAFTING_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func snapshot_prop(player: Node3D, object: Node3D, filename: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	var camera = Camera3D.new()
	get_tree().current_scene.add_child(camera)
	camera.position = object.global_position+Vector3(3,2.4,3)
	camera.look_at(object.global_position+Vector3.UP*0.9)
	camera.make_current()
	player.get_node("HUD").hide()
	await capture(filename)
	camera.queue_free()
	player.camera.make_current()
	player.get_node("HUD").show()

