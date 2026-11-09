extends "res://tests/crafting_test.gd"

func choose(dialog: Node, language: String) -> void:
	var index: int=1 if language=="en" else 0
	dialog._language_options.select(index)
	dialog._language_options.item_selected.emit(index)

func run() -> void:
	get_window().size=Vector2i(1280,720)
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/localization_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	Localization.settings_path=SaveService.SAVE_DIR+"settings.cfg"
	Localization.set_language("it")
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(12)
	var menu=get_tree().current_scene
	var dialog=menu.settings_dialog
	check(Localization.text("GIOCA")=="GIOCA","Italian remains Italian with English catalog installed")
	dialog.show_dialog()
	choose(dialog,"en")
	dialog._on_cancel_pressed()
	await frames(3)
	check(Localization.language=="it" and not FileAccess.file_exists(Localization.settings_path),"cancel neither changes language nor writes settings")
	dialog.show_dialog()
	choose(dialog,"en")
	dialog._on_apply_pressed()
	await frames(3)
	var config=ConfigFile.new()
	config.load(Localization.settings_path)
	check(Localization.language=="en" and config.get_value("interface","language")=="en","Apply changes language and saves selection")
	check(Localization.text(menu.btn_single.text)=="PLAY" and Localization.text(menu.btn_options.text)=="SETTINGS","existing main menu controls translate after Apply")
	check(Localization.format_text("%s funzionanti  ·  %d / %d",["Motore recuperato",1,2])=="Salvaged engine working  ·  1 / 2","dynamic formatting translates inserted names and retains quantities")
	Localization.register_sign("BANCO RECUPERO\nRIPARA / RICICLA")
	check(Localization.text("BANCO RECUPERO\nRIPARA / RICICLA")=="SALVAGE BENCH\nREPAIR / RECYCLE","multiline world signage composes translated lines")
	check(config.get_value("controls","key_jump")=="Spazio" and InputMap.action_get_events("jump")[0].keycode==KEY_SPACE,"translated key labels never rename saved bindings")
	await capture("language_en_main")
	dialog.show_dialog()
	check(dialog._language_options.selected==1 and dialog._tab_container.get_tab_title(2)=="CONTROLS","reopened settings restore English and translated tabs")
	await frames(4)
	await capture("language_en_settings")
	if DisplayServer.get_name()!="headless": check(dialog._btn_apply.get_global_rect().end.y<=dialog.size.y and dialog.size.y<=700,"English settings and language selector fit 720p")
	choose(dialog,"it")
	dialog._on_cancel_pressed()
	check(Localization.language=="en","cancel preserves previously saved English")
	menu._on_single_pressed()
	await frames(30)
	var player=get_tree().get_first_node_in_group("players")
	check(Localization.language=="en","world entry retains selected language")
	check(preload("res://scripts/gameplay/scrap_catalog.gd").item_name(0,0)=="Brake disc","scrap variants have English names")
	check(preload("res://scripts/gameplay/yard_clock.gd").caption().begins_with("DAY "),"drawn HUD clock uses translated template")
	await frames(5)
	await capture("language_en_hud")
	GameState.player_inventories[1].metal=2
	GameState.team_deposit_counts.metal=8
	preload("res://scripts/ui/materials_panel.gd").open(player,"metal")
	await frames(4)
	await capture("language_en_materials")
	check(player._pause_menu.find_children("*","Label",true,false).any(func(label):return label.text.contains("Bolts / item")),"material prices translate before interpolation")
	player._close_pause_menu()
	preload("res://scripts/ui/press_panel.gd").purchase(player)
	await frames(4)
	await capture("language_en_press")
	check(player._station_buy.text.begins_with("Buy") and player._press_start_button.text.begins_with("PROCESS"),"live baler buttons use English after dynamic refresh")
	player._close_pause_menu()
	preload("res://scripts/ui/curiosities_panel.gd").open(player)
	await frames(4)
	await capture("language_en_album")
	player._close_pause_menu()
	player._open_development()
	var monitor=player._upgrade_monitor
	for page in ["career","tools","modules","orders","specific"]:
		monitor._set_page(page)
		await frames(4)
		if page=="modules": check(monitor.display_viewport.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Drivetrain")),"module names translate inside level captions")
		await capture("language_en_office_"+page)
	monitor._set_page("modules")
	player._close_pause_menu()
	player._open_pause_menu()
	player._show_settings()
	await frames(4)
	var pause_dialog=player.get_children().filter(func(child):return child is SettingsDialog)[0]
	check(pause_dialog._language_options.selected==1 and pause_dialog.settings_path==Localization.settings_path,"pause settings share saved language without touching owner profile")
	var position: Vector3=player.position
	pause_dialog._on_keybind_pressed("interact")
	var conflict=InputEventKey.new()
	conflict.keycode=KEY_SPACE
	conflict.pressed=true
	pause_dialog._input(conflict)
	await frames(3)
	check(pause_dialog._keybind_waiting and pause_dialog._settings.key_interact=="E" and pause_dialog._key_interact.text=="Already assigned: Space","English rebinding rejects conflicts without changing stored key")
	check(player.position==position and get_tree().paused,"rebinding while paused never moves the player")
	pause_dialog._cancel_keybind()
	choose(pause_dialog,"it")
	pause_dialog._on_apply_pressed()
	await frames(3)
	player._close_pause_menu()
	check(Localization.text("GIOCA")=="GIOCA" and preload("res://scripts/gameplay/scrap_catalog.gd").item_name(0,0)=="Disco freno" and player._hotbar.text.contains("ATTREZZATURA") and monitor.display_viewport.find_children("*","Label",true,false).any(func(label):return label.text.begins_with("Trasmissione")),"switching back restores cached HUD and physical monitor without reopening")
	config.load(Localization.settings_path)
	config.set_value("interface","language",42)
	config.save(Localization.settings_path)
	var fresh=preload("res://scenes/settings_dialog.tscn").instantiate()
	player.add_child(fresh)
	check(fresh._settings.language=="it","invalid persisted language falls back safely")
	fresh.show_dialog()
	choose(fresh,"en")
	fresh.settings_path="res://project.godot/"
	var errors: bool=Engine.print_error_messages
	Engine.print_error_messages=false
	fresh._on_apply_pressed()
	Engine.print_error_messages=errors
	check(Localization.language=="it" and fresh.visible,"failed settings save does not apply language or close the dialog")
	fresh.settings_path=Localization.settings_path
	fresh._on_cancel_pressed()
	print("LOCALIZATION_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
