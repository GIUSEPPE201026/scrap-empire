extends "res://tests/crafting_test.gd"

func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("LAYOUT_RESULT: 0 checks, 0 failures")
		get_tree().quit()
		return
	get_window().size = Vector2i(1280,720)
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/layout_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	for page in ["story","projects","map"]:
		player._open_career(page)
		await frames(6)
		check(player._pause_menu.size.y<=720 and player._pause_menu.position.y>=0,"journal fits 720p: "+page)
		await capture("career_720_"+page)
	await click(player,"MOSTRA IL MONDO")
	check(player._career_map_wide and player._pause_menu.size.y<=720,"world map toggle remains accessible at 720p")
	await capture("career_720_world")
	player._close_pause_menu()
	player.position = Vector3(0,0.1,14)
	player._open_station()
	await frames(5)
	check(player._pause_menu.size.y<=720 and player._pause_menu.position.y>=0,"new scale panel fits 720p")
	await capture("scale_720")
	player._close_pause_menu()
	print("LAYOUT_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
