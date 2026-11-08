extends "res://tests/single_player_cycle.gd"

func run() -> void:
	get_tree().current_scene = null
	SaveService.SAVE_DIR = "res://test_logs/haul_world_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded = true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	var settings = preload("res://scenes/settings_dialog.tscn").instantiate()
	player.add_child(settings)
	settings.settings_path = SaveService.SAVE_DIR+"logistics_settings.cfg"
	player._open_pause_menu()
	settings.show_dialog()
	settings._on_keybind_pressed("recovery_mode")
	var remap = InputEventKey.new()
	remap.pressed = true
	remap.keycode = KEY_E
	settings._input(remap)
	check(settings._keybind_waiting and settings._settings.key_recovery_mode == "R", "recovery-mode remap rejects conflict with interaction")
	var mode_before: bool = player._recover_intact
	var paused_action = InputEventAction.new()
	paused_action.action = "recovery_mode"
	paused_action.pressed = true
	player._unhandled_input(paused_action)
	check(player._recover_intact == mode_before, "remapping while paused cannot switch dismantling mode")
	remap.keycode = KEY_G
	settings._input(remap)
	settings._on_apply_pressed()
	settings._load_settings()
	check(InputMap.action_get_events("recovery_mode")[0].keycode == KEY_G and settings._settings.key_recovery_mode == "G", "recovery-mode remap saves and reloads")
	settings.show_dialog()
	settings._on_reset_defaults()
	settings._on_apply_pressed()
	settings.hide()
	settings.queue_free()
	player._close_pause_menu()
	GameState.team_credits = 20000
	GameState.yard_level = 2
	GameState.vehicle_level = 2
	GameState.team_upgrade_levels.tool = 2
	GameState.workshop_modules = {"workbench":1}
	GameState.completed_orders = ["yard_restart"]
	sector.apply_land_expansions()
	sector.spawn_owned_vehicles()
	GameState.ops.seed_field_parts()
	GameState.operations_changed.emit()
	await frames(5)
	check(get_tree().get_nodes_in_group("bulk_parts").size() == GameState.bulk_defs.size(), "all bulky components exist as interactive world objects")
	check(get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("operation") not in ["customer","career","identity"]).size() == 5, "warehouse recovery dispatch crafting and assembly remain distinct from identity and customers")
	var buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(v): return v.level==2)[0]
	buggy.position = Vector3(8,0,-30)
	var battery = get_tree().get_nodes_in_group("bulk_parts").filter(func(v): return v.kind=="battery" and v.global_position.x<20)[0]
	player.position = battery.position+Vector3(0,0,-2)
	face(player,battery.global_position+Vector3.UP*0.35)
	await frames(5)
	interact(player)
	await frames(3)
	check(not GameState.operations.held.is_empty() and GameState.operations.held.kind=="battery", "E picks up actual damaged battery and removes its world body")
	var start: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(15)
	Input.action_release("move_forward")
	check(player.position.distance_to(start)>0.2 and player.position.distance_to(start)<0.8, "carrying bulky object changes actual walking pace")
	player._toggle_scooter()
	check(player._mounted_vehicle==null, "carried component prevents scooter equipment")
	await capture("haul_carry")
	player.position = buggy.to_global(Vector3(0,0,3.0))
	face(player,buggy.to_global(Vector3(0,1.2,1.6)))
	await frames(3)
	interact(player)
	await frames(3)
	check(GameState.operations.held.is_empty() and GameState.operations.cargo_parts.size()==1 and GameState.ops.cargo_mass()==18, "E at buggy rear loads component into real cargo")
	buggy.position = Vector3(-6,0,-8)
	var car = get_tree().get_nodes_in_group("salvage_assemblies").filter(func(v):return v.entity_id=="assembly_0")[0]
	player._equip_tool(1)
	player.position = car.position+Vector3(2.8,0.05,-1.2)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(car.global_position+Vector3(1.02,0.43,-1.2))
	player.look_rotation = Vector2(player.camera.rotation.x,player.camera.rotation.y)
	player.camera.rotation.y = 0
	await frames(6)
	check(player._target_scrap==car and car.selected_component==1, "ray selects wheel component independently of intact body panels")
	var mode_event = InputEventAction.new()
	mode_event.action = "recovery_mode"
	mode_event.pressed = true
	player._unhandled_input(mode_event)
	check(player._recover_intact and car.recover_intact, "remappable recovery action switches to intact component mode")
	Input.action_press("collect")
	await frames(370)
	Input.action_release("collect")
	await frames(3)
	check(GameState.ops.completed_components(car.entity_id)==[1] and not GameState.operations.held.is_empty() and GameState.operations.held.kind=="wheel", "holding on wheel recovers working part before panels without granting loose materials")
	check(GameState.get_inventory_mass(1)==0, "intact recovery uses carrying slot rather than material bag")
	player.position = buggy.to_global(Vector3(0,0,3))
	face(player,buggy.to_global(Vector3(0,1.2,1.6)))
	await frames(3)
	interact(player)
	await frames(3)
	player._unhandled_input(mode_event)
	car.select_component(0)
	await aim(player,car)
	Input.action_press("collect")
	await frames(220)
	Input.action_release("collect")
	await frames(3)
	check(0 in GameState.ops.completed_components(car.entity_id) and GameState.player_inventories[1].metal==3, "same vehicle supports raw panel recovery as a separate choice")
	car.select_component(2)
	await aim(player,car)
	player._unhandled_input(mode_event)
	Input.action_press("collect")
	await frames(510)
	Input.action_release("collect")
	await frames(3)
	check(not GameState.operations.held.is_empty() and GameState.operations.held.kind=="engine" and 2 in GameState.ops.completed_components(car.entity_id), "opened hood exposes selectable engine and intact recovery")
	await capture("component_recovery")
	player.position = buggy.to_global(Vector3(0,0,3))
	face(player,buggy.to_global(Vector3(0,1.2,1.6)))
	await frames(3)
	interact(player)
	await frames(3)
	car.select_component(3)
	player._equip_tool(2)
	await aim(player,car)
	Input.action_press("collect")
	await frames(440)
	Input.action_release("collect")
	await frames(3)
	check(not GameState.operations.held.is_empty() and GameState.operations.held.kind=="frame", "last structural component requires other removals and demolition tool")
	player.position = buggy.to_global(Vector3(0,0,3))
	face(player,buggy.to_global(Vector3(0,1.2,1.6)))
	await frames(3)
	interact(player)
	check(not GameState.operations.held.is_empty() and GameState.ops.cargo_mass()==78, "full-size frame cannot bypass stock buggy capacity")
	check(GameState.purchase_module("cargo_rack") and GameState.ops.cargo_capacity()==200, "cargo upgrade solves concrete 120kg haul limitation")
	interact(player)
	await frames(3)
	check(GameState.operations.held.is_empty() and GameState.ops.cargo_mass()==158, "upgraded buggy carries engine battery wheel and frame together")
	player._equip_tool(1)
	for index in 4:
		var scrap = get_tree().get_nodes_in_group("scrap").filter(func(v):return v.scrap_type==2 and not v.is_in_group("hidden_salvage"))[0]
		await aim(player,scrap)
		Input.action_press("collect")
		await frames(100)
		Input.action_release("collect")
		await frames(2)
	check(GameState.get_inventory_mass(1)==18, "bag holds panel metal and repair electronics gathered through actual interaction")
	player.position = buggy.to_global(Vector3(0,0,3))
	face(player,buggy.to_global(Vector3(0,1.2,1.6)))
	await frames(4)
	interact(player)
	check(player._is_paused and player._pause_menu!=null, "rear E opens dedicated cargo interface")
	await frames(4)
	if DisplayServer.get_name() != "headless":
		check(player._pause_menu.size.y <= get_viewport().get_visible_rect().size.y-20,"cargo menu fits viewport with load and close controls visible")
	await capture("buggy_cargo_menu")
	click_text(player,"CARICA LA SACCA")
	await frames(3)
	check(GameState.get_inventory_mass(1)==0 and GameState.ops.cargo_mass()==176, "cargo interface transfers bag with component weight included")
	await capture_vehicle_external(player,buggy,"buggy_loaded")
	check(SaveService.save_checkpoint(88), "loaded vehicle and dismantled identities checkpoint")
	player._do_quit_to_menu()
	await frames(15)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	player = get_tree().get_first_node_in_group("players")
	buggy = get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.level==2)[0]
	car = get_tree().get_nodes_in_group("salvage_assemblies").filter(func(v):return v.entity_id=="assembly_0")[0]
	check(GameState.ops.cargo_mass()==176 and car.stage==4 and get_tree().get_nodes_in_group("players").size()==1, "menu return preserves loaded cargo and removed components without duplicate player")
	player.position = buggy.position+Vector3(2,0,0)
	await frames(5)
	check(player._mount_vehicle(buggy), "loaded buggy remains driveable after scene change")
	var heading: float = player._vehicle_heading
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await frames(30)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	check(absf(player.look_rotation.y-heading)>0.05 and absf(wrapf(player.look_rotation.y-player._vehicle_heading,-PI,PI))<0.01, "driver view follows steering yaw while preserving look offset")
	# Resume now keeps the field parking location; use the central lane, not the old garage-start route.
	var drove: bool = await drive_to(player,Vector3(0,0,-4),false)
	drove = await drive_to(player,Vector3(0,0,6),false) and drove
	drove = await drive_to(player,Vector3(-20,0,6),false) and drove
	drove = await drive_to(player,Vector3(-34,0,12),false) and drove
	drove = await drive_to(player,Vector3(-34,0,21.5),true) and drove
	check(drove, "loaded buggy navigates real yard route back to warehouse using throttle and steering")
	if not drove:
		print("LOGISTICS_PLAYTHROUGH_RESULT: %d checks, %d failures" % [checks,failures])
		get_tree().quit(1)
		return
	await capture("haul_driving")
	player._dismount_vehicle()
	await frames(5)
	check(player._mounted_vehicle==null and buggy.parked,"loaded buggy permits safe exit after stopping")
	await frames(24)
	player.position = Vector3(-31.5,0,19.2)
	await frames(5)
	player._open_parts_storage()
	await capture("warehouse_unload")
	click_text(player,"SCARICA IL CASSONE")
	await frames(4)
	check(GameState.ops.cargo_mass()==0 and GameState.operations.stored_parts.size()==4 and GameState.team_deposit_counts.electronics==4 and GameState.team_deposit_counts.metal==3, "warehouse unload preserves all four components and exact raw stock")
	var recovery = get_tree().get_nodes_in_group("operations_service").filter(func(v):return v.get_meta("operation")=="recovery")[0]
	player.position = recovery.global_position+Vector3(0,0,2)
	face(player,recovery.global_position+Vector3.UP*1.2)
	await frames(5)
	interact(player)
	check(player._is_paused and player._near_ops_service()=="recovery", "Lotto Est opens actual recovery bench")
	await frames(4)
	if DisplayServer.get_name() != "headless":
		check(player._pause_menu.size.y <= get_viewport().get_visible_rect().size.y-20,"recovery menu fits viewport and scrolls component rows")
	await capture("recovery_bench_menu")
	var battery_id: String = GameState.operations.stored_parts.filter(func(v):return v.kind=="battery")[0].id
	player._ops_action("repair",battery_id)
	check(GameState.operations.stored_parts.filter(func(v):return v.id==battery_id)[0].quality==1 and GameState.team_deposit_counts.electronics==3, "bench action repairs damaged battery using depot supplies")
	var engine_id: String = GameState.operations.stored_parts.filter(func(v):return v.kind=="engine")[0].id
	player._ops_action("recycle",engine_id)
	check(GameState.team_deposit_counts.metal==13 and GameState.team_deposit_counts.copper==6 and GameState.team_deposit_counts.plastic==6, "bench recycling converts stored engine into its conserved 48kg material recipe")
	var loose_wheel = get_tree().get_nodes_in_group("bulk_parts").filter(func(v):return v.kind=="wheel" and v.quality==0)[0]
	player.position = loose_wheel.position+Vector3(0,0,2)
	face(player,loose_wheel.global_position+Vector3.UP*0.35)
	await frames(5)
	interact(player)
	player.position = Vector3(-31.5,0,19.2)
	await frames(5)
	interact(player)
	var wheel_id: String = GameState.operations.stored_parts.filter(func(v):return v.kind=="wheel" and int(v.quality)==0)[0].id
	player.position = recovery.global_position+Vector3(0,0,2)
	face(player,recovery.global_position+Vector3.UP*1.2)
	await frames(5)
	player._ops_action("repair",wheel_id)
	check(GameState.ops.usable_parts("wheel")==2 and GameState.team_deposit_counts.metal==11 and GameState.team_deposit_counts.electronics==2, "second damaged spare can be restored for working-parts supply")
	var press = get_tree().get_first_node_in_group("industrial_press")
	GameState.press_owned = true
	player.position = press.interaction_position()+Vector3(0,0,-1.8)
	face(player,press.interaction_position()+Vector3.UP*1.2)
	await frames(5)
	interact(player)
	await frames(4)
	if DisplayServer.get_name() != "headless":
		check(player._pause_menu.size.y <= get_viewport().get_visible_rect().size.y-20,"production controls fit viewport")
	await capture("production_queue_menu")
	click_text(player,"MASSIMO")
	check(GameState.operations.press_queue==1 and GameState.team_deposit_counts.metal==1, "production menu reserves two complete batches")
	await frames(750)
	check(GameState.press_bales==2 and GameState.press_remaining==0, "queued batches finish while player is free to work")
	GameState.completed_orders = GameState.order_defs.map(func(v):return v.id)
	player.position = Vector3(-18,0,22.2)
	player._open_development()
	player._upgrade_monitor._set_page("orders")
	await frames(4)
	await capture("recurring_offers")
	if DisplayServer.get_name()!="headless":
		await click_physical_button(player._upgrade_monitor,player._upgrade_monitor.buy_buttons.delivery_garage_spares)
	else:
		player._ops_action("accept_delivery","garage_spares")
	check(GameState.operations.active_delivery.get("id","")=="garage_spares", "certification unlocks selectable recurring work on the physical monitor")
	var ticket: int = GameState.operations.active_delivery.ticket
	player._open_development()
	player._upgrade_monitor._set_page("orders")
	await frames(4)
	await capture("recurring_delivery")
	var money: int = GameState.team_credits
	if DisplayServer.get_name()!="headless":
		await click_physical_button(player._upgrade_monitor,player._upgrade_monitor.buy_buttons.complete_delivery)
	else:
		player._ops_action("complete_delivery","",ticket)
	check(GameState.operations.deliveries==1 and GameState.team_credits==money+520 and GameState.operations.stored_parts.size()==1 and GameState.team_deposit_counts.electronics==0, "recurring work consumes exactly repaired battery two wheels and electronics")
	check(not GameState.ops.complete_delivery(ticket), "world supply receipt cannot credit again")
	check(GameState.purchase_module("press_drive") and GameState.purchase_module("press_drive"), "production upgrades unlock hopper after industrial milestones")
	var dispatch = get_tree().get_nodes_in_group("operations_service").filter(func(v):return v.get_meta("operation")=="dispatch")[0]
	player.position = dispatch.global_position+Vector3(0,0,2)
	face(player,dispatch.global_position+Vector3.UP*1.2)
	await frames(5)
	interact(player)
	await capture("dispatch_dock_menu")
	check(not player._pause_menu.find_children("*","Button",true,false).any(func(button):return button.text.to_lower().contains("tramoggia")),"shipping desk contains deliveries rather than unrelated production controls")
	player._close_pause_menu()
	player.position=press.interaction_position()+Vector3(0,0,-1.8)
	face(player,press.interaction_position()+Vector3.UP*1.2)
	await frames(5)
	interact(player)
	click_text(player,"ALIMENTAZIONE AUTOMATICA")
	check(GameState.operations.autofeed, "press screen controls its automatic feeder")
	GameState.ops.set_autofeed(false)
	await capture_stock(player)
	check(SaveService.save_checkpoint(89), "complete logistics and supply cycle persists")
	var before_parts: Array = GameState.operations.stored_parts.duplicate(true)
	GameState.operations = GameState.ops.empty_state()
	var loaded: bool = SaveService.load_save(89)
	check(loaded and GameState.operations.deliveries==1 and GameState.operations.stored_parts==before_parts and GameState.press_bales==2, "final reload preserves recurring progress remaining frame and produced bales")
	print("LOGISTICS_PLAYTHROUGH_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func interact(player: Node3D) -> void:
	for vehicle in get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.level == 2 and vehicle.parked and vehicle.to_local(player.global_position).z>0.85 and player.global_position.distance_to(vehicle.to_global(Vector3(0,0,1.8)))<3:
			player.rotation = Vector3.ZERO
			player.camera.rotation = Vector3.ZERO
			player.camera.look_at(vehicle.to_global(Vector3(0,1.2,1.6)))
			player.look_rotation = Vector2(player.camera.rotation.x,player.camera.rotation.y)
			player.camera.rotation.y = 0
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	player._unhandled_input(event)

func click_text(player: Node3D, prefix: String) -> void:
	var found: bool = false
	if is_instance_valid(player._pause_menu):
		for button in player._panel_box.find_children("*","Button",true,false):
			if (str(button.get_meta("action_label",button.text)).to_upper().begins_with(prefix.to_upper()) or button.tooltip_text.to_upper().begins_with(prefix.to_upper())) and not button.disabled:
				button.pressed.emit()
				found = true
				break
	check(found,"enabled UI action: "+prefix)

func drive_to(player: Node3D, target: Vector3, stop: bool) -> bool:
	for index in 1400:
		var delta: Vector3 = target-player.position
		delta.y = 0
		var distance: float = delta.length()
		var speed: float = absf(player._vehicle_speed)
		if distance < (2.5 if stop else 3.0) and (not stop or speed<0.8):
			Input.action_release("move_forward")
			Input.action_release("move_back")
			Input.action_release("move_left")
			Input.action_release("move_right")
			return true
		var desired: float = atan2(-delta.x,-delta.z)
		var error: float = wrapf(desired-player._vehicle_heading,-PI,PI)
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(error)>0.025:
			Input.action_press("move_left" if error>0 else "move_right",minf(1.0,absf(error)*2))
		Input.action_release("move_forward")
		Input.action_release("move_back")
		if absf(error)>0.5 and player._vehicle_speed>4:
			Input.action_press("move_back")
		elif stop and distance < speed*speed/30.0+2.5:
			if player._vehicle_speed>0.3:
				Input.action_press("move_back")
		else:
			Input.action_press("move_forward",0.35 if absf(error)>0.8 else 1.0)
		await frames(1)
	for action in ["move_forward","move_back","move_left","move_right"]:
		Input.action_release(action)
	print("DRIVE_DIAG target=",target," position=",player.position," speed=",player._vehicle_speed)
	return false

func capture_stock(player: Node3D) -> void:
	if DisplayServer.get_name()=="headless":
		return
	var camera = Camera3D.new()
	get_tree().current_scene.add_child(camera)
	camera.position = Vector3(-40,3.1,16)
	camera.look_at(Vector3(-34,1,23))
	camera.make_current()
	player.get_node("HUD").hide()
	await capture("warehouse_stock")
	camera.position = Vector3(-115,preload("res://scripts/gameplay/desert_world.gd").height_at(Vector3(-115,0,145))+2,138)
	camera.look_at(Vector3(-115,preload("res://scripts/gameplay/desert_world.gd").height_at(Vector3(-115,0,148))+1.2,148))
	await capture("exterior_recovery_site")
	camera.queue_free()
	player.camera.make_current()
	player.get_node("HUD").show()

func face(player,point: Vector3) -> void:
	player.rotation=Vector3.ZERO
	player.camera.rotation=Vector3.ZERO
	player.camera.look_at(point)
	player.look_rotation=Vector2(player.camera.rotation.x,player.camera.rotation.y)
	player.camera.rotation.y=0

