extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/sand_dust_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player=get_tree().get_first_node_in_group("players")
	GameState.yard_level=1
	GameState.vehicle_level=2
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var buggy=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.level==2)[0]
	player.position=Vector3(0,0.08,60)
	buggy.position=player.position+Vector3(1,0,0)
	check(player._mount_vehicle(buggy),"buggy mounts for dust probe")
	await frames(35)
	if DisplayServer.get_name()!="headless":
		for wheel in buggy.wheels:
			wheel.set_meta("grounded",true)
			wheel.set_meta("ground_point",Vector3(0,0,100))
		buggy.update_dust(player,8,0.5)
		check(buggy._dust_emitters.size()==2 and buggy._dust_emitters[0].emitting,"rear dust emits for sand and slip")
		buggy.update_dust(player,8,0.0)
		check(not buggy._dust_emitters[0].emitting,"straight driving does not emit drift dust")
		for wheel in buggy.wheels: wheel.set_meta("ground_point",Vector3.ZERO)
		buggy.update_dust(player,8,0.5)
		check(not buggy._dust_emitters[0].emitting,"concrete suppresses sand dust")
		buggy.stop_dust()
		check(not buggy._dust_emitters[1].emitting,"parking cleanup stops both emitters")
	print("SAND_DUST_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
