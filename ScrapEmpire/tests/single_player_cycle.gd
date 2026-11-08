extends Node

var failures: int = 0
var checks: int = 0
var _test_held_actions: Dictionary = {}
var _restored_test_holds: int = 0

func check(condition: bool, label_text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label_text)
	else:
		print("PASS: " + label_text)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority=-1000
	# Renderer tests inject input into their own viewport. Keep desktop keystrokes
	# from starting a session or confirming a purchase while the suite runs.
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	get_window().set_flag(Window.FLAG_MOUSE_PASSTHROUGH,true)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_input_event_callback(_isolated_window_input,get_window().get_window_id())
	call_deferred("run")

func inject_input(event: InputEvent) -> void:
	# Keep InputMap state and normal viewport routing, but distinguish our events
	# from desktop input delivered to the renderer window during an unattended run.
	event.set_meta("qa_injected",true)
	for action in InputMap.get_actions():
		if event.is_action(action):
			if event.is_pressed():
				_test_held_actions[action]=true
			else:
				_test_held_actions.erase(action)
	Input.parse_input_event(event)

func _isolated_window_input(event: InputEvent) -> void:
	if not event.has_meta("qa_injected"):
		# Input updates its global action state before dispatching to Window.
		# Remove desktop presses too (e.g. Space must not jump in a hold test).
		for action in InputMap.get_actions():
			if event.is_action(action):
				if _test_held_actions.has(action):
					Input.action_press(action)
				else:
					Input.action_release(action)
		return
	get_window().window_input.emit(event)
	get_window().push_input(event)

func hold_test_action(action: String) -> void:
	_test_held_actions[action]=true
	Input.action_press(action)

func release_test_action(action: String) -> void:
	_test_held_actions.erase(action)
	Input.action_release(action)

