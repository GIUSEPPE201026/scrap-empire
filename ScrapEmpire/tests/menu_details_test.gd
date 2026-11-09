extends "res://tests/crafting_test.gd"
func run() -> void:
	get_window().size=Vector2i(1280,720)
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/details_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player=get_tree().get_first_node_in_group("players")
	GameState.yard_level=2
	GameState.team_credits=10000
	preload("res://scripts/economy/extra_mobility.gd").purchase("loader")
	player._select_vehicle(6)
	await frames(4)
	var scrolls: Array=player._pause_menu.find_children("*","ScrollContainer",true,false).filter(func(node):return node.get_meta("detail_fold",false))
	check(scrolls.size()>=3,"vehicle details use bounded scroll areas")
	for scroll in scrolls:
		var toggle: Button=scroll.get_parent().get_child(0)
		toggle.pressed.emit()
		await frames(3)
	check(scrolls.filter(func(node):return node.visible).size()==1,"opening another detail closes the previous one")
	var size: Vector2i=player._pause_menu.size
	var toggle: Button=scrolls.back().get_parent().get_child(0)
	for index in 20:
		toggle.pressed.emit()
		await frames(2)
	check(player._pause_menu.size==size,"repeated plus toggles never grow popup indefinitely")
	check(player._pause_menu.size.x<=1248 and player._pause_menu.size.y<=700,"expanded vehicle menu stays inside 720p")
	await capture("bounded_vehicle_details")
	var icons=preload("res://scripts/ui/menu_symbols.gd")
	check(icons.icon("loader").resource_path.ends_with("loader.png") and icons.icon("dirtbike").resource_path.ends_with("dirtbike.png"),"vehicle menu icons are rendered game models")
	check(Localization.text(GameState.module_defs.motor.description)=="Velocità e ripresa di entrambi i mezzi","Italian legacy encoding is repaired before display")
	player._pause_menu.get_meta("vehicle_job_tabs").current_tab=1
	var popup=player._pause_menu
	await click(player,"Accetta incarico")
	check(preload("res://scripts/economy/industrial_jobs.gd").progress("loader").active and player._pause_menu==popup,"vehicle job tab accepts work without closing or recentering menu")
	await capture("vehicle_job_models")
	print("MENU_DETAILS_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
