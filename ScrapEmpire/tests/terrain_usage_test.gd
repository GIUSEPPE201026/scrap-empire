extends "res://tests/single_player_cycle.gd"

func aim_point(player: Node3D, point: Vector3) -> void:
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(point)
	player.look_rotation = Vector2(player.camera.rotation.x,player.camera.rotation.y)
	player.camera.rotation.y = 0

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/terrain_%d/" % Time.get_ticks_usec()
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
	buggy.position = Vector3(40,0,10)
	player.position = buggy.to_global(Vector3(0,0,3))
	aim_point(player,buggy.to_global(Vector3(0,1.2,1.6)))
	await frames(4)
	check(player._near_cargo_bay()==buggy and player._nearest_vehicle()==null,"rear aim selects cargo and never driver seat")
	await capture("targeted_cargo")
	aim_point(player,Vector3(40,3,16))
	await frames(2)
	check(player._near_cargo_bay()==null and player._nearest_vehicle()==null,"looking away suppresses vehicle actions")
	player.position = buggy.to_global(Vector3(1.7,0,0.15))
	aim_point(player,buggy.to_global(Vector3(0,1.2,0.15)))
	await frames(4)
	check(player._nearest_vehicle()==buggy and player._near_cargo_bay()==null,"side aim selects seat only")
	check(player._mount_vehicle(buggy),"targeted seat mounts vehicle")
	# One front contact climbs a 30cm obstacle, the chassis must visibly respond.
	var bump = StaticBody3D.new()
	var bump_shape = CollisionShape3D.new()
	bump_shape.shape = BoxShape3D.new()
	bump_shape.shape.size = Vector3(0.55,0.3,0.55)
	bump.add_child(bump_shape)
	sector.add_child(bump)
	bump.global_position = player.global_position+Vector3(-1.1,0.15,-1.15)
	await frames(35)
	check(absf(buggy.visual.rotation.x)+absf(buggy.visual.rotation.z)>0.025,"single raised wheel moves actual chassis pitch and roll")
	await capture("chassis_one_wheel")
	bump.queue_free()
	await frames(15)
	var drive = player._vehicle_motion
	drive.heading = 0
	drive.speed = 1.0/3.6
	drive.step(player,buggy,0,1,false,1.0/60.0)
	var slow_yaw: float = absf(drive.heading)
	drive.heading = 0
	drive.speed = 20.0/3.6
	drive.step(player,buggy,0,1,false,1.0/60.0)
	check(absf(drive.heading)>slow_yaw*5,"steering changes actual yaw much more at 20kmh than 1kmh")
	drive.speed = 0
	drive.heading = 0
	Input.action_press("move_forward")
	Input.action_press("move_left",0.25)
	await frames(60)
	Input.action_release("move_forward")
	Input.action_release("move_left")
	check(is_finite(buggy.visual.position.y) and absf(buggy.visual.position.y)<0.36,"spring remains finite within suspension travel")
	for index in 400:
		player._vehicle_motion.step(player,buggy,0,0,false,0.05)
	check(is_finite(player._vehicle_motion.suspension_velocity),"spring tolerates long variable-frame settling")
	await capture("suspension_revision")
	player._vehicle_speed = 0
	player._vehicle_motion.speed = 0
	await frames(10)
	player._dismount_vehicle()
	await frames(24) # Let the intentional exit camera transition finish before aiming elsewhere.
	var part = get_tree().get_first_node_in_group("bulk_parts")
	player.position = part.global_position+Vector3(0,0,2)
	aim_point(player,part.global_position+Vector3.UP*0.3)
	await frames(5)
	var original: Vector3 = part.global_position
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	inject_input(mouse)
	await frames(3)
	check(player._dragged==part,"right button acquires aimed bulky object")
	Input.action_press("move_back")
	await frames(40)
	Input.action_release("move_back")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = false
	inject_input(mouse)
	await frames(4)
	check(player._dragged==null and part.global_position.distance_to(original)>0.1,"ground dragging moves object and releases")
	check(GameState.get_inventory_mass(1)==0 and GameState.operations.field[part.part_id].dropped,"dragging saves world position without bag reward")
	await capture("dragging_revision")
	var raw = get_tree().get_first_node_in_group("scrap")
	player.position = raw.global_position+Vector3(0,0,2)
	aim_point(player,raw.global_position+Vector3.UP*0.3)
	await frames(4)
	var raw_start: Vector3 = raw.global_position
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	inject_input(mouse)
	await frames(3)
	check(player._dragged==raw,"right button selects ordinary collectible Area3D")
	Input.action_press("move_back")
	await frames(45)
	Input.action_release("move_back")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = false
	inject_input(mouse)
	await frames(4)
	check(raw.global_position.distance_to(raw_start)>0.1 and GameState.operations.get("loose_positions",{}).has(raw.entity_id),"ordinary scrap actually moves and position is checkpointed")
	await aim(player,raw)
	Input.action_press("collect")
	await frames(110)
	Input.action_release("collect")
	await frames(3)
	check(GameState.operations.get("scrap_album",[]).size()==1 and GameState.get_inventory_mass(1)>0,"actual held collection adds a book discovery and material")
	check(GameState.ops.record_discovery(2,4) and GameState.ops.record_discovery(2,4) and GameState.operations.scrap_album.size()==2,"collection book records discovery once")
	player._open_scrap_book()
	await frames(3)
	await capture("collection_book")
	player._close_pause_menu()
	var assembly = get_tree().get_nodes_in_group("salvage_assemblies").filter(func(a):return a.definition_id=="car")[0]
	assembly.position = Vector3(35,0,30)
	player.position = Vector3(37,0,31.2)
	aim_point(player,Vector3(36.02,0.43,31.2))
	await frames(4)
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	inject_input(mouse)
	await frames(3)
	check(player._dragged==assembly,"dragging a car component selects the whole dismantlable object")
	var assembly_start: Vector3 = assembly.position
	Input.action_press("move_back")
	await frames(60)
	Input.action_release("move_back")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = false
	inject_input(mouse)
	await frames(3)
	check(assembly.position.distance_to(assembly_start)>0.1 and GameState.operations.loose_positions.has(assembly.entity_id),"dismantlable scrap moves and persists without becoming inventory")
	player.position = Vector3(-28,0.08,74)
	player.velocity = Vector3.ZERO
	player.look_rotation = Vector2.ZERO
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await frames(210)
	Input.action_release("move_forward")
	await frames(3)
	check(player.position.y>3.5,"player physically climbs a giant heap using ordinary movement")
	await capture("giant_heap_climb")
	var clock = preload("res://scripts/gameplay/yard_clock.gd")
	var before: float = clock.elapsed()
	await frames(60)
	check(clock.elapsed()>before+0.9,"day clock advances during play")
	get_tree().paused = true
	before = clock.elapsed()
	await frames(30)
	check(clock.elapsed()==before,"pause freezes day clock")
	get_tree().paused = false
	GameState.operations.world_seconds = 1201.0
	check(clock.caption().begins_with("GIORNO 2"),"new day uses persistent elapsed time")
	check(SaveService.save_checkpoint(92) and SaveService.load_save(92) and clock.elapsed()==1201.0,"day and dragged field checkpoint reload")
	# A separate physical rig rolls down a ten-degree ramp without throttle.
	var ramp = StaticBody3D.new()
	var ramp_shape = CollisionShape3D.new()
	ramp_shape.shape = BoxShape3D.new()
	ramp_shape.shape.size = Vector3(8,0.2,14)
	ramp.add_child(ramp_shape)
	sector.add_child(ramp)
	ramp.position = Vector3(-45,1,40)
	ramp.rotation.x = -0.18
	var rig = CharacterBody3D.new()
	var rig_shape = CollisionShape3D.new()
	rig_shape.shape = BoxShape3D.new()
	rig_shape.shape.size = Vector3(0.6,0.3,1.5)
	rig_shape.position.y = 0.15
	rig.add_child(rig_shape)
	rig.floor_snap_length = 0.6
	sector.add_child(rig)
	rig.position = Vector3(-45,4,40)
	for i in 90:
		rig.velocity.y -= 9.81/60
		rig.move_and_slide()
		await frames(1)
	var rolling = preload("res://scripts/gameplay/vehicle_motion.gd").new()
	rolling.reset(0,Vector3.ZERO,GameState.vehicle_defs[1])
	for i in 60:
		rig.velocity.y -= 9.81/60
		rolling.step(rig,buggy,0,0,false,1.0/60)
		rig.move_and_slide()
		await frames(1)
	check(rolling.speed>0.7 and rig.position.z<40,"buggy drivetrain gains speed downhill on a real ramp without throttle")
	rolling.parking_brake = true
	for i in 90:
		rolling.step(rig,buggy,1,0,false,1.0/60)
		rig.move_and_slide()
		await frames(1)
	var slope_position: Vector3 = rig.position
	for i in 30:
		rolling.step(rig,buggy,0,0,false,1.0/60)
		rig.move_and_slide()
		await frames(1)
	check(rolling.speed==0 and rig.position.distance_to(slope_position)<0.05,"parking brake prevents downhill creep on physical ramp")
	rig.queue_free()
	ramp.queue_free()
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	var variants: Dictionary = {}
	for i in 20:
		variants[catalog.variant_for("electronics_%03d" % i)] = true
	check(variants.size()==5 and catalog.NAMES[2].size()==5,"electronics sector exposes five distinct collectible variants")
	var unique_names: Dictionary = {}
	for family in 7:
		for variant in 5:
			unique_names[catalog.item_name(family,variant)] = true
	check(unique_names.size()==35,"collection book exposes 35 distinct names without repeated aliases")
	var layout = preload("res://scripts/gameplay/landfill_layout.gd")
	check(layout.surface_height(Vector3.ZERO,4)>layout.surface_height(Vector3.ZERO,0)*4,"heap profiles include small and huge climbable heights")
	var malformed: Dictionary = GameState.serialize().duplicate(true)
	malformed.operations.world_seconds = INF
	check(not SaveService._validate_save_schema(malformed),"corrupt world clock rejected")
	if DisplayServer.get_name() != "headless":
		var review = Camera3D.new()
		sector.add_child(review)
		review.position = Vector3(39,5,-6)
		review.look_at(Vector3(33,1,-15))
		review.make_current()
		player.get_node("HUD").hide()
		await capture("heap_grounded_revision")
		GameState.operations.world_seconds = 700.0
		get_tree().get_first_node_in_group("yard_clock").refresh_visuals()
		await frames(3)
		await capture("yard_night_revision")
		GameState.operations.world_seconds = 100.0
		get_tree().get_first_node_in_group("yard_clock").refresh_visuals()
		var gallery = Node3D.new()
		sector.add_child(gallery)
		gallery.position = Vector3(0,60,0)
		var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
		art.box(gallery,Vector3(10,0.1,12),Vector3(0,-0.1,0),Color("#b3a58c"))
		for family in 7:
			for variant in 5:
				var exhibit = Node3D.new()
				exhibit.position = Vector3((variant-2)*1.7,0,(family-3)*1.5)
				gallery.add_child(exhibit)
				catalog.build(exhibit,family,variant,art)
		review.position = Vector3(8,73,12)
		review.look_at(Vector3(0,60,0))
		await frames(3)
		await capture("catalog_35_models")
		gallery.queue_free()
		player.get_node("HUD").show()
		review.queue_free()
	print("TERRAIN_USAGE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