func _physics_process(_delta: float) -> void:
	# Native focus changes can clear Input's global held state even when their
	# window events are filtered. Restore the explicitly scripted hold before
	# player physics; release/cancellation tests remove it deliberately.
	for action in _test_held_actions:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
			_restored_test_holds+=1

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/sp_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	var menu = get_tree().current_scene
	check(menu.name == "MainMenu", "boot reaches main menu")
	await capture("menu")
	var settings = menu.get_node("SettingsDialog")
	settings.settings_path = SaveService.SAVE_DIR + "settings.cfg"
	settings.show_dialog()
	settings._tab_container.current_tab = 2
	await capture("settings_controls")
	settings._on_keybind_pressed("move_forward")
	var key_event = InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_S
	settings._input(key_event)
	check(settings._keybind_waiting and settings._settings.key_move_forward == "W", "conflicting key rejected")
	key_event.keycode = KEY_Q
	settings._input(key_event)
	check(settings._settings.key_move_forward == "Q", "remap updates correct settings key")
	settings._on_cancel_pressed()
	check(InputMap.action_get_events("move_forward")[0].keycode == KEY_W, "cancel restores saved controls")
	settings.show_dialog()
	settings._settings.key_move_forward = "Q"
	settings._settings.fov = 95.0
	settings._settings.invert_y = true
	settings._settings.master_volume = 0.4
	settings._on_apply_pressed()
	var saved_settings = ConfigFile.new()
	check(saved_settings.load(settings.settings_path) == OK and saved_settings.get_value("controls", "key_move_forward") == "Q", "settings persisted to disk")
	settings._load_settings()
	check(settings._settings.fov == 95.0 and settings._settings.invert_y and InputMap.action_get_events("move_forward")[0].keycode == KEY_Q, "settings and remap reload")
	settings.show_dialog()
	settings._on_reset_defaults()
	settings._on_apply_pressed()
	menu._on_single_pressed()
	await frames(15)
	var player = get_tree().get_first_node_in_group("players")
	player.auto_workshop_zones = false
	check(player != null and player.camera.current, "single player has current camera")
	check(not NetworkGateway.is_network_connected(), "single player requires no network")
	check(get_tree().get_nodes_in_group("scrap").size() == 120, "exactly 120 scrap")
	var counts = {"metal": 0, "plastic": 0, "electronics": 0}
	var ids: Dictionary = {}
	for scrap in get_tree().get_nodes_in_group("scrap"):
		counts[player._scrap_type_to_material_id(scrap.scrap_type)] += 1
		ids[scrap.entity_id] = true
	check(counts == {"metal": 60, "plastic": 40, "electronics": 20} and ids.size() == 120, "material distribution and unique IDs")
	await frames(60)
	check(player.is_on_floor(), "player grounded on collidable floor")
	check(get_tree().get_nodes_in_group("landfill_piles").size() == 6, "six collidable landfill heaps")
	var furthest: float = 0
	for scrap in get_tree().get_nodes_in_group("scrap"):
		furthest = maxf(furthest, scrap.position.distance_to(Vector3(0, 0, 14)))
	check(furthest > 70, "landfill extends beyond the starting yard")
	await test_world_rework(player)
	await capture("sector")
	await capture_landfill(player)
	if OS.get_cmdline_user_args().has("--yard-review"):
		print("YARD_TEST_RESULT: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1 if failures else 0)
		return
	if OS.get_cmdline_user_args().has("--menu-review"):
		player.position = Vector3(0, 0, 12)
		player._open_station()
		await capture("station_redesign")
		player._open_development()
		await capture("development")
		player._open_vehicle_shop()
		await capture("garage_vehicles")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--review-only"):
		print("LANDFILL_VISUAL_REVIEW_READY")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--material-review"):
		await aim(player, get_tree().get_nodes_in_group("scrap")[0])
		await capture("terrain_material")
		print("MATERIAL_VISUAL_REVIEW_READY")
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--vehicle-review"):
		await test_vehicle_refit(player)
		await test_workshop_modules(player)
		print("VEHICLE_TEST_RESULT: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if OS.get_cmdline_user_args().has("--campaign-review"):
		GameState.yard_level = 2
		GameState.vehicle_level = 2
		await test_tool_roles_and_orders(player)
		await test_workshop_modules(player)
		print("CAMPAIGN_TEST_RESULT: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	if OS.get_cmdline_user_args().has("--workshop-review"):
		await test_workshop_discovery(player)
		print("WORKSHOP_TEST_RESULT: %d checks, %d failures" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	check(is_equal_approx(player.camera.position.y, 1.6), "camera retains eye height")
	var before_position: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(15)
	Input.action_release("move_forward")
	check(player.position.distance_to(before_position) > 0.5, "movement through InputMap")
	player.position = Vector3(0, 0, -78)
	player.look_rotation = Vector2.ZERO
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(player.position.z < -81,"north gate permits actual walking through visible opening")
	player.position=Vector3(20,0,-78)
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(player.position.z > -79.8, "solid fence panel blocks actual movement outside the gate")
	player.position = Vector3(0, 0, 12)
	await frames(3)
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	check(player.position.y > 0.1, "jump responds to mapped action")
	await frames(90)
	player._open_pause_menu()
	before_position = player.position
	var frozen_glow: float = get_tree().current_scene._glow_time
	Input.action_press("move_forward")
	await frames(15)
	Input.action_release("move_forward")
	check(player.position == before_position and get_tree().current_scene._glow_time == frozen_glow, "pause freezes player and world")
	player._show_settings()
	await frames(2)
	var pause_settings = player.get_children().filter(func(child): return child is SettingsDialog)[0]
	check(pause_settings.can_process() and pause_settings.visible, "settings usable during pause")
	check(get_tree().paused and player._is_paused, "opening settings keeps world paused")
	await capture("pause_settings")
	pause_settings._on_keybind_pressed("move_forward")
	key_event.keycode = KEY_E
	pause_settings._input(key_event)
	Input.action_press("move_forward")
	await frames(3)
	Input.action_release("move_forward")
	check(player.position == before_position and GameState.get_inventory_mass(1) == 0, "remapping cannot move or deposit")
	pause_settings._on_cancel_pressed()
	player._close_pause_menu()
	await frames(3)
	check(not get_tree().paused, "resume unpauses")
	var target = get_tree().get_nodes_in_group("scrap")[0]
	check(not EconomyService.purchase_upgrade("bag") and GameState.team_credits == 0, "purchase rejected without sufficient credits")
	await aim(player, target)
	var barrier = StaticBody3D.new()
	var barrier_shape = CollisionShape3D.new()
	barrier_shape.shape = BoxShape3D.new()
	barrier_shape.shape.size = Vector3(2, 3, 0.2)
	barrier.add_child(barrier_shape)
	get_tree().current_scene.add_child(barrier)
	barrier.position = target.position + Vector3(0, 0.5, 0.8)
	Input.action_press("collect")
	await frames(100)
	Input.action_release("collect")
	check(player._target_scrap == null and GameState.get_inventory_mass(1) == 0, "solid obstacle blocks collection")
	barrier.queue_free()
	await frames(3)
	await aim(player, target)
	player.position.z += 3.5
	Input.action_press("collect")
	await frames(100)
	Input.action_release("collect")
	check(player._target_scrap != target and is_instance_valid(target) and GameState.get_inventory_mass(1) == 0, "outside three meters cannot collect distant scrap")
	await aim(player, target)
	Input.action_press("collect")
	await frames(20)
	check(player._collecting and player._collect_progress > 0, "hold begins visible collection")
	await capture("collection")
	Input.action_release("collect")
	await frames(2)
	check(not player._collecting and is_instance_valid(target), "release cancels without consuming")
	Input.action_press("collect")
	await frames(20)
	player.look_rotation.y += PI
	await frames(2)
	check(not player._collecting and is_instance_valid(target), "lost target cancels collection")
	Input.action_release("collect")
	for bag_index in 3:
		for item_index in 10:
			target = get_tree().get_nodes_in_group("scrap").filter(func(item): return item.scrap_type == 0)[0]
			await aim(player, target)
			Input.action_press("collect")
			await frames(100)
			Input.action_release("collect")
			await frames(2)
		check(GameState.get_inventory_mass(1) == 20, "bag capacity 20 kg, batch %d" % bag_index)
		target = get_tree().get_nodes_in_group("scrap").filter(func(item): return item.scrap_type == 0)[0]
		await aim(player, target)
		Input.action_press("collect")
		await frames(100)
		Input.action_release("collect")
		check(is_instance_valid(target) and not target.is_queued_for_deletion(), "full bag keeps scrap in world")
		player.position = Vector3(0, 0, 12)
		player._open_station()
		var credits_before: int = GameState.team_credits
		player._try_deposit()
		check(GameState.get_inventory_mass(1) == 0 and GameState.team_deposit_counts.metal == 10 and GameState.team_credits == credits_before, "deposit conserves materials without credits")
		player._try_deposit()
		check(GameState.team_deposit_counts.metal == 10, "repeat deposit cannot duplicate")
		player._sell_deposit()
		check(GameState.team_credits == credits_before + 100 and GameState.team_deposit_counts.metal == 0, "sale transfers exactly 100 credits")
		player._sell_deposit()
		check(GameState.team_credits == credits_before + 100, "repeat sale credits zero")
		player._close_pause_menu()
		await frames(2)
	player._open_station()
	player._buy_bag()
	check(GameState.team_credits == 50 and GameState.get_inventory_capacity(1) == 30, "purchase costs 250 and increases capacity to 30")
	check(InventoryService.get_capacity() == 30 and "30" in player._weight_label.text and "50" in player._credits_label.text, "HUD and inventory service reflect upgrade during pause")
	await capture("upgrade")
	player._buy_bag()
	check(GameState.team_credits == 50, "repeat purchase cannot debit")
	for item_index in 15:
		check(InventoryService.add_item(1, "metal"), "upgraded bag accepts item %d" % item_index)
	check(not InventoryService.add_item(1, "plastic"), "upgraded bag refuses excess")
	player._new_expedition()
	check(GameState.get_inventory_mass(1) == 30, "new expedition rejects nonempty bag")
	player._try_deposit()
	player._new_expedition()
	await frames(15)
	player = get_tree().get_first_node_in_group("players")
	player.auto_workshop_zones = false
	check(get_tree().get_nodes_in_group("players").size() == 1 and get_tree().get_nodes_in_group("scrap").size() == 120, "new expedition no duplicate nodes")
	check(GameState.team_credits == 50 and GameState.team_deposit_counts.metal == 15 and GameState.get_inventory_capacity(1) == 30, "expedition preserves progression and unsold deposit")
	player.position.y = -30
	await frames(3)
	check(player.position.y > 0, "out of bounds respawn")
	check(SaveService.save_checkpoint(), "checkpoint writes and promotes temp file")
	GameState.team_credits = 0
	GameState.team_upgrade_levels.bag = 0
	check(SaveService.load_save(), "latest checkpoint discoverable")
	check(GameState.team_credits == 50 and GameState.get_inventory_capacity(1) == 30, "load restores credits and upgrades")
	var invalid: Dictionary = GameState.serialize().duplicate(true)
	invalid.team_credits = -1
	check(not GameState.deserialize(invalid) and GameState.team_credits == 50, "invalid load does not mutate state")
	invalid = GameState.serialize().duplicate(true)
	invalid.team_deposit_counts.metal = 1.5
	check(not SaveService._validate_save_schema(invalid), "fractional counts rejected")
	check(not SaveService._validate_save_schema([]), "non-object JSON rejected")
	var corrupt_path: String = SaveService.SAVE_DIR + "scrapempire_999999999999999999_slot0.json"
	var corrupt = FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(not SaveService.load_save() and FileAccess.get_file_as_string(corrupt_path) == "{broken", "corrupt file preserved")
	player._open_pause_menu()
	player._do_quit_to_menu()
	await frames(8)
	check(get_tree().get_nodes_in_group("players").is_empty() and not get_tree().paused, "menu cleanup removes player and pause")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "return from pause releases cursor in main menu")
	SessionState.progression_loaded = false
	GameState.team_credits = 0
	GameState.team_upgrade_levels.bag = 0
	get_tree().current_scene._on_single_pressed()
	await frames(15)
	check(GameState.team_credits == 50 and GameState.get_inventory_capacity(1) == 30, "corrupt latest falls back to valid checkpoint")
	check(get_tree().get_nodes_in_group("players").size() == 1, "reenter starts one player")
	player = get_tree().get_first_node_in_group("players")
	player.auto_workshop_zones = false
	for material_type in [1, 2]:
		target = get_tree().get_nodes_in_group("scrap").filter(func(item): return item.scrap_type == material_type)[0]
		await aim(player, target)
		Input.action_press("collect")
		await frames(70 if material_type == 1 else 165)
		Input.action_release("collect")
		await frames(2)
	check(GameState.get_inventory_mass(1) == 4 and GameState.player_inventories[1].plastic == 1 and GameState.player_inventories[1].electronics == 1, "plastic and electronics use catalog masses and collection durations")
	InventoryService.deposit_all(1)
	check(GameState.team_deposit_counts.plastic == 1 and GameState.team_deposit_counts.electronics == 1 and GameState.get_inventory_mass(1) == 0, "mixed materials conserved during deposit")
	await test_press(player)
	await test_development()
	await test_salvage_transport()
	player = get_tree().get_first_node_in_group("players")
	await test_vehicle_refit(player)
	await test_workshop_modules(player)
	print("SP_TEST_RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame

func aim(player: Node3D, target: Node3D) -> void:
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	var target_point: Vector3 = target.global_position + (Vector3.UP*0.33 if target.is_in_group("scrap") else Vector3.ZERO)
	if target.is_in_group("salvage_assemblies"):
		var step: Dictionary = target.get_step()
		if not step.is_empty():
			var anchor: Array = step.anchor
			target_point = target.to_global(Vector3(anchor[0],anchor[1],anchor[2]))
	player.position = Vector3(target_point.x,0,target_point.z+1.5)
	var from = player.position + Vector3(0, 30, 0)
	var query = PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 80, 0))
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		player.position.y = hit.position.y + 0.05
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(target_point)
	player.look_rotation = Vector2(player.camera.rotation.x, player.camera.rotation.y)
	player.camera.rotation.y = 0
	await frames(3)

func capture(label_text: String) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--capture"):
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test_logs/" + label_text + ".png")

func capture_landfill(player: Node3D) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--capture"):
		return
	var overview = Camera3D.new()
	get_tree().current_scene.add_child(overview)
	overview.position = Vector3(70, 65, 65)
	overview.look_at(Vector3(0, 0, -22))
	overview.current = true
	player.get_node("HUD").hide()
	await capture("landfill_overview")
	player.camera.current = true
	player.get_node("HUD").show()
	overview.queue_free()

func test_press(player: Node3D) -> void:
	var legacy: Dictionary = GameState.serialize().duplicate(true)
	legacy.schema_version = 1
	legacy.erase("press")
	GameState.press_owned = true
	check(GameState.deserialize(legacy) and not GameState.press_owned and GameState.team_credits == 50, "v1 campaign migrates without changing progression")
	check(not GameState.purchase_press() and GameState.team_credits == 50, "press cannot be purchased without funds")
	GameState.team_credits = int(GameState.press_def.cost) + 50
	var machine = get_tree().get_first_node_in_group("industrial_press")
	player.position = machine.interaction_position() + Vector3(0, 0, -1)
	player.look_rotation = Vector2(0.0, PI)
	await frames(3)
	player._open_press()
	player._purchase_press()
	check(GameState.press_owned and GameState.team_credits == 50, "press purchase debits catalog cost once")
	check(not GameState.purchase_press() and GameState.team_credits == 50, "duplicate machine purchase rejected")
	await capture("press_panel")
	player._begin_press()
	check(GameState.press_remaining == float(GameState.press_def.cycle_seconds) and GameState.team_deposit_counts.metal == 10, "press reserves exactly five metal units")
	check(not GameState.start_press() and GameState.team_deposit_counts.metal == 10, "busy press rejects duplicate start")
	player._open_pause_menu()
	var paused_remaining: float = GameState.press_remaining
	await frames(30)
	check(GameState.press_remaining == paused_remaining, "pause freezes machine timer")
	player._close_pause_menu()
	await frames(120)
	await capture("press_working")
	var remaining: float = GameState.press_remaining
	check(remaining > 0 and remaining < paused_remaining, "machine advances while collecting is available")
	check(SaveService.save_checkpoint(77), "in-progress machine checkpoint writes")
	GameState.press_remaining = 0
	GameState.press_owned = false
	check(SaveService.load_save(77) and GameState.press_owned and GameState.press_remaining > 0 and GameState.team_deposit_counts.metal == 10, "load resumes reserved batch without refund or duplication")
	await frames(300)
	check(GameState.press_remaining == 0 and GameState.press_bales == 1, "completed cycle creates one bale")
	await capture("press_complete")
	await frames(30)
	check(GameState.press_bales == 1, "completed cycle cannot create extra bales")
	var value_before: int = GameState.get_deposit_value()
	check(GameState.get_bale_value() == 75 and value_before == 203, "pressed metal adds 50 percent value with conserved mass")
	var credits_before: int = GameState.team_credits
	check(EconomyService.sell_deposit() == value_before and GameState.team_credits == credits_before + value_before and GameState.press_bales == 0, "sale includes bale once")
	check(EconomyService.sell_deposit() == 0 and not GameState.start_press(), "empty depot cannot sell or process again")
	var malformed: Dictionary = GameState.serialize().duplicate(true)
	malformed.press.remaining_seconds = -1
	check(not SaveService._validate_save_schema(malformed), "negative machine timer rejected")
	malformed.press.remaining_seconds = 1
	malformed.press.owned = false
	check(not SaveService._validate_save_schema(malformed), "unowned machine cannot hold a reserved batch")
	malformed.press.owned = true
	malformed.press.remaining_seconds = 0
	malformed.press.bales = 0.5
	check(not SaveService._validate_save_schema(malformed), "fractional bale count rejected")
	player.position = Vector3(0, 0, 12)
	player._open_station()
	player._new_expedition()
	await frames(15)
	check(GameState.press_owned and get_tree().get_nodes_in_group("industrial_press").size() == 1, "new expedition retains one purchased press")

func test_development() -> void:
	var player = get_tree().get_first_node_in_group("players")
	player.auto_workshop_zones = false
	player.set_process_unhandled_input(false)
	check(not GameState.purchase_land() and GameState.yard_level == 0, "land purchase rejects insufficient funds")
	var gate_query = PhysicsRayQueryParameters3D.create(Vector3(93, 1, 0), Vector3(97, 1, 0))
	var before_gate: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(gate_query)
	check(not before_gate.is_empty() and before_gate.collider.name == "LockedGate", "unowned lot has an actual entrance barrier")
	GameState.team_credits = 7000
	check(not GameState.purchase_land(), "cash alone cannot bypass required project tool")
	player.position = Vector3(-18, 0, 24.5)
	player._open_development()
	player._buy_development("tool")
	check(GameState.owns_tool(1) and not GameState.owns_tool(2), "first kit unlocks screwdriver without granting hammer")
	check(not GameState.purchase_land(), "land project also requires materials in central deposit")
	GameState.team_deposit_counts.electronics = 4
	player.position = Vector3(-26, 0, 21)
	player._open_land()
	await capture("land_plans")
	player._buy_land()
	check(GameState.yard_level == 1 and GameState.team_credits == 5900 and GameState.team_deposit_counts.electronics == 0, "first expansion consumes exact project materials and price")
	check(get_tree().get_nodes_in_group("scrap").size() == 144 and get_tree().get_nodes_in_group("field_depot").filter(func(node):return node.get_parent().is_in_group("unlocked_lots")).size() == 1, "first purchased lot opens resources and satellite depot immediately")
	await frames(2)
	check(player.get_world_3d().direct_space_state.intersect_ray(gate_query).is_empty(), "purchase removes the entrance barrier immediately")
	player.position = Vector3(-18, 0, 24.5)
	player._buy_development("tool")
	check(GameState.owns_tool(1) and GameState.owns_tool(2), "buying hammer keeps screwdriver available")
	GameState.team_deposit_counts.copper = 6
	GameState.team_deposit_counts.aluminum = 6
	player.position = Vector3(-26, 0, 21)
	player._buy_land()
	check(GameState.yard_level == 2 and GameState.team_credits == 3600 and GameState.team_deposit_counts.copper == 0 and GameState.team_deposit_counts.aluminum == 0 and not GameState.purchase_land(), "second expansion requires first lot resources and consumes them once")
	check(get_tree().get_nodes_in_group("scrap").size() == 168 and get_tree().get_nodes_in_group("expansion_piles").size() == 6, "both lots visibly contain six additional heaps and 48 new scraps")
	get_tree().current_scene.apply_land_expansions()
	check(get_tree().get_nodes_in_group("scrap").size() == 168, "refreshing owned lots cannot duplicate spawned resources")
	player.position = Vector3(-18, 0, 24.5)
	player._buy_development("movement")
	check(GameState.team_upgrade_levels.movement == 1 and float(GameState.get_upgrade_effect("movement")) > 1.0, "movement upgrade changes travel speed")
	check(SaveService.save_checkpoint(88), "expanded campaign checkpoint saved")
	GameState.yard_level = 0
	check(SaveService.load_save(88) and GameState.yard_level == 2, "land ownership reloads")
	var invalid: Dictionary = GameState.serialize().duplicate(true)
	invalid.yard_level = 3
	check(not SaveService._validate_save_schema(invalid), "impossible land level rejected")
	player._close_pause_menu()
	player._open_station()
	player._new_expedition()
	await frames(15)
	check(get_tree().get_nodes_in_group("scrap").size() == 168, "two expansions unlock 48 additional scraps")
	check(get_tree().get_first_node_in_group("players")._navigation_label == "LOTTO DELLE DUNE", "loading owned land automatically indicates route to expanded property")
	var kinds: Dictionary = {}
	for scrap in get_tree().get_nodes_in_group("scrap"):
		kinds[scrap.scrap_type] = true
	check(kinds.size() == 7, "seven material families unlocked")
	player = get_tree().get_first_node_in_group("players")
	player.auto_workshop_zones = false
	player.set_process_unhandled_input(false)
	for material_type in [3, 4, 5, 6]:
		player._equip_tool(1 if material_type in [3, 4] else 2)
		var target = get_tree().get_nodes_in_group("scrap").filter(func(item): return item.scrap_type == material_type)[0]
		await aim(player, target)
		Input.action_press("collect")
		await frames(135)
		Input.action_release("collect")
		await frames(2)
	check(GameState.player_inventories[1].copper == 1 and GameState.player_inventories[1].rubber == 1 and GameState.player_inventories[1].glass == 1 and GameState.player_inventories[1].aluminum == 1, "new scrap families collectible with correct inventory keys")
	player.position = Vector3(0, 0, 77)
	player.look_rotation = Vector2(0, PI)
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(player.position.z > 80, "south gate permits leaving the landfill")
	var terrain = preload("res://scripts/gameplay/desert_world.gd")
	check(terrain.height_at(Vector3(0, 0, 125)) > 1 and terrain.height_at(Vector3.ZERO) == 0, "exterior dunes have real elevation with flat yard")
	player.position = Vector3(0, terrain.height_at(Vector3(0, 0, 120)) + 1, 120)
	player.look_rotation = Vector2(-0.35, PI)
	await frames(90)
	check(player.is_on_floor(), "dune collision supports player")
	await capture("dunes")

func test_salvage_transport() -> void:
	var player = get_tree().get_first_node_in_group("players")
	player.auto_workshop_zones = false
	player.set_process_unhandled_input(false)
	for material_id in GameState.player_inventories[1]:
		GameState.player_inventories[1][material_id] = 0
	GameState.team_upgrade_levels.bag = 0
	GameState.team_upgrade_levels.tool = 2
	player._equip_tool(1)
	# This fixture deliberately closes previously tested lots; reset their raw identities too.
	GameState.sector_consumed_ids.clear()
	GameState.sector_revision = 0
	GameState.yard_level = 0
	var car = get_tree().get_nodes_in_group("salvage_assemblies").filter(func(item): return item.definition_id == "car")[0]
	check(get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.definition_id in ["car","generator","appliance"]).size()==13 and get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return node.entity_id.begins_with("desert_")).size()==4, "nine original salvage objects four expanded lot objects and four distinct desert recoveries remain available")
	car.select_component(0)
	await aim(player,car)
	check(player._target_scrap == car, "car selected by same three meter line-of-sight ray")
	Input.action_press("collect")
	await frames(40)
	Input.action_release("collect")
	await frames(2)
	check(car.stage == 0 and GameState.get_inventory_mass(1) == 0, "releasing dismantle leaves object and materials intact")
	Input.action_press("collect")
	await frames(250)
	Input.action_release("collect")
	await frames(2)
	check(car.stage == 1 and GameState.player_inventories[1].metal == 3, "held dismantling removes first car part and yields three metal")
	await capture("salvage_car")
	check(not GameState.claim_salvage(car.entity_id, "car", 0, 1).success, "completed stage cannot grant materials twice")
	car.select_component(1)
	await aim(player,car)
	for index in 7:
		InventoryService.add_item(1, "metal")
	Input.action_press("collect")
	await frames(310)
	Input.action_release("collect")
	await frames(2)
	check(car.stage == 1 and GameState.get_inventory_mass(1) == 20, "full bag rejects entire dismantling batch")
	check(not player._collecting and player._collection_requirement().contains("SACCA PIENA"), "full bag is explained before starting a false progress bar")
	for material_id in GameState.player_inventories[1]:
		GameState.player_inventories[1][material_id] = 0
	Input.action_press("collect")
	await frames(310)
	Input.action_release("collect")
	await frames(2)
	check(car.stage == 2 and GameState.get_inventory_mass(1) == 5, "second phase yields mixed materials (stage %d, mass %.1f)" % [car.stage, GameState.get_inventory_mass(1)])
	car.select_component(2)
	await aim(player,car)
	check(not player._collecting and player._collection_requirement().contains("PROGETTO"), "locked project blocks progress immediately with explanation")
	check(not car.commit_stage(1, 1).success and car.stage == 2, "advanced phase needs unlocked equipment tier")
	GameState.yard_level = 1
	check(car.commit_stage(1, 1).success and car.commit_stage(1, 2).success and car.stage == 4, "later car phases complete without duplicated yields")
	check(not car.commit_stage(1).success, "fully dismantled object cannot be consumed again")
	player.position = Vector3(0, 0, 12)
	player._open_inventory()
	await capture("inventory")
	var metal_before: int = GameState.player_inventories[1].metal
	var credits_before: int = GameState.team_credits
	player._sell_one("metal", "bag")
	check(GameState.player_inventories[1].metal == metal_before - 1 and GameState.team_credits == credits_before + 10, "individual bag sale consumes one item and credits once")
	player._close_pause_menu()
	player.position = Vector3(0, 0, 115)
	player._open_inventory()
	credits_before = GameState.team_credits
	player._sell_one("metal", "bag")
	check(GameState.team_credits == credits_before, "individual sale unavailable away from scale")
	player._close_pause_menu()
	player.position = Vector3(0, 0, 12)
	InventoryService.deposit_all(1)
	var deposit_before: int = GameState.team_deposit_counts.metal
	player._open_inventory()
	player._sell_one("metal", "deposit")
	check(GameState.team_deposit_counts.metal == deposit_before - 1, "individual deposit sale conserves other items")
	player._close_pause_menu()
	for definition_id in ["generator", "appliance"]:
		var item = get_tree().get_nodes_in_group("salvage_assemblies").filter(func(object): return object.definition_id == definition_id)[0]
		check(item.commit_stage(1, 1 if definition_id == "generator" else 2).success, "distinct dismantling recipe works: " + definition_id)
	GameState.vehicle_level = 0
	GameState.team_credits = 3000
	GameState.yard_level = 0
	player.position = Vector3(-18, 0, 24.5)
	player.position = Vector3(15, 0, 25)
	player._open_vehicle_shop()
	player._buy_vehicle()
	check(GameState.vehicle_level == 1 and GameState.team_credits == 2400, "scooter purchased at garage for 600")
	check(not GameState.purchase_vehicle(), "buggy locked before first land expansion")
	GameState.yard_level = 1
	player._buy_vehicle()
	check(GameState.vehicle_level == 2 and GameState.team_credits == 600, "utility buggy purchase follows scooter and land")
	await capture("garage_vehicles")
	player._close_pause_menu()
	var scooter = get_tree().get_nodes_in_group("yard_vehicles").filter(func(item): return item.level == 1)[0]
	check(not scooter.visible, "portable scooter starts stored rather than cluttering the base")
	player.position = Vector3(9, 0, 20)
	player.rotation = Vector3.ZERO
	player._toggle_scooter()
	check(scooter.visible and player._mounted_vehicle == scooter, "equipping scooter puts it directly under the rider")
	check(player.position.distance_to(Vector3(9, 0, 20)) < 0.1, "scooter equipment never places it ahead or teleports player")
	await capture("scooter_equipped")
	player._open_inventory()
	var equip_buttons = player._panel_box.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("action_label",button.text)) == "EQUIPAGGIA" and not button.disabled)
	check(equip_buttons.size() == int(GameState.team_upgrade_levels.tool) + 1, "all owned hand tools remain selectable while scooter is equipped")
	equip_buttons[0].pressed.emit()
	check(player._mounted_vehicle == null and not scooter.visible and not player._is_paused, "inventory equip button puts scooter away and returns to walking")
	player._toggle_scooter()
	var start: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(player.position.distance_to(start) > 4 and not scooter.parked, "vehicle accelerates and moves using player collision")
	Input.action_press("move_left")
	await frames(20)
	Input.action_release("move_left")
	check(absf(player._vehicle_heading) > 0.05, "vehicle steering changes heading")
	player._dismount_vehicle()
	check(not scooter.visible and scooter.body.collision_layer == 0 and player._mounted_vehicle == null and is_equal_approx(player.camera.position.y, 1.6), "unequipping scooter removes it and restores walking")
	await frames(3)
	player._toggle_scooter()
	check(player._mounted_vehicle == scooter, "scooter can be equipped again in place")
	player._equip_tool(0)
	check(player._mounted_vehicle == null and not scooter.visible, "selecting an ordinary tool automatically puts scooter away")
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(item): return item.level == 2)[0]
	player.position = buggy.position + Vector3(2, 0, 0)
	check(player._mount_vehicle(buggy), "utility buggy can be mounted after purchase")
	start = player.position
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(player.position.distance_to(start) > 4 and player.camera.position.distance_to(buggy.visual.position + buggy.visual.basis * Vector3(0,1.94,-0.075)) < 0.001, "buggy moves and driver camera stays attached to physical seat")
	player._dismount_vehicle()
	check(SaveService.save_checkpoint(99), "vehicle progression checkpoint saves")
	GameState.vehicle_level = 0
	check(SaveService.load_save(99) and GameState.vehicle_level == 2, "vehicle ownership reloads")
	var malformed: Dictionary = GameState.serialize().duplicate(true)
	malformed.vehicle_level = 3
	check(not SaveService._validate_save_schema(malformed), "invalid vehicle progression rejected")
	malformed.vehicle_level = 2
	malformed.yard_level = 0
	check(not SaveService._validate_save_schema(malformed), "save validation enforces buggy land prerequisite")
	await test_workshop_discovery(player)

