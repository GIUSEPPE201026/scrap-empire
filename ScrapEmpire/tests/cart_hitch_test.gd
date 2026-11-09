extends "res://tests/crafting_test.gd"
const HITCH=preload("res://scripts/gameplay/cart_hitch.gd")

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/hitch_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player=get_tree().get_first_node_in_group("players")
	var sector=get_tree().get_first_node_in_group("sector")
	GameState.vehicle_level=2
	GameState.yard_level=2
	GameState.team_credits=10000
	check(preload("res://scripts/economy/extra_mobility.gd").purchase("dirtbike"),"motorcycle owned before hitch use")
	sector.spawn_owned_vehicles()
	GameState.crafting.data().stock.handcart=1
	check(GameState.crafting.deploy("handcart",Vector3(43,0.08,50.65),0),"persistent cart deployed on clear ground")
	var id: String=GameState.crafting.data().objects.keys()[0]
	var cart=player._craft_object(id)
	var buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="buggy")[0]
	buggy.position=Vector3(43,0.08,47)
	GameState.crafting.data().objects[id].cargo={"metal":10}
	await look(player,Vector3(44.3,0.08,49.4),HITCH.point(buggy))
	var focus: Dictionary=preload("res://scripts/gameplay/interaction_focus.gd").resolve(player)
	check(focus.kind=="hitch" and not focus.detach,"aiming at rear hitch offers physical coupling")
	player._activate_interaction(focus)
	check(cart.tow_vehicle==buggy and player._towed_cart==cart and GameState.crafting.data().objects[id].hitch=="buggy","E couples loaded cart and checkpoints actual link")
	player._open_inventory()
	await frames(3)
	check(cart.tow_vehicle==buggy and player._towed_cart==cart,"opening menu does not detach physical trailer")
	player._close_pause_menu()
	await look(player,buggy.position+Vector3(1.4,0,0),buggy.to_global(Vector3(0,1.2,0.15)))
	focus=preload("res://scripts/gameplay/interaction_focus.gd").resolve(player)
	check(focus.kind=="vehicle","coupled cart does not hide seat interaction")
	player._activate_interaction(focus)
	await frames(20)
	var start: Vector3=cart.position
	hold_test_action("move_forward")
	await frames(90)
	release_test_action("move_forward")
	check(cart.position.distance_to(start)>0.5 and cart.tow_vehicle==buggy,"buggy pulls physical cart without instant detachment")
	player._vehicle_motion.parking_brake=true
	await frames(60)
	player._dismount_vehicle()
	await frames(5)
	check(not is_instance_valid(player._mounted_vehicle) and cart.tow_vehicle==buggy,"driver can get out while leaving cart hitched")
	var parked: Vector3=cart.position
	player.position+=Vector3(9,0,0)
	await frames(15)
	check(cart.position.distance_to(parked)<0.15 and cart.tow_vehicle==buggy,"walking away leaves hitched trailer with the parked vehicle")
	check(not GameState.ops.begin_expedition(true),"new expedition requires unhitching instead of relocating attached trailer")
	var directory: String=SaveService.SAVE_DIR
	var errors: bool=Engine.print_error_messages
	SaveService.SAVE_DIR="res://project.godot/"
	Engine.print_error_messages=false
	player._stop_cart()
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(cart.tow_vehicle==buggy and GameState.crafting.data().objects[id].hitch=="buggy","failed unhitch checkpoint keeps physical and saved connection")
	check(SaveService.save_checkpoint(111),"hitched cart snapshot validates")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(40)
	player=get_tree().get_first_node_in_group("players")
	cart=player._craft_object(id)
	check(is_instance_valid(cart.tow_vehicle) and cart.tow_vehicle.vehicle_kind=="buggy" and GameState.crafting.cart_mass(id)==20,"scene reentry restores one hitch and exact cargo")
	player._stop_cart()
	check(cart.tow_vehicle==null and not GameState.crafting.data().objects[id].has("hitch"),"explicit unhitch removes saved coupling")
	var bike=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="dirtbike")[0]
	bike.position=Vector3(43,0.08,60)
	GameState.crafting.move_object(id,Vector3(43,0.08,62.65),0)
	await frames(3)
	await look(player,Vector3(44,0.08,61.4),HITCH.point(bike))
	check(HITCH.couple(player,cart,bike),"motorcycle couples 20 kg trailer at its own rear hitch")
	GameState.player_inventories[1].plastic=1
	check(not GameState.crafting.load_cart(id) and GameState.crafting.cart_mass(id)==20,"motorcycle hitch blocks overload before taking bag materials")
	player.position=bike.position+Vector3(1.2,0,0)
	check(player._mount_vehicle(bike) and player._towed_cart==cart,"motorcycle boarding preserves physical trailer")
	await frames(25)
	start=cart.position
	hold_test_action("move_forward")
	await frames(80)
	release_test_action("move_forward")
	check(cart.position.distance_to(start)>0.4 and cart.tow_vehicle==bike,"motorcycle moves trailer with load penalty")
	player._vehicle_motion.parking_brake=true
	await frames(60)
	await snapshot_prop(player,cart,"cart_motorcycle_hitch")
	var invalid: Dictionary=GameState.serialize().duplicate(true)
	invalid.operations.crafting.objects[id].cargo.metal=11
	check(not SaveService._validate_save_schema(invalid),"saved overloaded motorcycle trailer is rejected")
	invalid=GameState.serialize().duplicate(true)
	invalid.local_expedition.travel.trailer.id="missing_cart"
	check(not SaveService._validate_save_schema(invalid),"trailer snapshot cannot refer to missing equipment")
	check(GameState.crafting.cart_mass(id)==20 and GameState.player_inventories[1].plastic==1,"hitch use conserves stock and bag materials")
	var command=InputEventKey.new()
	command.physical_keycode=KEY_H
	command.keycode=KEY_H
	command.pressed=true
	inject_input(command)
	await frames(3)
	command=command.duplicate()
	command.pressed=false
	inject_input(command)
	check(cart.tow_vehicle==null and not GameState.crafting.data().objects[id].has("hitch"),"H while parked unhitches motorcycle through normal input")
	print("CART_HITCH_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
