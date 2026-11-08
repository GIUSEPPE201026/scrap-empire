extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/vehicle_trade_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	GameState.yard_level = 1
	GameState.vehicle_level = 2
	sector.spawn_owned_vehicles()
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.level==2)[0]
	buggy.position = Vector3(42,0,12)
	player.position = buggy.position+Vector3(1.5,0,0)
	player.look_rotation.x = 0.6
	check(player._mount_vehicle(buggy),"buggy mounts for camera and suspension trial")
	await frames(20)
	var seat: Vector3 = buggy.visual.to_local(player.camera.global_position)
	check(seat.distance_to(Vector3(0,1.94,-0.075))<0.01 and player.camera.global_basis.z.dot(buggy.visual.global_basis.z)>0.99,"first-person eyes occupy actual seat and face forward after mounting")
	check((player.camera.cull_mask & (1<<19))==0,"first-person view hides local helmet")
	await capture("buggy_driver_pov")
	player.look_rotation.y = player._vehicle_heading+PI
	player._update_vehicle_camera()
	check(absf(wrapf(player.look_rotation.y-player._vehicle_heading,-PI,PI))<=1.751,"cockpit freelook stays within seated neck rotation")
	player.look_rotation.y = player._vehicle_heading
	var key = InputEventKey.new()
	key.keycode = KEY_V
	key.pressed = true
	var forward_keys: Array[InputEvent] = InputMap.action_get_events("move_forward")
	InputMap.action_erase_events("move_forward")
	var bound = InputEventKey.new()
	bound.keycode = KEY_V
	InputMap.action_add_event("move_forward",bound)
	player._unhandled_input(key)
	check(not player._vehicle_third_person,"camera shortcut yields to remapped gameplay key")
	InputMap.action_erase_events("move_forward")
	for binding in forward_keys:
		InputMap.action_add_event("move_forward",binding)
	player._unhandled_input(key)
	await frames(3)
	check(player._vehicle_third_person and player.camera.position.distance_to(Vector3(0,1.35,0))>4,"V enables real third-person chase camera")
	check((player.camera.cull_mask & (1<<19))!=0,"third-person camera shows driver helmet")
	await capture("buggy_third_person")
	var focus: Vector3 = buggy.visual.global_position+Vector3.UP*1.35
	var free_distance: float = player.camera.global_position.distance_to(focus)
	var wall = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(8,5,0.3)
	wall.add_child(collision)
	sector.add_child(wall)
	wall.position = focus+Vector3(0,1,3)
	await frames(6)
	check(player.camera.global_position.distance_to(focus)<free_distance*0.75,"camera boom retracts before rear wall")
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = 0.2
	query.transform.origin = player.camera.global_position
	query.exclude = [player.get_rid(),buggy.body.get_rid()]
	check(player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"retracted third-person camera remains outside solid obstacles")
	wall.queue_free()
	await frames(6)
	check(player.camera.global_position.distance_to(focus)>free_distance*0.9,"camera returns to normal distance when obstacle clears")
	player._unhandled_input(key)
	await frames(3)
	check(not player._vehicle_third_person,"V returns to cockpit")
	var ramp = StaticBody3D.new()
	var ramp_shape = CollisionShape3D.new()
	ramp_shape.shape = BoxShape3D.new()
	ramp_shape.shape.size = Vector3(16,0.2,18)
	ramp.add_child(ramp_shape)
	sector.add_child(ramp)
	ramp.position = Vector3(45,1,15)
	ramp.rotation.x = 0.32
	if DisplayServer.get_name()!="headless":
		preload("res://scripts/gameplay/scrapyard_art.gd").new().box(ramp,Vector3(16,0.2,18),Vector3.ZERO,Color("#987653"))
	player.position = Vector3(45,2,15)
	player.velocity = Vector3.ZERO
	player._vehicle_motion.speed = 0
	player._vehicle_motion.parking_brake = true
	await frames(100)
	check(absf(buggy.visual.rotation.x)>0.18,"chassis follows substantial uphill angle")
	check(buggy.wheels.size()==4,"four suspension pivots exist in runtime and headless")
	var minimum: float = 100
	var maximum: float = -100
	var clear_fenders: bool = true
	for wheel in buggy.wheels:
		minimum = minf(minimum,wheel.position.y)
		maximum = maxf(maximum,wheel.position.y)
		clear_fenders = clear_fenders and wheel.position.y+float(wheel.get_meta("radius"))<1.06
	check(maximum-minimum<0.07,"uniform slope is not applied a second time as differential suspension travel")
	check(clear_fenders and maximum<=0.601 and minimum>=-0.001,"extended droop and bounded compression keep tyres below mudguards")
	check(buggy.visual.to_local(player.camera.global_position).distance_to(Vector3(0,1.94,-0.075))<0.01,"cockpit remains attached to driver eyes on uphill chassis")
	await snapshot_prop(player,buggy.visual,"buggy_uphill_wheel_clearance")
	player._unhandled_input(key)
	await frames(3)
	await capture("buggy_uphill_chase")
	player._dismount_vehicle()
	await frames(24)
	check(player._mounted_vehicle==null and not player._vehicle_third_person and player.camera.position.distance_to(Vector3(0,1.6,0))<0.01,"dismount restores walking camera and clears third-person mode")
	player._unhandled_input(key)
	check(not player._vehicle_third_person,"vehicle view shortcut is inactive on foot")
	ramp.queue_free()
	var craft = GameState.crafting
	GameState.team_upgrade_levels.tool = 1
	GameState.team_deposit_counts.metal = 30
	GameState.team_deposit_counts.plastic = 20
	GameState.team_deposit_counts.electronics = 10
	check(not craft.can_craft("desk_lamp") and craft.demand("marta")==0,"consumer product and buyer respect campaign prerequisite")
	GameState.completed_orders = [GameState.order_defs[0].id]
	await look(player,Vector3(4,0.1,24.2),Vector3(4,1.3,26.4))
	player._open_crafting("desk_lamp")
	await capture("customer_product_recipe")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=800 and player._pause_menu.position.y>=0,"five-recipe crafting menu fits rendered window")
	await click(player,"COSTRUISCI")
	check(int(craft.data().stock.get("desk_lamp",0))==1 and GameState.team_deposit_counts.metal==28 and GameState.team_deposit_counts.electronics==9,"sale product is actually crafted from warehouse scraps")
	player._close_pause_menu()
	for index in 3:
		check(craft.craft("desk_lamp",int(GameState.operations.serial)),"additional sale unit crafted: "+str(index))
	var marta = get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("customer","")=="marta")[0]
	await look(player,marta.position+Vector3(0,0.1,-2.2),marta.position+Vector3.UP*1.3)
	check(player._near_ops_service()=="customer" and player._ops_service_node()==marta,"aiming at actual customer selects her order")
	await snapshot_prop(player,marta,"customer_counters")
	var interaction = InputEventAction.new()
	interaction.action = "interact"
	interaction.pressed = true
	player._unhandled_input(interaction)
	await frames(3)
	await capture("customer_order")
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=800 and player._pause_menu.position.y>=0,"customer order panel fits rendered window")
	var balance: int = GameState.team_credits
	var ticket: int = GameState.operations.serial
	await click(player,"CONSEGNA 1")
	check(GameState.team_credits==balance+90 and int(craft.data().stock.desk_lamp)==3 and craft.demand("marta")==2,"customer UI consumes one finished product and pays exact price")
	check(not craft.sell_product("marta",1,ticket) and GameState.team_credits==balance+90,"replayed sale ticket cannot award twice")
	player._close_pause_menu()
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR = "res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var failed: bool = craft.sell_product("marta",1,int(GameState.operations.serial))
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(not failed and int(craft.data().stock.desk_lamp)==3 and craft.demand("marta")==2 and GameState.team_credits==balance+90,"failed sale checkpoint restores product demand and money together")
	check(craft.sell_product("marta",2,int(GameState.operations.serial)) and craft.demand("marta")==0 and GameState.team_credits==balance+270,"remaining daily demand settles exactly once")
	check(not craft.sell_product("marta",1,int(GameState.operations.serial)) and int(craft.data().stock.desk_lamp)==1,"daily order limit prevents unlimited selling")
	check(SaveService.save_checkpoint(93) and SaveService.load_save(93) and craft.demand("marta")==0 and int(craft.data().stock.desk_lamp)==1,"product stock and daily sales persist across disk reload")
	GameState.operations.world_seconds = float(GameState.operations.get("world_seconds",0))+float(GameState.logistics_def.day_seconds)
	check(craft.demand("marta")==3,"next in-game day renews customer demand")
	check(not craft.sell_product("unknown",1,int(GameState.operations.serial)) and not craft.sell_product("marta",0,int(GameState.operations.serial)),"unknown buyer and zero quantity rejected")
	check(not craft.can_craft("toolbox") and craft.demand("enzo")==0,"second consumer product has later campaign unlock")
	GameState.completed_orders.append(GameState.order_defs[1].id)
	check(craft.craft("toolbox",int(GameState.operations.serial)) and craft.sell_product("enzo",1,int(GameState.operations.serial)) and craft.demand("enzo")==1,"second product is crafted and sold to its own customer")
	var invalid: Dictionary = GameState.serialize().duplicate(true)
	invalid.operations.crafting.sales.marta.units = 4
	check(not SaveService._validate_save_schema(invalid),"excess customer sales count rejected on load")
	invalid = GameState.serialize().duplicate(true)
	invalid.operations.crafting.sales.enzo.day = craft.day()+1
	check(not SaveService._validate_save_schema(invalid),"future customer receipt day rejected on load")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	check(get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("operation")=="customer").size()==GameState.logistics_def.customers.size() and craft.demand("enzo")==1,"scene reentry restores demand without duplicating customers")
	print("VEHICLE_TRADE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