func test_workshop_discovery(player: Node3D) -> void:
	player._equip_tool(0)
	var pile = get_tree().get_nodes_in_group("landfill_piles")[0]
	for material_id in GameState.player_inventories[1]:
		GameState.player_inventories[1][material_id] = 0
	check(pile.can_start_collection() and pile.commit_stage(1).success, "pile rummaging recovers a material batch")
	check(not pile.can_start_collection() and not pile.commit_stage(1).success and GameState.get_inventory_mass(1) == 3, "searched pile cannot duplicate its hidden reward")
	var second_pile = get_tree().get_nodes_in_group("landfill_scenery")[0]
	player.position = second_pile.position + Vector3(0, 0, 8)
	player.velocity = Vector3.ZERO
	await frames(8)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(second_pile.global_position + Vector3(0, 1.1, 5.3))
	player.look_rotation = Vector2(player.camera.rotation.x, player.camera.rotation.y)
	player.camera.rotation.y = 0
	await frames(2)
	Input.action_press("collect")
	await frames(35)
	check(player._collecting and player._target_scrap == second_pile, "holding on pile starts visible rummaging")
	await capture("pile_rummaging")
	await frames(220)
	Input.action_release("collect")
	check(not second_pile.can_start_collection() and GameState.get_inventory_mass(1) == 6, "held rummaging finishes once through player interaction")
	check(get_tree().get_nodes_in_group("hidden_salvage").size() == 30, "thirty collectible scraps are placed on pile surfaces")
	check(get_tree().get_nodes_in_group("buried_assemblies").size() == 3, "three dismantlable objects partially buried in piles")
	var hidden = get_tree().get_nodes_in_group("hidden_salvage")[0]
	check(hidden.position.y > 0.5, "hidden objects are elevated rather than scattered only on ground")
	await aim(player, hidden)
	check(player._target_scrap == hidden, "hidden pile scrap remains reachable by line of sight")
	await capture("hidden_scrap")
	var buried = get_tree().get_nodes_in_group("buried_assemblies")[0]
	await aim(player, buried)
	check(player._target_scrap == buried, "partially buried assembly remains reachable")
	await capture("buried_salvage")
	player.position = Vector3(4, 0, 18.5)
	player.velocity = Vector3.ZERO
	player.look_rotation = Vector2(0, PI)
	player.auto_workshop_zones = true
	await frames(10)
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(not player._is_paused and not get_tree().paused and player.position.z > 21, "walking into garage never opens a menu")
	player.position = Vector3(-18, 0, 22.2)
	player.velocity = Vector3.ZERO
	await frames(4)
	check(player._near_service() == "tools" and player._interact_prompt.text.contains("PREMI"), "nearby workbench displays explicit interaction prompt")
	var interact = InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	player._unhandled_input(interact)
	check(player._is_paused, "pressing interact opens only the nearby service")
	var monitor = player._upgrade_monitor
	check(monitor.active and monitor.focus_camera.current and player._pause_menu == null, "upgrades live on physical monitor rather than a popup window")
	if DisplayServer.get_name() != "headless":
		await test_monitor_pointer(player, monitor)
	await capture("workshop_tablet_menu")
	player._close_pause_menu()
	await frames(10)
	check(not player._is_paused and player.camera.current and not monitor.active, "closing physical monitor restores player camera without reopening")
	player.auto_workshop_zones = false
	player.position = Vector3(-18, 0, 24.5)
	player.look_rotation = Vector2(-0.15, PI)
	await frames(3)
	await capture("workshop_interior")
	player.position = Vector3(-18, 0, 22.2)
	player.look_rotation = Vector2(-0.1, PI)
	await frames(4)
	check(player._interact_prompt.visible and player._interact_prompt.global_position.distance_to(monitor.global_position + Vector3.UP * 2.85) < 0.01, "press E prompt floats above the monitor in world space")
	await capture("monitor_world_prompt")
	await test_equipment_and_bonus(player)
	await test_expanded_world(player)
