extends "res://tests/crafting_test.gd"

func audit(player: Node, id: String) -> void:
	await frames(5)
	check(is_instance_valid(player._pause_menu) and player._is_paused and get_tree().paused,"menu pauses the world: "+id)
	if not is_instance_valid(player._pause_menu):
		return
	if DisplayServer.get_name()!="headless":
		var window: Window=player._pause_menu
		check(window.size.x<=1280 and window.size.y<=700 and window.position.y>=0,"menu fits 720p: "+id)
		var outside: PackedStringArray=[]
		for control in window.find_children("*","Button",true,false):
			if not control.is_visible_in_tree():
				continue
			var ancestor: Node=control.get_parent()
			var scrollable: bool=false
			while ancestor!=null and ancestor!=window:
				if ancestor is ScrollContainer:
					scrollable=true
				ancestor=ancestor.get_parent()
			if not scrollable and not Rect2(Vector2.ZERO,Vector2(window.size)).grow(1).encloses(control.get_global_rect()):
				outside.append(control.text)
		check(outside.is_empty(),"fixed actions remain inside panel: "+id+" "+", ".join(outside))
	await capture("ux_"+id)

func visible_action(player: Node, label: String) -> bool:
	return player._pause_menu.find_children("*","Button",true,false).any(func(button):return str(button.get_meta("action_label",button.text))==label and button.is_visible_in_tree())

