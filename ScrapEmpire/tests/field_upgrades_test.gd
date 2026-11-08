extends "res://tests/single_player_cycle.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/field_upgrades_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	GameState.team_credits = 10000
	check(not GameState.purchase_module("gloves"),"new equipment respects prerequisite tool")
	GameState.team_upgrade_levels.tool = 1
	check(not GameState.purchase_module("scanner"),"scanner waits for first completed order")
	check(GameState.purchase_module("headlamp"),"lamp installs before first order with screwdriver owned")
	await frames(3)
	check(is_instance_valid(player._work_light) and player._work_light.spot_range==12,"purchased lamp creates actual 12m spotlight on camera")
	player._toggle_work_light()
	check(not player._work_light.visible,"lamp switch actually hides light")
	player._toggle_work_light()
	check(player._work_light.visible,"lamp switch restores light")
	var old_forward: Array[InputEvent] = InputMap.action_get_events("move_forward")
	InputMap.action_erase_events("move_forward")
	var key = InputEventKey.new()
	key.keycode = KEY_L
	InputMap.action_add_event("move_forward",key)
	key.pressed = true
	player._unhandled_input(key)
	check(player._work_light_enabled,"lamp shortcut does not override a remapped gameplay key")
	InputMap.action_erase_events("move_forward")
	for binding in old_forward:
		InputMap.action_add_event("move_forward",binding)
	GameState.completed_orders = [GameState.order_defs[0].id]
	var base_seconds: float = GameState.recovery_seconds("metal",0)
	for id in ["gloves","harness","scanner"]:
		check(GameState.purchase_module(id),"first field module installs: "+id)
	check(GameState.team_credits==8350,"first upgrades debit exact total of 1650 Bulloni")
	check(is_equal_approx(GameState.recovery_seconds("metal",0),base_seconds*0.8),"gloves reduce real collection duration by 20 percent")
	check(not GameState.recovery_allowed("copper",0),"gloves do not bypass required tool roles")
	check(not GameState.purchase_module("scanner"),"scanner second level waits for three orders")
	var target = get_tree().get_first_node_in_group("scrap")
	for item in get_tree().get_nodes_in_group("scrap"):
		item.position = Vector3(150,0,150)
	target.position = Vector3(35,0,0)
	player.position = Vector3(0,0.1,0)
	player._navigation_label = ""
	player._scan_scrap()
	check(player._navigation_label.is_empty(),"25m scanner does not reveal distant collectible")
	GameState.completed_orders = [GameState.order_defs[0].id,GameState.order_defs[1].id,GameState.order_defs[2].id]
	for id in ["gloves","harness","scanner","headlamp"]:
		check(GameState.purchase_module(id),"second field module installs: "+id)
	player._scan_scrap()
	check(player._navigation_target==target.global_position and player._navigation_label.begins_with("SCANNER"),"55m scanner gives real navigation to missing book entry")
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	GameState.ops.record_discovery(target.scrap_type,catalog.variant_for(target.entity_id))
	player._scan_scrap()
	check(player._navigation_label.is_empty(),"scanner ignores known variants and clears stale scanner destination")
	await frames(3)
	check(player._work_light.spot_range==22 and player._work_light.spot_angle==48,"second lamp expands actual light range and cone")
	var before: int = GameState.team_credits
	check(not GameState.purchase_module("scanner") and GameState.team_credits==before,"maxed upgrade cannot debit repeatedly")
	check(SaveService.save_checkpoint(94) and SaveService.load_save(94) and GameState.workshop_modules.scanner==2 and GameState.workshop_modules.harness==2,"all new equipment persists through checkpoint")
	GameState.workshop_modules.harness = 0
	var part = get_tree().get_first_node_in_group("bulk_parts")
	player.position = part.position+Vector3(0,0,2)
	await aim(player,part)
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	inject_input(mouse)
	await frames(3)
	var start: Vector3 = player.position
	Input.action_press("move_back")
	await frames(20)
	Input.action_release("move_back")
	var normal_distance: float = player.position.distance_to(start)
	GameState.workshop_modules.harness = 2
	start = player.position
	Input.action_press("move_back")
	await frames(20)
	Input.action_release("move_back")
	var upgraded_distance: float = player.position.distance_to(start)
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = false
	inject_input(mouse)
	await frames(3)
	check(upgraded_distance>normal_distance*1.5,"harness increases actual walking movement while dragging")
	GameState.workshop_modules.erase("gloves")
	var directory: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR = "res://project.godot/"
	var output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	before = GameState.team_credits
	var purchased: bool = GameState.purchase_module("gloves")
	Engine.print_error_messages = output
	SaveService.SAVE_DIR = directory
	check(not purchased and GameState.team_credits==before and not GameState.workshop_modules.has("gloves"),"failed checkpoint rolls back new upgrade and cost")
	player.position = Vector3(-18,0,20)
	player._open_inventory()
	await frames(4)
	if DisplayServer.get_name()!="headless":
		check(player._pause_menu.size.y<=get_viewport().get_visible_rect().size.y-20,"equipment utilities fit viewport")
	await capture("field_equipment")
	player._close_pause_menu()
	player.position = Vector3(-18,0,22.2)
	player._open_development()
	player._upgrade_monitor._set_page("modules")
	await frames(3)
	var monitor = player._upgrade_monitor
	var offered: Dictionary={}
	for category in ["vehicles","production","recovery"]:
		monitor._set_module_category(category)
		offered.merge(monitor.buy_buttons)
	check(offered.size()==12 and offered.has("scanner") and offered.has("headlamp") and offered.has("assembly"),"three focused upgrade categories retain all twelve upgrade lines")
	for scroll in monitor.display_viewport.find_children("*","ScrollContainer",true,false):
		scroll.ensure_control_visible(monitor.buy_buttons.gloves)
	await frames(3)
	await capture("field_upgrade_shop")
	if DisplayServer.get_name()!="headless":
		await click_physical_button(monitor,monitor.buy_buttons.gloves)
		check(GameState.workshop_modules.get("gloves",0)==1,"physical monitor click purchases new field module")
	player._close_pause_menu()
	player.position = Vector3(0,0.1,0)
	player.look_rotation = Vector2(-0.2,0)
	GameState.operations.world_seconds = 700.0
	get_tree().get_first_node_in_group("yard_clock").refresh_visuals()
	await frames(4)
	await capture("headlamp_night")
	print("FIELD_UPGRADES_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