func test_equipment_and_bonus(player: Node3D) -> void:
	var original: Dictionary = GameState.serialize().duplicate(true)
	GameState.team_upgrade_levels.tool = 2
	player._equip_tool(0)
	var hands: float = GameState.recovery_seconds("metal", 0)
	player._equip_tool(1)
	var precision: float = GameState.recovery_seconds("electronics", 1)
	player._equip_tool(2)
	check(GameState.recovery_seconds("metal", 2) < hands and precision < GameState.recovery_seconds("electronics", 0) and not GameState.recovery_allowed("electronics", 2), "specialist tools improve their own materials and cannot replace each other")
	player._open_inventory()
	await capture("equipment_inventory")
	player._close_pause_menu()
	player.position = Vector3(15, 0, 25)
	check(player._interact_prompt is Label3D and player._interact_prompt.get_parent() == get_tree().current_scene, "interaction prompt is anchored in 3D rather than a fixed HUD label")
	check(player._near_service() == "vehicles" and not player._near_garage(), "vehicle kiosk separated from tools")
	player._open_vehicle_shop()
	await capture("vehicle_kiosk")
	player._close_pause_menu()
	player.position = Vector3(-26, 0, 21)
	check(player._near_service() == "land", "land planning terminal separated from tools and vehicles")
	player._open_land()
	await capture("land_terminal")
	player._close_pause_menu()
	var bonus_path: String = SaveService.SAVE_DIR + "owner_bonus.json"
	for id in GameState.player_inventories[1]:
		GameState.player_inventories[1][id] = 0
	var target = get_tree().get_nodes_in_group("scrap").filter(func(item): return item.scrap_type == 0)[0]
	player._equip_tool(2)
	await aim(player, target)
	Input.action_press("collect")
	await frames(12)
	await capture("hammer_collecting")
	var hold_frames: int = ceili(GameState.recovery_seconds("metal", 2) * 60) - 10
	await frames(maxi(1, hold_frames))
	Input.action_release("collect")
	check(GameState.get_inventory_mass(1) == 2, "equipped hammer completes collection into the material bag")
	if DisplayServer.get_name() != "headless":
		check(is_instance_valid(player._held_tool) and player._tool_visual_level == 2, "equipped hammer has a first person animated model")
		check(not get_tree().get_nodes_in_group("collection_fx").is_empty(), "successful collection spawns a visual pull effect")
	await capture("collection_pull")
	await frames(25)
	check(get_tree().get_nodes_in_group("collection_fx").is_empty(), "collection effects clean up without leaving nodes")
	var file = FileAccess.open(bonus_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"id":"isolated_bonus_test", "amount":2000}))
	file.close()
	var before: int = GameState.team_credits
	check(SaveService.apply_pending_owner_bonus() and GameState.team_credits == before + 2000, "requested 2000 bonus applied and saved")
	check(SaveService.apply_pending_owner_bonus() and GameState.team_credits == before + 2000, "bonus receipt prevents repeat credit")
	var bonus_checkpoint = SaveService.list_saves().filter(func(entry): return entry.slot == 0 and entry.credits == before + 2000)[0]
	check(SaveService.load_save(0, bonus_checkpoint.timestamp) and SaveService.apply_pending_owner_bonus() and GameState.team_credits == before + 2000, "bonus remains single after loading")
	var queue_file = FileAccess.open(bonus_path, FileAccess.WRITE)
	queue_file.store_string(JSON.stringify({"grants":[{"id":"isolated_bonus_test", "amount":2000}, {"id":"isolated_extra_20k", "amount":20000}]}))
	queue_file.close()
	check(SaveService.apply_pending_owner_bonus() and GameState.team_credits == before + 22000, "additional 20k grant preserves prior receipt and credits only the extra amount")
	check(SaveService.apply_pending_owner_bonus() and GameState.team_credits == before + 22000, "queued owner bonuses cannot repeat")
	GameState.deserialize(original)
	player._equipped_tool = -1
