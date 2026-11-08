extends "res://tests/crafting_test.gd"

func fit(label_text: String) -> void:
	var window=get_window()
	var logical: Vector2=get_viewport().get_visible_rect().size
	var physical: Vector2=Vector2(window.size)
	check(absf(logical.aspect()-physical.aspect())<0.003,"viewport fills screen aspect without bars: "+label_text)
	var transform: Transform2D=get_viewport().get_final_transform()
	check(absf(transform.get_scale().x-transform.get_scale().y)*minf(logical.x,logical.y)<1.1,"uniform scale within pixel rounding: "+label_text)
	check(transform.origin.length()<1,"content starts at screen edge: "+label_text)

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/display_fit_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	await frames(15)
	check(int(ProjectSettings.get_setting("display/window/size/mode"))==Window.MODE_WINDOWED,"windowed is project default")
	check(get_window().mode==Window.MODE_WINDOWED,"engine starts windowed")
	check(get_window().size.x<=DisplayServer.screen_get_size(get_window().current_screen).x and get_window().size.y<=DisplayServer.screen_get_size(get_window().current_screen).y,"startup window fits current monitor")
	print("DISPLAY_NATIVE: window=%s screen=%s" % [get_window().size,DisplayServer.screen_get_size(get_window().current_screen)])
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	var menu=get_tree().current_scene
	fit("startup window")
	await capture("display_startup_window")
	menu._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	get_window().mode=Window.MODE_WINDOWED
	for dimensions in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1680,720),Vector2i(1024,768)]:
		get_window().size=dimensions
		await frames(10)
		var id="%dx%d" % [dimensions.x,dimensions.y]
		check(get_window().size==dimensions,"window actually tests requested resolution: "+id)
		print("DISPLAY_MATRIX: requested=%s actual=%s logical=%s" % [dimensions,get_window().size,get_viewport().get_visible_rect().size])
		fit(id)
		var bounds: Rect2=get_viewport().get_visible_rect()
		var slots: Control=player.get_node("HUD/EquipmentSlots")
		check(absf(slots.get_global_rect().get_center().x-bounds.get_center().x)<1,"equipment stays horizontally centered: "+id)
		check(absf(slots.get_global_rect().end.y-(bounds.end.y-40))<2,"equipment stays attached to screen bottom: "+id)
		check(bounds.encloses(player._hotbar.get_global_rect()),"shortcuts remain on screen: "+id)
		await frames(8)
		check(not player._field_ui.layout_rects.is_empty() and player._field_ui.layout_rects.all(func(rect):return bounds.encloses(rect)),"actual illustrated HUD stays inside adapted viewport: "+id)
		await capture("display_hud_"+id)
		player._open_inventory()
		await frames(5)
		check(Vector2(player._pause_menu.size).x<=bounds.size.x and Vector2(player._pause_menu.size).y<=bounds.size.y,"inventory fits adapted viewport: "+id)
		await capture("display_inventory_"+id)
		player._close_pause_menu()
	get_window().mode=Window.MODE_EXCLUSIVE_FULLSCREEN
	await frames(12)
	fit("gameplay fullscreen")
	check(get_window().size==DisplayServer.screen_get_size(get_window().current_screen),"gameplay returns to native fullscreen")
	player._open_pause_menu()
	player._show_settings()
	await frames(5)
	check(get_window().mode==Window.MODE_EXCLUSIVE_FULLSCREEN,"opening settings preserves fullscreen")
	await capture("display_fullscreen_settings")
	var dialog: SettingsDialog=player.get_children().filter(func(node):return node is SettingsDialog)[0]
	dialog._fullscreen_check.button_pressed=false
	dialog._on_cancel_pressed()
	await frames(4)
	check(get_window().mode==Window.MODE_EXCLUSIVE_FULLSCREEN,"cancel does not change session window mode")
	player._show_settings()
	await frames(4)
	dialog=player.get_children().filter(func(node):return node is SettingsDialog)[0]
	dialog.settings_path=SaveService.SAVE_DIR+"settings.cfg"
	dialog._fullscreen_check.button_pressed=false
	dialog._on_apply_pressed()
	await frames(10)
	check(get_window().mode==Window.MODE_WINDOWED,"settings can return to windowed without forcing future startup fullscreen")
	print("DISPLAY_FIT_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
