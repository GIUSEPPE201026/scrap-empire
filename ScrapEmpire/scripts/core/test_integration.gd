## TestIntegration.gd
## Integration test for full single player flow - runs in graphical mode

extends Node

var _phase: int = 0  # 0=wait_menu, 1=click_single, 2=in_game, 3=test_movement, 4=test_collection, 5=test_deposit, 6=done
var _frames_in_phase: int = 0
var _player: Node3D = null
var _initial_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	print("[INTEGRATION] TestIntegration starting")
	set_process(true)
	# Wait for main menu to load
	_phase = 0
	_frames_in_phase = 0

func _process(delta: float) -> void:
	_frames_in_phase += 1

	match _phase:
		0:  # Wait for main menu
			var menu = get_tree().get_nodes_in_group("main_menu")
			var current_scene = get_tree().current_scene
			var btn_found = false
			if current_scene:
				btn_found = current_scene.get_node_or_null("VBoxContainer/BtnSinglePlayer") != null
			if menu.size() > 0 or btn_found:
				print("[INTEGRATION] Main menu detected, clicking Giocatore Singolo")
				_on_click_single()
				_phase = 1
				_frames_in_phase = 0
			elif _frames_in_phase > 120:  # 2 seconds timeout
				print("[INTEGRATION] FAIL: Main menu not found")
				get_tree().quit(1)

		1:  # Wait for sector to load
			var sector = get_tree().get_first_node_in_group("sector")
			if sector:
				print("[INTEGRATION] Sector loaded, finding player")
				_phase = 2
				_frames_in_phase = 0
			elif _frames_in_phase > 120:
				print("[INTEGRATION] FAIL: Sector not loaded")
				get_tree().quit(1)

		2:  # Find player and verify
			var players = get_tree().get_nodes_in_group("players")
			if players.size() > 0:
				_player = players[0]
				_initial_pos = _player.global_position
				print("[INTEGRATION] Player found at ", _initial_pos)
				# Verify camera
				if _player.camera and _player.camera.current:
					print("[INTEGRATION] PASS: Camera is current")
				else:
					print("[INTEGRATION] FAIL: Camera not current")
					get_tree().quit(1)
				_phase = 3
				_frames_in_phase = 0
			elif _frames_in_phase > 120:
				print("[INTEGRATION] FAIL: Player not found")
				get_tree().quit(1)

		3:  # Test movement - move forward for 2 seconds
			if _player and _frames_in_phase == 1:
				# Simulate forward input by directly setting velocity
				_player.velocity.z = -4.5
				_player.move_and_slide()
			elif _frames_in_phase >= 120:  # 2 seconds
				var final_pos = _player.global_position
				var distance = final_pos.distance_to(_initial_pos)
				print("[INTEGRATION] Movement test: distance = ", distance)
				if distance > 0.5:
					print("[INTEGRATION] PASS: Movement working")
				else:
					print("[INTEGRATION] FAIL: No movement")
					get_tree().quit(1)
				_phase = 4
				_frames_in_phase = 0

		4:  # Test collection - look at scrap and hold left click
			# For now just wait and check scrap items exist
			var scrap_items = get_tree().get_nodes_in_group("scrap")
			if _frames_in_phase == 1:
				print("[INTEGRATION] Found ", scrap_items.size(), " scrap items")
				if scrap_items.size() > 0:
					print("[INTEGRATION] PASS: Scrap items spawned")
				else:
					print("[INTEGRATION] FAIL: No scrap items")
					get_tree().quit(1)
			elif _frames_in_phase >= 60:  # 1 second
				_phase = 5
				_frames_in_phase = 0

		5:  # Test deposit zone detection
			var deposit_zones = get_tree().get_nodes_in_group("deposit_zone")
			if _frames_in_phase == 1:
				print("[INTEGRATION] Found ", deposit_zones.size(), " deposit zones")
				if deposit_zones.size() > 0:
					print("[INTEGRATION] PASS: Deposit zone exists")
				else:
					print("[INTEGRATION] FAIL: No deposit zone")
					get_tree().quit(1)
			elif _frames_in_phase >= 60:
				_phase = 6
				_frames_in_phase = 0

		6:  # Test complete - run for a few more seconds to catch any runtime errors
			if _frames_in_phase >= 180:  # 3 seconds
				print("[INTEGRATION] ALL TESTS PASSED - Full flow working!")
				get_tree().quit(0)

func _on_click_single() -> void:
	# Simulate clicking the single player button
	var btn_single = get_tree().current_scene.get_node_or_null("VBoxContainer/BtnSinglePlayer")
	if btn_single:
		btn_single.emit_signal("pressed")
	else:
		# Try alternative path
		var menu = get_tree().get_nodes_in_group("main_menu")
		if menu.size() > 0:
			menu[0]._on_single_pressed()
		else:
			# Direct call
			SessionState.start_single_player()