func test_monitor_pointer(player: Node3D, monitor: Node3D) -> void:
	var snapshot: Dictionary = GameState.serialize().duplicate(true)
	GameState.team_credits = 5000
	GameState.team_upgrade_levels.bag = 0
	monitor.build_screen()
	await frames(4)
	var button: Button = monitor.buy_buttons["bag"]
	var ui_point: Vector2 = button.get_global_rect().get_center()
	var uv: Vector2 = ui_point / Vector2(monitor.UI_SIZE)
	var world: Vector3 = monitor.screen.to_global(Vector3((uv.x - 0.5) * monitor.SCREEN_SIZE.x, (0.5 - uv.y) * monitor.SCREEN_SIZE.y, 0))
	var pointer: Vector2 = monitor.focus_camera.unproject_position(world)
	var mapped = monitor.map_pointer(pointer)
	check(mapped != null and mapped.distance_to(ui_point) < 1, "monitor maps real screen pointer onto its physical display")
	var motion = InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	monitor._input(motion)
	await frames(2)
	var click = InputEventMouseButton.new()
	click.position = pointer
	click.global_position = pointer
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	monitor._input(click)
	await frames(2)
	click.pressed = false
	monitor._input(click)
	await frames(4)
	check(GameState.team_upgrade_levels.bag == 1 and GameState.team_credits == 4750, "clicking physical monitor buys upgrade once through economy service")
	GameState.deserialize(snapshot)
	monitor.build_screen()
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	monitor._input(escape)
	check(not player._is_paused and player.camera.current, "escape leaves monitor and restores normal controls")
	player._open_development()
	await frames(3)