func audit_monitor(monitor: Node, id: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	var outside: PackedStringArray=[]
	for button in monitor.display_viewport.find_children("*","Button",true,false):
		if not button.is_visible_in_tree():
			continue
		var ancestor: Node=button.get_parent()
		var scrollable: bool=false
		while ancestor!=null and ancestor!=monitor.display_viewport:
			if ancestor is ScrollContainer:
				scrollable=true
			ancestor=ancestor.get_parent()
		if not scrollable and not Rect2(Vector2.ZERO,Vector2(monitor.UI_SIZE)).encloses(button.get_global_rect()):
			outside.append(button.text)
	check(outside.is_empty(),"monitor fixed actions inside physical display: "+id+" "+", ".join(outside))

func run() -> void:
	get_window().size=Vector2i(1280,720)
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/menu_ux_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	var menu=get_tree().current_scene
	check(menu.name=="MainMenu" and menu.btn_single.text=="GIOCA","main menu offers one clear play action")
	await capture("ux_main")
	var settings=menu.get_node("SettingsDialog")
	settings.settings_path=SaveService.SAVE_DIR+"settings.cfg"
	settings.show_dialog()
	for tab in 3:
		settings._tab_container.current_tab=tab
		await frames(4)
		if DisplayServer.get_name()!="headless":
			check(settings.size.y<=700 and settings._btn_apply.get_global_rect().end.y<=settings.size.y,"settings footer accessible: %d" % tab)
		await capture("ux_settings_%d" % tab)
	settings._on_cancel_pressed()
	menu._on_single_pressed()
	await frames(25)
	var player=get_tree().get_first_node_in_group("players")
	var stray=InputEventKey.new()
	stray.keycode=KEY_I
	stray.pressed=true
	_isolated_window_input(stray)
	await frames(3)
	check(not player._is_paused,"untagged desktop shortcut cannot alter automated scenario")
	inject_input(stray.duplicate())
	await frames(3)
	check(player._is_paused and visible_action(player,"Monopattino · bloccato"),"tagged I traverses input routing and opens actual equipment")
	var release: InputEventKey=stray.duplicate()
	release.pressed=false
	inject_input(release)
	inject_input(stray.duplicate())
	await frames(3)
	check(not player._is_paused,"tagged I reaches popup shortcut and resumes world")
	player.position=Vector3(0,0.1,14)
	player._open_station()
	await audit(player,"scale_trade")
	check(player._station_deposit.disabled and player._station_surplus.disabled,"empty scale does not offer meaningless transfers or sales")
	check(visible_action(player,"Deposita") and not visible_action(player,"Materiali") and not visible_action(player,"Nuova spedizione"),"scale separates trade from stock and expedition")
	await click(player,"Scorte")
	check(visible_action(player,"Materiali") and visible_action(player,"Componenti") and not visible_action(player,"Deposita"),"stock tab exposes only item management")
	await audit(player,"scale_stock")
	await click(player,"Spedizioni")
	check(visible_action(player,"Nuova spedizione") and not visible_action(player,"Vendi avanzi"),"expedition has its own panel task")
	await audit(player,"scale_expedition")
	for entry in [["inventory",player._open_inventory],["garage_locked",player._open_vehicle_shop],["scale_materials",player._open_cargo],["press_purchase",player._open_press],["storage",player._open_parts_storage],["cargo",player._open_buggy_cargo],["gear",player._open_crafted_gear],["expansion",player._open_land],["curiosities",player._open_journal],["collection",player._open_scrap_book],["pause",player._open_pause_menu]]:
		entry[1].call()
		await audit(player,entry[0])
		if entry[0]=="inventory" and DisplayServer.get_name()!="headless":
			var tile: Button=player._pause_menu.find_children("*","Button",true,false).filter(func(button):return button.tooltip_text.begins_with("Martello"))[0]
			tile.grab_focus()
			await frames(4)
			var preview: TextureRect=player._pause_menu.find_children("EquipmentPreview","TextureRect",true,false)[0]
			check(preview.texture==preload("res://scripts/ui/salvage_ui.gd").image("hammer"),"actual keyboard focus previews locked tool without equipping or closing inventory")
			await click(player,"Martello")
			check(player._is_paused and not GameState.owns_tool(2) and player._active_tool()==0,"clicking locked tool inspects without ownership bypass")
			await capture("ux_inventory_hammer")
		if entry[0]=="collection":
			await click(player,"Elettronica")
			var labels: Array=player._pause_menu.find_children("*","Label",true,false)
			check(labels.any(func(label):return label.text==preload("res://scripts/gameplay/scrap_catalog.gd").item_name(2,0)) and not labels.any(func(label):return label.text==preload("res://scripts/gameplay/scrap_catalog.gd").item_name(0,0)),"collection switches actual family cards without a long combined list")
		player._close_pause_menu()
	preload("res://scripts/ui/crafting_panel.gd").queue(player)
	await audit(player,"queue_empty")
	player._close_pause_menu()
	GameState.yard_level=2
	GameState.vehicle_level=2
	GameState.press_owned=true
	GameState.team_upgrade_levels.tool=2
	GameState.completed_orders=GameState.order_defs.slice(0,3).map(func(order):return order.id)
	GameState.workshop_modules.workbench=1
	get_tree().get_first_node_in_group("sector").apply_land_expansions()
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	player.position=get_tree().get_first_node_in_group("field_depot").global_position+Vector3(0,0,1)
	player._open_field_depot()
	await audit(player,"field_depot")
	player._close_pause_menu()
	for entry in [["garage_owned",player._open_vehicle_shop],["production",player._open_production_queue],["supply_jobs",player._open_supply_jobs]]:
		if entry[0]=="production":
			player.position=get_tree().get_first_node_in_group("industrial_press").interaction_position()+Vector3(0,0,-1.8)
			GameState.workshop_modules.press_drive=2
		entry[1].call()
		await audit(player,entry[0])
		if entry[0]=="production":
			await click(player,"Attiva tramoggia")
			check(GameState.operations.autofeed and not player._is_paused,"production primary control activates feeder through spatially validated operation")
			GameState.ops.set_autofeed(false)
		player._close_pause_menu()
	preload("res://scripts/ui/yard_panels.gd").parts(player,true)
	await audit(player,"recovery")
	for recipe in ["handcart","repair_kit","restored_radio"]:
		preload("res://scripts/ui/crafting_panel.gd").open(player,true,recipe)
		await audit(player,"recipe_"+recipe)
		if recipe=="restored_radio":
			await click(player,"Cliente")
			check(not player._is_paused and player._navigation_label.contains("Nina"),"product catalog links the actual buyer on the world navigator")
	for id in ["marta","bruno","ada"]:
		preload("res://scripts/ui/customer_panel.gd").open(player,id)
		await audit(player,"customer_"+id)
	for page in ["story","projects","map"]:
		player._open_career(page)
		await audit(player,"journal_"+page)
	player._close_pause_menu()
	player._open_development()
	var monitor=player._upgrade_monitor
	for page in ["career","tools","orders","specific","modules"]:
		monitor._set_page(page)
		await frames(4)
		await capture("ux_monitor_"+page)
		audit_monitor(monitor,page)
		check(monitor.display_viewport.find_children("*","Button",true,false).any(func(button):return not button.disabled),"monitor actions available: "+page)
	for category in ["vehicles","recovery","production"]:
		var title: String={"vehicles":"Mezzi","recovery":"Recupero","production":"Produzione"}[category]
		var tab: Button=monitor.display_viewport.find_children("*","Button",true,false).filter(func(button):return button.text==title)[0]
		if DisplayServer.get_name()=="headless":
			tab.pressed.emit()
		else:
			await click_physical_button(monitor,tab)
		await frames(3)
		check(monitor.module_category==category and monitor.buy_buttons.size() in [3,4,5],"physical tab selects focused module category: "+category)
		audit_monitor(monitor,category)
		await capture("ux_modules_"+category)
	GameState.completed_orders=GameState.order_defs.map(func(order):return order.id)
	monitor._set_page("orders")
	await frames(5)
	audit_monitor(monitor,"certified_deliveries")
	await capture("ux_monitor_certified")
	player._close_pause_menu()
	check(not player._is_paused and not get_tree().paused,"closing menus resumes single player")
	print("MENU_UX_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
