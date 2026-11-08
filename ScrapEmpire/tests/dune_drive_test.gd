extends "res://tests/crafting_test.gd"

var finite: bool = true
var wheel_clearance: bool = true
var seat_error: float = 0.0
var max_pitch: float = 0.0
var max_speed: float = 0.0
var ground_error: float=0.0
var ground_samples: int=0

func observe(player, buggy) -> void:
	finite=finite and player.global_position.is_finite() and player.velocity.is_finite() and buggy.visual.rotation.is_finite() and player.camera.global_position.is_finite()
	max_pitch=maxf(max_pitch,absf(buggy.visual.rotation.x))
	max_speed=maxf(max_speed,absf(player._vehicle_speed))
	if not player._vehicle_third_person:
		seat_error=maxf(seat_error,buggy.visual.to_local(player.camera.global_position).distance_to(Vector3(0,1.94,-0.075)))
	for wheel in buggy.wheels:
		wheel_clearance=wheel_clearance and wheel.position.y>=-0.001 and wheel.position.y<=0.601 and wheel.position.y+float(wheel.get_meta("radius"))<1.06
		if wheel.get_meta("grounded",false):
			var point: Vector3=wheel.get_meta("ground_point")
			var normal: Vector3=wheel.get_meta("ground_normal")
			ground_error=maxf(ground_error,absf((wheel.global_position-point).dot(normal)-float(wheel.get_meta("radius"))))
			ground_samples+=1

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/dune_drive_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	player.set_process_unhandled_input(false)
	GameState.yard_level=1
	GameState.vehicle_level=2
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.level==2)[0]
	var terrain = preload("res://scripts/gameplay/desert_world.gd")
	buggy.position=Vector3(0,terrain.height_at(Vector3(0,0,100))+0.08,100)
	buggy.rotation.y=PI
	player.position=buggy.position+Vector3(2,0,0)
	check(player._mount_vehicle(buggy),"buggy enters at actual external dune start")
	await frames(30)
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for index in 540:
		await get_tree().physics_frame
		observe(player,buggy)
	check(player.global_position.distance_to(start)>35 and max_speed>6,"actual controller accelerates and traverses substantial real uneven terrain")
	check(max_pitch>0.04,"moving chassis actually pitches with dune profile")
	check(seat_error<0.002,"moving cockpit remains aligned to driver eyes throughout dunes")
	await capture("dune_drive_cockpit")
	var heading: float = player._vehicle_heading
	Input.action_press("move_right",0.35)
	for index in 80:
		await get_tree().physics_frame
		observe(player,buggy)
	Input.action_release("move_right")
	check(absf(wrapf(player._vehicle_heading-heading,-PI,PI))>0.15,"actual steering changes travel direction at speed on dunes")
	var key = InputEventKey.new()
	key.keycode=KEY_V
	key.pressed=true
	player._unhandled_input(key)
	for index in 20:
		await get_tree().physics_frame
		observe(player,buggy)
	check(player._vehicle_third_person,"third person remains usable during real dune motion")
	await capture("dune_drive_chase")
	var volume = PhysicsShapeQueryParameters3D.new()
	volume.shape=SphereShape3D.new()
	volume.shape.radius=0.2
	volume.transform.origin=player.camera.global_position
	volume.exclude=[player.get_rid(),buggy.body.get_rid()]
	check(player.get_world_3d().direct_space_state.intersect_shape(volume).is_empty(),"moving chase camera remains outside terrain")
	key.keycode=KEY_P
	player._unhandled_input(key)
	await frames(90)
	var parked: Vector3 = player.global_position
	await frames(30)
	Input.action_release("move_forward")
	check(player._vehicle_motion.parking_brake and absf(player._vehicle_speed)<0.01 and player.global_position.distance_to(parked)<0.08,"parking brake holds real dune slope against accelerator")
	check(finite and wheel_clearance,"all moving poses stay finite and tyres stay below mudguards")
	check(ground_samples>1200 and ground_error<0.02,"reachable tyre contacts remain on the actual surface after body movement")
	if DisplayServer.get_name()!="headless":
		check(is_instance_valid(buggy._tracks) and buggy._tracks.stamps>20 and buggy._tracks.stamps<=640,"driven sand receives bounded world-space tyre imprints")
		await capture("buggy_sand_tracks")
	# End through normal pause so the audio mixer has frames to stop the engine.
	player._open_pause_menu()
	await frames(6)
	print("DUNE_DRIVE_METRICS distance=",start.distance_to(player.global_position)," max_speed=",max_speed," max_pitch=",max_pitch," seat_error=",seat_error," contact_samples=",ground_samples," contact_error=",ground_error)
	print("DUNE_DRIVE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