func test_expanded_world(player: Node3D) -> void:
	player._close_pause_menu()
	var sector = get_tree().current_scene
	GameState.team_credits = 5000
	GameState.team_upgrade_levels.tool = 2
	for level in range(GameState.yard_level, 2):
		for id in GameState.land_defs[level].project_materials:
			GameState.team_deposit_counts[id] = GameState.land_defs[level].project_materials[id]
		check(GameState.purchase_land(), "lot project purchase in current expedition succeeds")
	sector.apply_land_expansions()
	check(get_tree().get_nodes_in_group("unlocked_lots").size() == 2 and get_tree().get_nodes_in_group("field_depot").filter(func(node):return node.get_parent().is_in_group("unlocked_lots")).size() == 2, "two large expansion compounds and outposts are accessible")
	check(sector.get_node("GarageShellBack").position == Vector3(4, 2.25, 28) and sector.get_node("OfficeBack").position.x == -18, "garage retains original position while house office forms separate hub zone")
	check(get_tree().get_first_node_in_group("industrial_press").position == Vector3(-10, 0, 14), "production relocated beside the central scale")
	var depot = get_tree().get_nodes_in_group("field_depot")[0]
	player.position = depot.global_position + Vector3(0, 0, 2)
	for id in GameState.player_inventories[1]:
		GameState.player_inventories[1][id] = 0
	InventoryService.add_item(1, "metal")
	var before: int = GameState.team_deposit_counts.metal
	var credits: int = GameState.team_credits
	player._open_field_depot()
	player._deposit_field()
	check(GameState.get_inventory_mass(1) == 0 and GameState.team_deposit_counts.metal == before + 1 and GameState.team_credits == credits, "satellite depot conserves materials without selling them")
	player._deposit_field()
	check(GameState.team_deposit_counts.metal == before + 1 and GameState.team_credits == credits, "repeating satellite transfer cannot duplicate")
	await capture("satellite_depot")
	player._close_pause_menu()
	var terrain = preload("res://scripts/gameplay/desert_world.gd")
	player.position = Vector3(280, terrain.height_at(Vector3(280, 0, 180)) + 1, 180)
	await frames(80)
	check(player.is_on_floor() and sector.get_node("WorldEdgeX1").position.x == 639, "expanded 1280 metre world has real terrain beyond old boundary")
	check(get_tree().get_nodes_in_group("world_secrets").size() == 3, "three unique easter eggs populate the outer dunes")
	var secret = get_tree().get_nodes_in_group("world_secrets")[0]
	player.position = secret.global_position + Vector3(0, 0, 2)
	await frames(15)
	player._discover_nearest()
	check(secret.secret_id in GameState.secrets_found, "nearby easter egg can be discovered with interaction")
	credits = GameState.team_credits
	check(not secret.discover() and GameState.team_credits == credits, "discovery reward only credited once")
	await capture("curiosity_album")
	player._close_pause_menu()
	for other in get_tree().get_nodes_in_group("world_secrets"):
		if other == secret:
			continue
		player.position = other.global_position + Vector3(0, 0, 2)
		await frames(15)
		player._discover_nearest()
		check(other.secret_id in GameState.secrets_found, "outer landmark discoverable: " + other.secret_id)
		player._close_pause_menu()
		await capture_curiosity(player, other)
	check(SaveService.save_checkpoint(98), "discovery album checkpoint saves")
	GameState.secrets_found = []
	check(SaveService.load_save(98) and GameState.secrets_found.size() == 3 and secret.secret_id in GameState.secrets_found, "complete discovery album persists after loading")
	var bad: Dictionary = GameState.serialize().duplicate(true)
	bad.secrets_found.append("unknown_relic")
	check(not SaveService._validate_save_schema(bad), "unknown discovery IDs rejected on load")
	await test_tool_roles_and_orders(player)
	if DisplayServer.get_name() != "headless":
		var overview = Camera3D.new()
		sector.add_child(overview)
		overview.position = Vector3(45, 28, -9)
		overview.look_at(Vector3(-3, 0, 24))
		overview.make_current()
		player.get_node("HUD").hide()
		await capture("hub_overview")
		overview.position = Vector3(-9, 6, 11)
		overview.look_at(Vector3(-18, 1.7, 24))
		await capture("office_front")
		overview.position = Vector3(195, 48, 45)
		overview.look_at(Vector3(170, 0, -25))
		await capture("expanded_lots")
		overview.position = secret.global_position + Vector3(5, 4, -8)
		overview.look_at(secret.global_position + Vector3.UP)
		await capture("dune_curiosity")
		player.camera.make_current()
		player.get_node("HUD").show()
		overview.queue_free()

