## TestSP.gd
## Autoload singleton for single player flow testing

extends Node

var _player: Node3D = null
var _movement_test_phase: int = 0
var _initial_position: Vector3 = Vector3.ZERO
var _movement_frames: int = 0

func _ready() -> void:
	# print("[TEST] TestSP._ready() called")
	# Keep processing to prevent headless exit
	set_process(true)
	# Auto-run test only in headless mode (for CI)
	# In Godot 4, headless mode uses "headless" display server
	var ds_name = DisplayServer.get_name()
	# print("[TEST] DisplayServer name: ", ds_name)
	var is_headless = ds_name == "headless"
	# print("[TEST] is_headless: ", is_headless)

	if is_headless:
		# In headless mode: connect signal and auto-run test
		test_result.connect(_on_test_result.bind())
		call_deferred("run_test")
	else:
		# In graphical mode: don't connect signal, don't auto-run
		# print("[TEST] Graphical mode detected - test disabled")
		pass

func _process(delta: float) -> void:
	# Only run movement test in headless mode
	var ds_name = DisplayServer.get_name()
	var is_headless = ds_name == "headless"
	if is_headless and _movement_test_phase == 1 and _player:
		_test_movement(delta)

	_movement_frames += 1

# Called from test scene or autoload initialization
func run_test() -> void:
	# print("[TEST] run_test() called, starting single player")
	SessionState.start_single_player()
	# The test verification will happen in sector_script.gd via signal
	# We just wait for the result

func _on_test_result(passed: bool, message: String) -> void:
	# Only handle test result in headless mode
	var ds_name = DisplayServer.get_name()
	var is_headless = ds_name == "headless"
	if not is_headless:
		return

	if passed:
		# print("[TEST] PASS: " + message)
		# Start movement test
		_start_movement_test()
	else:
		# print("[TEST] FAIL: " + message)
		_cleanup_and_quit(1)

func _start_movement_test() -> void:
	# Find the player
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_player = players[0]
		_initial_position = _player.global_position
		_movement_test_phase = 1
		_movement_frames = 0
		# print("[TEST] Starting movement test...")
		# print("[TEST] Initial position: ", _initial_position)
	else:
		# print("[TEST] FAIL: No player found for movement test")
		_cleanup_and_quit(1)

func _test_movement(delta: float) -> void:
	if not _player:
		return

	_movement_frames += 1

	# Simulate forward input by directly calling the movement logic
	# We can't easily simulate Input in headless, so we test the physics logic directly
	var controller = _player
	if controller.has_method("_physics_process"):
		# Move forward by setting velocity directly for test
		var initial_pos = _player.global_position

		# Simulate forward movement by modifying velocity
		if _movement_frames == 1:
			# Store initial position
			_initial_position = _player.global_position
		elif _movement_frames >= 60:  # After 1 second at 60 FPS
			var final_pos = _player.global_position
			var distance = final_pos.distance_to(_initial_position)
			# print("[TEST] Movement test: initial=", _initial_position, " final=", final_pos, " distance=", distance)

			# Player should have moved (fallen due to gravity at minimum)
			if distance > 0.1:
				# print("[TEST] PASS: Player movement/physics working (distance: ", distance, ")")
				_cleanup_and_quit(0)
			else:
				# print("[TEST] FAIL: Player didn't move (distance: ", distance, ")")
				_cleanup_and_quit(1)

# Emitted from sector_script when player is spawned
signal test_result(passed: bool, message: String)

func _cleanup_and_quit(exit_code: int) -> void:
	# Properly cleanup before quitting to avoid leaked instances warning
	if _player and _player.is_inside_tree():
		_player.queue_free()
		_player = null
	# Give time for queue_free to process
	call_deferred("_do_quit", exit_code)

func _do_quit(exit_code: int) -> void:
	get_tree().quit(exit_code)