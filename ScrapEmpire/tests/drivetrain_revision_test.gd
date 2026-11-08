extends "res://tests/crafting_test.gd"

func review_driver(player: Node3D, buggy: Node3D, filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var camera=Camera3D.new()
	get_tree().current_scene.add_child(camera)
	var focus: Vector3=buggy.visual.global_position+Vector3.UP*1.1
	camera.position=focus+Vector3(4,1.6,-4)
	camera.look_at(focus)
	camera.make_current()
	await frames(8)
	await capture(filename)
	player.camera.make_current()
	camera.queue_free()

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/drivetrain_revision_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	if DisplayServer.get_name()!="headless":
		check(is_instance_valid(player._local_avatar) and player._local_avatar.visible,"walking player has the articulated worker body")
		hold_test_action("move_forward")
		await frames(12)
		release_test_action("move_forward")
		check(player._local_avatar.gait_amount>0.1,"actual walking animates worker legs")
	GameState.vehicle_level=2
	GameState.yard_level=1
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
	buggy.position=Vector3(43,0,60)
	player.position=buggy.position+Vector3(2,0,0)
	check(player._mount_vehicle(buggy),"boarding begins through actual mount action")
	if DisplayServer.get_name()!="headless": check(not player._local_avatar.visible,"boarding hides walking body without duplicating driver")
	check(player._vehicle_entry_time>0,"boarding has a camera transition instead of an instantaneous view")
	await review_driver(player,buggy,"desert_entry_animation")
	await frames(40)
	check(player._vehicle_entry_time==0 and buggy.visual.to_local(player.camera.global_position).distance_to(Vector3(0,1.94,-0.075))<0.01,"entry settles at real driver eye position")
	if DisplayServer.get_name()!="headless": check(buggy.rider.position.length()<0.01 and buggy.rider.seated>0.99,"articulated driver finishes inside seat")
	var wall=StaticBody3D.new()
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(12,4,0.5)
	wall.add_child(shape)
	get_tree().current_scene.add_child(wall)
	wall.position=Vector3(43,2,51)
	hold_test_action("move_forward")
	await frames(200)
	check(player.position.z>52 and absf(player._vehicle_speed)<0.2,"blocked buggy cannot accumulate phantom drivetrain speed")
	var at: Vector3=player.global_position
	await frames(30)
	check(player.global_position.distance_to(at)<0.03 and absf(player._vehicle_speed)<0.2,"speed remains consistent with actual displacement against obstacle")
	release_test_action("move_forward")
	wall.queue_free()
	await frames(4)
	player.position=Vector3(43,0.08,60)
	player.velocity=Vector3.ZERO
	player._vehicle_motion.speed=0
	player._vehicle_motion.heading=0
	hold_test_action("move_forward")
	await frames(125)
	hold_test_action("move_right")
	hold_test_action("jump")
	await frames(55)
	var blend: float=player._vehicle_motion.drift_blend
	var slip: float=player._vehicle_motion.drift_angle
	print("DRIFT_RELEASE blend=",blend," slip=",slip," speed=",player._vehicle_speed," position=",player.position)
	release_test_action("jump")
	await frames(3)
	check(blend>0.8 and slip>0.1 and player._vehicle_motion.drift_blend>0.75,"handbrake release preserves slide and does not instantly restore full grip")
	release_test_action("move_right")
	release_test_action("move_forward")
	await frames(140)
	check(player._vehicle_motion.drift_blend<0.01,"traction recovers progressively after release")
	player._vehicle_motion.parking_brake=true
	await frames(130)
	player.global_position=Vector3(0,0.08,65)
	await frames(30)
	player._vehicle_third_person=true
	player._update_vehicle_camera()
	await capture("desert_buggy_redesign")
	if DisplayServer.get_name()!="headless":
		var camera=Camera3D.new()
		get_tree().current_scene.add_child(camera)
		camera.position=player.global_position+Vector3(4,2.7,-5)
		camera.look_at(player.global_position+Vector3.UP*1.2)
		camera.make_current()
		await frames(4)
		await capture("desert_buggy_front")
		player.camera.make_current()
		camera.queue_free()
	player._dismount_vehicle()
	check(player._mounted_vehicle==null and player._vehicle_exit_time>0,"exit immediately restores walking body while view animates out")
	await review_driver(player,buggy,"desert_exit_animation")
	await frames(45)
	check(player._vehicle_exit_time==0 and player.camera.position.distance_to(Vector3(0,1.6,0))<0.01 and get_tree().get_nodes_in_group("players").size()==1,"exit finishes at walking eye position without a duplicate player")
	if DisplayServer.get_name()!="headless": check(not is_instance_valid(buggy._exit_ghost),"temporary exit actor is cleaned up")
	if DisplayServer.get_name()!="headless": check(player._local_avatar.visible,"walking body returns after dismount")
	player.position=Vector3(43,0.08,60)
	player.velocity=Vector3.ZERO
	await frames(8)
	player._toggle_scooter()
	hold_test_action("move_forward")
	hold_test_action("move_right")
	await frames(30)
	check(is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.level==1 and absf(player._mounted_vehicle.visual.rotation.z)<0.002,"scooter stays upright when steering on flat ground")
	if DisplayServer.get_name()!="headless":
		check(player._mounted_vehicle.rider.scooter_pose and player._mounted_vehicle.rider.visible,"scooter uses the same worker with standing handlebar pose")
		await review_driver(player,player._mounted_vehicle,"closure_worker_scooter")
	release_test_action("move_forward")
	release_test_action("move_right")
	player._dismount_vehicle()
	print("DRIVETRAIN_REVISION_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