func capture_curiosity(player: Node3D, secret: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	player.set_physics_process(false)
	player._interact_prompt.hide()
	var camera = Camera3D.new()
	get_tree().current_scene.add_child(camera)
	camera.position = secret.global_position + Vector3(10, 7, -12)
	camera.look_at(secret.global_position + Vector3(2, 3, 1))
	camera.make_current()
	player.get_node("HUD").hide()
	await capture("curiosity_" + secret.secret_id)
	player.camera.make_current()
	player.get_node("HUD").show()
	player.set_physics_process(true)
	camera.queue_free()
func test_tool_roles_and_orders(player: Node3D) -> void:
	player._close_pause_menu()
	GameState.team_upgrade_levels.tool = 2
	for id in GameState.player_inventories[1]:
		GameState.player_inventories[1][id] = 0
	check(GameState.recovery_allowed("copper", 1) and not GameState.recovery_allowed("copper", 2), "copper requires precision tool even when hammer is owned")
	check(GameState.recovery_allowed("glass", 2) and not GameState.recovery_allowed("glass", 1), "glass needs hammer instead of screwdriver")
	var target = get_tree().get_nodes_in_group("scrap").filter(func(item): return item.scrap_type == 2)[0]
	# Tool-role fixture uses a clear lane; placement/occlusion are tested separately.
	target.position = Vector3(5,0.7,5)
	var target_id: String = target.entity_id
	player._equip_tool(2)
	await aim(player, target)
	Input.action_press("collect")
	await frames(170)
	Input.action_release("collect")
	check(is_instance_valid(target) and GameState.get_inventory_mass(1) == 0 and not player._collecting, "wrong tool cannot consume scrap or grant materials")
	await capture("wrong_tool_hint")
	player._equip_tool(1)
	Input.action_press("collect")
	await frames(100)
	Input.action_release("collect")
	check(GameState.player_inventories[1].electronics == 1, "switching to correct tool recovers the same object")
	check(not GameState.recover_world_scrap(1, target_id, "electronics", 1) and GameState.player_inventories[1].electronics == 1, "replaying collected world identity cannot duplicate materials")
	check(not GameState.recover_world_scrap(1, "electronics_999", "electronics", 1), "unknown world scrap identity cannot grant materials")
	check(not GameState.claim_salvage("tool_test", "generator", 0, 1, 2).success, "hammer cannot open generator electronics")
	check(GameState.claim_salvage("tool_test", "generator", 0, 1, 1).success, "screwdriver opens precision dismantling stage")
	check(not GameState.claim_salvage("tool_test", "generator", 1, 1, 2).success and GameState.claim_salvage("tool_test", "generator", 1, 1, 1).success, "later generator wiring still needs screwdriver after hammer purchase")
	for id in GameState.player_inventories[1]:
		GameState.player_inventories[1][id] = 0
	check(not GameState.claim_salvage("tool_test", "generator", 2, 1, 1).success and GameState.claim_salvage("tool_test", "generator", 2, 1, 2).success, "same object switches from precision tool to hammer for its base")
	GameState.completed_orders = []
	for id in GameState.team_deposit_counts:
		GameState.team_deposit_counts[id] = 0
	check(not GameState.complete_order("yard_restart"), "order rejects missing materials without consuming anything")
	for order in GameState.order_defs:
		for id in order.materials:
			GameState.team_deposit_counts[id] = int(order.materials[id])
		GameState.press_bales = int(order.bales)
		player.position = Vector3(-18, 0, 22.2)
		player._open_development()
		player._upgrade_monitor._set_page("orders")
		await frames(3)
		await capture("work_order_" + order.id)
		var balance: int = GameState.team_credits
		var bag: Dictionary = GameState.player_inventories[1].duplicate()
		var delivered: bool
		if DisplayServer.get_name() != "headless":
			var rectangle: Rect2 = player._upgrade_monitor.buy_buttons["order"].get_global_rect()
			check(rectangle.position.y >= 0 and rectangle.end.y <= player._upgrade_monitor.UI_SIZE.y, "order delivery button remains within physical screen: " + order.id)
			await click_physical_button(player._upgrade_monitor, player._upgrade_monitor.buy_buttons["order"])
			delivered = order.id in GameState.completed_orders
		else:
			delivered = GameState.complete_order(order.id)
		check(delivered and GameState.team_credits == balance + int(order.reward), "order consumes central deposit and rewards exact amount: " + order.id)
		var consumed: bool = true
		for id in order.materials:
			consumed = consumed and int(GameState.team_deposit_counts[id]) == 0
		check(consumed, "order consumes exactly the requested deposit items")
		check(GameState.player_inventories[1] == bag and GameState.press_bales == 0, "order preserves bag and consumes required bales")
		check(not GameState.complete_order(order.id) and GameState.team_credits == balance + int(order.reward), "same order cannot credit twice")
		player._close_pause_menu()
	check(SaveService.save_checkpoint(97), "completed work orders checkpoint saves")
	player._open_development()
	player._upgrade_monitor._set_page("orders")
	await capture("certified_yard_complete")
	player._close_pause_menu()
	GameState.completed_orders = []
	check(SaveService.load_save(97) and GameState.completed_orders.size() == GameState.order_defs.size(), "work order progress persists")
	var malformed: Dictionary = GameState.serialize().duplicate(true)
	malformed.completed_orders = ["precision_supply"]
	check(not SaveService._validate_save_schema(malformed), "out of sequence or unknown orders rejected")
	var legacy: Dictionary = GameState.serialize().duplicate(true)
	legacy.erase("completed_orders")
	check(GameState.deserialize(legacy) and GameState.completed_orders.is_empty() and GameState.owns_tool(1) and GameState.owns_tool(2), "legacy equipment levels migrate into both complementary tools")
	check(SaveService.load_save(97) and GameState.completed_orders.size() == GameState.order_defs.size(), "saved order receipts restore after legacy compatibility check")
	player._upgrade_monitor.active_page = "tools"
	player._equip_tool(0)
func click_physical_button(monitor: Node3D, button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var uv: Vector2 = point / Vector2(monitor.UI_SIZE)
	var world: Vector3 = monitor.screen.to_global(Vector3((uv.x - 0.5) * monitor.SCREEN_SIZE.x, (0.5 - uv.y) * monitor.SCREEN_SIZE.y, 0))
	var pointer: Vector2 = monitor.focus_camera.unproject_position(world)
	var motion = InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	monitor._input(motion)
	await frames(2)
	var click = InputEventMouseButton.new()
	click.position = pointer
	click.global_position = pointer
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	monitor._input(click)
	await frames(2)
	click.pressed = false
	monitor._input(click)
	await frames(4)
func test_vehicle_refit(player: Node3D) -> void:
	player._close_pause_menu()
	GameState.vehicle_level = 2
	GameState.yard_level = 2
	GameState.workshop_modules.clear()
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var scooter = get_tree().get_nodes_in_group("yard_vehicles").filter(func(v): return v.level == 1)[0]
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(v): return v.level == 2)[0]
	player.position = Vector3(14,0,65)
	player.look_rotation = Vector2.ZERO
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await frames(8)
	Input.action_press("move_forward")
	await frames(12)
	var walking_speed: float = player.velocity.length()
	player._toggle_scooter()
	check(player._mounted_vehicle == scooter and player._vehicle_speed > walking_speed * 0.9, "equipping scooter inherits existing forward momentum")
	await frames(30)
	Input.action_release("move_forward")
	var coast_start: Vector3 = player.position
	var initial_speed: float = player._vehicle_speed
	await frames(10)
	check(player.position.distance_to(coast_start) > 0.3 and player._vehicle_speed > initial_speed * 0.7, "releasing throttle coasts instead of stopping instantly")
	Input.action_press("move_back")
	await frames(16)
	Input.action_release("move_back")
	check(player._vehicle_speed < initial_speed - 2, "opposite throttle provides strong braking")
	var floor_height: float = player.position.y
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	check(player.position.y > floor_height + 0.25 and not player.is_on_floor(), "scooter mapped jump lifts rider and vehicle")
	var first_up: float = player.velocity.y
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(player.velocity.y < first_up, "airborne jump cannot stack vertical impulses")
	await capture("scooter_jump")
	await frames(100)
	check(player.is_on_floor() and absf(player.position.y) < 0.2, "scooter lands on physical terrain without sinking: %s floor=%s" % [player.position,player.is_on_floor()])
	player._open_pause_menu()
	var paused_position: Vector3 = player.position
	await frames(10)
	check(player.position == paused_position, "pause freezes vehicle drivetrain and suspension")
	player._close_pause_menu()
	player._dismount_vehicle()
	# Test the actual outdoor collision surface, not the analytical height alone.
	var desert = preload("res://scripts/gameplay/desert_world.gd")
	player.position = Vector3(-40,desert.height_at(Vector3(-40,0,145)) + 0.05,145)
	player.velocity = Vector3.ZERO
	player.look_rotation = Vector2(0,PI)
	player.rotation.y = PI
	await frames(25)
	player._toggle_scooter()
	check(player._mounted_vehicle == scooter, "scooter equips on exterior dune slope")
	await frames(12)
	check(player._vehicle_motion.chassis_up.distance_to(Vector3.UP) > 0.02 and player.camera.transform.basis.y.dot(scooter.visual.basis.y) > 0.999, "rider camera inherits dune pitch and roll from scooter")
	check(player.camera.position.distance_to(scooter.visual.position + scooter.visual.basis * Vector3(0,1.7,0)) < 0.001, "camera position follows tilted rider seat rather than upright character origin")
	Input.action_press("move_forward")
	await frames(75)
	Input.action_release("move_forward")
	var ground_query = PhysicsRayQueryParameters3D.create(player.position + Vector3.UP,player.position - Vector3.UP * 3,1,[player.get_rid(),scooter.body.get_rid()])
	var dune_hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ground_query)
	check(not dune_hit.is_empty() and player.position.y - dune_hit.position.y < 0.7, "riding dune maintains real ground contact")
	await capture("rider_dune_view")
	await capture_vehicle_external(player, scooter, "scooter_dunes")
	player._dismount_vehicle()
	buggy.position = Vector3(-40, desert.height_at(Vector3(-40,0,165)),165)
	player.position = buggy.position + Vector3(2,0.2,0)
	await frames(5)
	check(player._mount_vehicle(buggy), "buggy mounts with full size collision chassis")
	check(player.collision.shape is BoxShape3D and player.collision.shape.size.z > 2.5, "buggy collision spans raised chassis rather than pedestrian capsule")
	await frames(20)
	check(player._vehicle_motion.chassis_up.distance_to(Vector3.UP) > 0.02, "buggy axle contacts follow irregular ground")
	var buggy_ground_query = PhysicsRayQueryParameters3D.create(player.position + Vector3.UP * 2, player.position - Vector3.UP * 2,1,[player.get_rid(),buggy.body.get_rid()])
	var buggy_ground: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(buggy_ground_query)
	check(not buggy_ground.is_empty() and player.position.y - buggy_ground.position.y > -0.08 and player.position.y - buggy_ground.position.y < 1, "buggy support collision keeps wheels above dune surface")
	check(not buggy_ground.is_empty() and absf(buggy.visual.global_position.y - buggy_ground.position.y) < 0.15, "chassis suspension settles at wheel contact height instead of floating")
	await capture_vehicle_external(player, buggy, "buggy_dunes")
	player._dismount_vehicle()
	check(player._mounted_vehicle == null and player.collision.shape is CapsuleShape3D, "safe buggy exit restores walking collision")
	await frames(24)
	check(is_equal_approx(player.camera.position.y,1.6) and absf(player.camera.rotation.z) < 0.001, "leaving vehicle restores upright walking view and eye position")
	# A real barrier stops the chassis; drivetrain cannot accumulate hidden speed.
	var barrier = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(6,4,0.5)
	barrier.add_child(shape)
	get_tree().current_scene.add_child(barrier)
	barrier.position = Vector3(14,2,57)
	player.position = Vector3(14,0,65)
	player.velocity = Vector3.ZERO
	player.look_rotation = Vector2.ZERO
	player.rotation.y = 0
	await frames(8)
	player._toggle_scooter()
	Input.action_press("move_forward")
	await frames(150)
	Input.action_release("move_forward")
	check(player.position.z > 57.4 and absf(player._vehicle_speed) < 1, "collision blocks scooter and removes drivetrain speed: %s speed=%.3f" % [player.position,player._vehicle_speed])
	player._dismount_vehicle()
	barrier.queue_free()
	player.position = Vector3(0,0,12)
	player.velocity = Vector3.ZERO
	await frames(8)

