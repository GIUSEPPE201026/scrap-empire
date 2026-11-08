extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/drive_placement_fix_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	GameState.vehicle_level=2
	GameState.yard_level=1
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	for level in [2,1]:
		var vehicle=get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==level)[0]
		for angle in [0.18,0.38]:
			var ramp=StaticBody3D.new()
			var shape=CollisionShape3D.new()
			shape.shape=BoxShape3D.new()
			shape.shape.size=Vector3(30,0.5,180)
			ramp.add_child(shape)
			get_tree().current_scene.add_child(ramp)
			ramp.position=Vector3(450,55,130)
			ramp.rotation.x=angle
			vehicle.position=ramp.to_global(Vector3(0,0.25,-50))+Vector3.UP*0.08
			vehicle.rotation.y=PI
			vehicle.show()
			player.position=vehicle.position+Vector3(2,0,0)
			player.velocity=Vector3.ZERO
			check(player._mount_vehicle(vehicle),"mount actual vehicle on descending fixture %d / %.2f" % [level,angle])
			await frames(20)
			hold_test_action("move_forward")
			await frames(90)
			release_test_action("move_forward")
			var entry: float=absf(player._vehicle_speed)
			var start: Vector3=player.position
			await frames(150)
			var exit: float=absf(player._vehicle_speed)
			print("DOWNHILL level=",level," slope=",angle," entry=",entry," exit=",exit," travel=",start.distance_to(player.position)," floor=",player.is_on_floor())
			check(exit>entry+1.0 and start.distance_to(player.position)>8,"downhill coasting gains speed instead of gradually stopping %d / %.2f" % [level,angle])
			player._dismount_vehicle()
			await frames(24)
			ramp.queue_free()
			await frames(3)
	var flat=StaticBody3D.new()
	var flat_shape=CollisionShape3D.new()
	flat_shape.shape=BoxShape3D.new()
	flat_shape.shape.size=Vector3(140,0.5,140)
	flat.add_child(flat_shape)
	get_tree().current_scene.add_child(flat)
	flat.position=Vector3(450,35,-180)
	var buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
	buggy.position=flat.position+Vector3(0,0.35,35)
	buggy.rotation.y=0
	player.position=buggy.position+Vector3(2,0,0)
	check(player._mount_vehicle(buggy),"drift fixture mounts real buggy on unobstructed plane")
	await frames(20)
	hold_test_action("move_forward")
	await frames(150)
	hold_test_action("move_right")
	hold_test_action("jump")
	var slip_total: float=0
	for index in 90:
		await frames(1)
		if index>=45: slip_total+=player._vehicle_motion.drift_angle
	var average: float=slip_total/45
	print("SUSTAINED_DRIFT mean_slip=",average," speed=",player._vehicle_speed)
	check(average>0.25 and absf(player._vehicle_speed)>3,"handbrake produces sustained measurable slide rather than one transient peak")
	release_test_action("jump")
	await frames(3)
	check(player._vehicle_motion.drift_blend>0.5,"handbrake release does not instantly kill slide")
	release_test_action("move_right")
	await frames(160)
	check(player._vehicle_motion.drift_angle<0.12,"straightening the wheels recovers rolling grip")
	release_test_action("move_forward")
	player._vehicle_motion.parking_brake=true
	await frames(100)
	player._dismount_vehicle()
	await frames(24)
	GameState.crafting.data().stock.handcart=1
	await look(player,Vector3(43,0.08,62),Vector3(43,1.6,55))
	player._open_crafted_gear()
	await click(player,"POSIZIONA CARRELLO")
	check(is_instance_valid(player._placement) and not player._is_paused and GameState.crafting.data().stock.handcart==1,"horizontal view enters placement preview without consuming cart")
	await frames(3)
	check(not player._placement.ground.is_empty(),"placement preview finds reachable ground ahead without aiming at own feet")
	var key=InputEventKey.new()
	key.keycode=KEY_R
	key.pressed=true
	inject_input(key)
	await frames(2)
	check(absf(player._placement.yaw)>0.7,"placement rotation changes actual preview orientation")
	await capture("drive_fix_cart_preview")
	var cancel=InputEventMouseButton.new()
	cancel.button_index=MOUSE_BUTTON_RIGHT
	cancel.pressed=true
	inject_input(cancel)
	await frames(2)
	cancel=cancel.duplicate()
	cancel.pressed=false
	inject_input(cancel)
	check(not is_instance_valid(player._placement) and GameState.crafting.data().stock.handcart==1,"cancelling preview leaves cart in equipment")
	player._open_crafted_gear()
	await click(player,"POSIZIONA CARRELLO")
	await confirm_placement(player)
	check(GameState.crafting.data().stock.handcart==0 and get_tree().get_nodes_in_group("crafted_objects").any(func(node):return node.kind=="handcart"),"confirm action places cart exactly once")
	print("DRIVE_PLACEMENT_FIX_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