func capture_vehicle_external(player: Node3D, vehicle: Node3D, filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var overview = Camera3D.new()
	get_tree().current_scene.add_child(overview)
	overview.position = player.position + Vector3(4,2.7,5)
	overview.look_at(player.position + Vector3(0,0.7,0))
	overview.make_current()
	await capture(filename)
	overview.queue_free()
	player.camera.make_current()

func test_workshop_modules(player: Node3D) -> void:
	GameState.team_credits = 20000
	GameState.workshop_modules.clear()
	GameState.completed_orders.clear()
	check(not GameState.purchase_module("motor"), "module progression requires completed work order")
	GameState.completed_orders = ["yard_restart"]
	GameState.vehicle_level = 0
	check(not GameState.purchase_module("motor"), "transmission cannot be bought without owning vehicle")
	GameState.vehicle_level = 2
	GameState.press_owned = true
	GameState.team_upgrade_levels.tool = 2
	var save_directory: String = SaveService.SAVE_DIR
	var before_failure: Dictionary = GameState.serialize().duplicate(true)
	SaveService.SAVE_DIR = "res://project.godot/"
	var print_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false # Intentional I/O failure; assertion below checks rollback.
	var failed_purchase: bool = GameState.purchase_module("motor")
	Engine.print_error_messages = print_errors
	SaveService.SAVE_DIR = save_directory
	check(not failed_purchase and GameState.team_credits == before_failure.team_credits and GameState.workshop_modules == before_failure.workshop_modules, "failed checkpoint rolls back module ownership and full purchase cost")
	var original: int = GameState.team_credits
	for id in ["motor","suspension","workbench","press_drive","cargo_rack"]:
		check(GameState.purchase_module(id), "first workshop module installs: " + id)
		check(not GameState.purchase_module(id), "second module level waits for industrial order: " + id)
	check(GameState.team_credits == original - 2400, "module upgrades charge exact costs once")
	check(GameState.module_effect("motor") > 1 and GameState.module_effect("suspension") > 1 and is_equal_approx(GameState.press_cycle_seconds(),4.5), "installed modules alter driving and actual press recipe duration")
	GameState.completed_orders = ["yard_restart","precision_supply","industrial_delivery"]
	player.position = Vector3(-18,0,22.2)
	player._open_development()
	player._upgrade_monitor._set_page("modules")
	await frames(3)
	await capture("workshop_modules")
	if DisplayServer.get_name() != "headless":
		await click_physical_button(player._upgrade_monitor,player._upgrade_monitor.buy_buttons.motor)
		check(GameState.workshop_modules.motor == 2, "physical monitor module button buys through validated service")
	else:
		check(GameState.purchase_module("motor"), "second transmission level installs after industrial order")
	player._close_pause_menu()
	for id in ["suspension","workbench","press_drive"]:
		check(GameState.purchase_module(id), "second workshop module installs: " + id)
	check(not GameState.purchase_module("motor"), "maxed module cannot charge again")
	check(is_equal_approx(GameState.press_cycle_seconds(),3.0) and is_equal_approx(GameState.module_effect("workbench"),0.7), "production and precision upgrades use distinct concrete effects")
	GameState.press_remaining = 0
	GameState.press_bales = 0
	GameState.team_deposit_counts.metal = 5
	check(GameState.start_press() and is_equal_approx(GameState.press_remaining,3.0), "upgraded press reserves real batch with shorter production timer")
	await frames(210)
	check(GameState.press_bales == 1 and GameState.team_deposit_counts.metal == 0, "upgraded press produces exactly one bale with same material cost")
	var fixture = GameState.serialize().duplicate(true)
	check(SaveService.save_checkpoint(96), "workshop module checkpoint saves")
	GameState.workshop_modules.clear()
	check(SaveService.load_save(96) and GameState.workshop_modules.size() == 5 and GameState.workshop_modules.motor == 2, "all workshop levels survive save and load")
	fixture.workshop_modules.motor = 2.5
	check(not SaveService._validate_save_schema(fixture), "fractional module progression rejected")
	fixture.workshop_modules = {"unknown":1}
	check(not SaveService._validate_save_schema(fixture), "unknown module rejected without replacing save")
	fixture.erase("workshop_modules")
	check(GameState.deserialize(fixture) and GameState.module_effect("motor") == 1, "older checkpoints load with stock vehicles and no modules")
	check(SaveService.load_save(96), "saved module checkpoint restores after compatibility test")
	GameState.team_upgrade_levels.bag = 2
	check(EconomyService.purchase_upgrade("bag") and GameState.get_inventory_capacity(1) == 55, "new expedition bag expands capacity to 55 kg")
	check(EconomyService.purchase_upgrade("bag") and GameState.get_inventory_capacity(1) == 70, "final transport bag reaches 70 kg")
	GameState.team_credits=20000
	check(EconomyService.purchase_upgrade("bag") and GameState.get_inventory_capacity(1)==90,"advanced transport bag reaches 90 kg")
	check(EconomyService.purchase_upgrade("bag") and GameState.get_inventory_capacity(1)==110,"maximum transport bag reaches 110 kg")
	check(not EconomyService.purchase_upgrade("bag"), "bag cannot exceed catalog maximum")
	var balance: int = GameState.team_credits
	var deposits: Dictionary = GameState.team_deposit_counts.duplicate()
	GameState.vehicle_level = 1
	check(not GameState.complete_order("fleet_service") and GameState.team_credits == balance and GameState.team_deposit_counts == deposits, "fleet objective cannot bypass buggy requirement or consume deposits")
	GameState.vehicle_level = 2
func test_world_rework(player: Node3D) -> void:
	var motion = preload("res://scripts/gameplay/vehicle_motion.gd")
	var random = RandomNumberGenerator.new()
	random.seed = 11932
	var normal = Vector3.UP
	var stable: bool = true
	for index in 30000:
		var magnitude: float = pow(10.0,random.randf_range(-10,-1))
		var target = Vector3(random.randf_range(-1,1)*magnitude,1,random.randf_range(-1,1)*magnitude).normalized()
		normal = motion.smooth_contact_up(normal,target,random.randf())
		stable = stable and normal.is_finite() and absf(normal.length_squared()-1) < 0.00001
	check(stable, "30000 almost parallel suspension normals stay finite and normalized without rotation axes")
	var arrival = get_tree().get_first_node_in_group("arrival_area")
	check(arrival != null and player.position.distance_to(arrival.global_position) < 0.3, "spawn starts grounded on dedicated arrival pad outside service collisions")
	check(get_tree().get_nodes_in_group("starter_salvage").size() == 3 and get_tree().get_nodes_in_group("scrap").size() == 120, "starter sorting bench reuses three existing scraps without inflating economy")
	await capture("arrival_spawn")
	var names: Dictionary = {}
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	for type in 7:
		for variant in 3:
			names[catalog.item_name(type,variant)] = true
	check(names.size() == 21, "seven materials each expose three distinct named object variants")
	for family in ["steel","plastic","rubble","sand","rubber"]:
		var valid: bool = true
		for map in ["albedo","roughness","normal"]:
			valid = valid and FileAccess.file_exists("res://assets/textures/surfaces/%s_%s.png" % [family,map])
		check(valid, "authored surface maps present: " + family)
	var layout = preload("res://scripts/gameplay/landfill_layout.gd")
	var definitions: Dictionary = {}
	for pile in get_tree().get_nodes_in_group("landfill_piles"):
		definitions[pile.definition_id] = true
	check(definitions.size() == 5, "heap families have distinct recovery recipes and tool roles")
	var pile = get_tree().get_nodes_in_group("landfill_piles")[0]
	for angle in [0.3,1.7,3.5,5.2]:
		var local = Vector3(cos(angle)*4.7,0,sin(angle)*4.7)
		var position: Vector3 = pile.global_position + local
		var query = PhysicsRayQueryParameters3D.create(position+Vector3.UP*10,position-Vector3.UP,1,[player.get_rid()])
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y-layout.surface_height(local,0)) < 0.15, "irregular heap rendered profile matches physical recovery surface %.1f" % angle)
	var old_bag: Dictionary = GameState.player_inventories[1].duplicate()
	var old_tools: int = GameState.team_upgrade_levels.tool
	GameState.team_upgrade_levels.tool = 2
	for id in ["pile_plastic","pile_electronics","pile_rubble","pile_metal"]:
		for material in GameState.player_inventories[1]:
			GameState.player_inventories[1][material] = 0
		var definition: Dictionary = GameState.salvage_defs[id].steps[0]
		var tool: int = int(definition.tool)
		check(not GameState.claim_salvage("thematic_"+id,id,0,1,(tool+1)%3).success, "thematic pile rejects wrong tool: " + id)
		var result: Dictionary = GameState.claim_salvage("thematic_"+id,id,0,1,tool)
		check(result.success and result.materials == definition["yield"], "thematic pile yields exact dedicated materials: " + id)
		check(not GameState.claim_salvage("thematic_"+id,id,0,1,tool).success, "thematic pile cannot repeat reward: " + id)
	GameState.player_inventories[1] = old_bag
	GameState.team_upgrade_levels.tool = old_tools
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--capture"):
		player.get_node("HUD").hide()
		var camera = Camera3D.new()
		get_tree().current_scene.add_child(camera)
		camera.position = pile.global_position+Vector3(9,6,10)
		camera.look_at(pile.global_position+Vector3.UP*1.8)
		camera.make_current()
		await capture("heap_reworked")
		var gallery = Node3D.new()
		gallery.position = Vector3(-60,25,0)
		get_tree().current_scene.add_child(gallery)
		var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
		art.box(gallery,Vector3(12,0.12,5.5),Vector3(0,-0.1,0),Color("#908878"))
		for type in 7:
			for variant in 3:
				var item = Node3D.new()
				item.position = Vector3(-4.8+type*1.6,0, -1.5+variant*1.5)
				gallery.add_child(item)
				catalog.build(item,type,variant,art)
		camera.position = gallery.global_position+Vector3(4,5.5,-8)
		camera.look_at(gallery.global_position+Vector3.UP*0.2)
		await capture("scrap_catalog")
		camera.position = gallery.global_position+Vector3(-3.2,2.0,-3.9)
		camera.look_at(gallery.global_position+Vector3(-3.2,0.25,0))
		await capture("plastic_objects")
		gallery.queue_free()
		camera.queue_free()
		player.camera.make_current()
		player.get_node("HUD").show()







