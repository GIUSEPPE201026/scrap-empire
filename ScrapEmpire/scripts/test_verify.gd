## Test script to verify autoloads and scene configuration
## Run with: godot --path "..." --headless -s res://scripts/test_verify.gd

@tool
extends SceneTree

func _init():
	var output = "=== ScrapEmpire Verification Test ===\n"

	# Test 1: Check autoloads exist
	var autoloads = [
		"SessionState",
		"GameState",
		"CommandService",
		"NetworkGateway",
		"ReplicationService",
		"InventoryService",
		"EconomyService",
		"ContractService",
		"SaveService"
	]

	output += "\n--- Autoload Verification ---\n"
	for name in autoloads:
		var node = get_root().get_node_or_null("/root/" + name)
		if node:
			output += "OK: %s found at /root/%s\n" % [name, name]
			if node.has_method("_ready"):
				output += "  - Has _ready method\n"
		else:
			output += "FAIL: %s NOT FOUND at /root/%s\n" % [name, name]

	# Test 2: Check NetworkGateway stable path
	output += "\n--- NetworkGateway Path ---\n"
	var ng = get_root().get_node_or_null("/root/Session/NetworkGateway")
	if ng:
		output += "OK: NetworkGateway at /root/Session/NetworkGateway\n"
	else:
		output += "FAIL: NetworkGateway NOT at /root/Session/NetworkGateway\n"
		# Check alternative
		var ng2 = get_root().get_node_or_null("/root/NetworkGateway")
		if ng2:
			output += "  Found at /root/NetworkGateway instead\n"

	# Test 3: Check scenes exist
	output += "\n--- Scene Verification ---\n"
	var scenes = [
		"res://scenes/boot.tscn",
		"res://scenes/main_menu.tscn",
		"res://scenes/lobby.tscn",
		"res://scenes/sector.tscn",
		"res://scenes/player.tscn"
	]
	for scene_path in scenes:
		var scene = ResourceLoader.load(scene_path)
		if scene:
			output += "OK: %s loads\n" % scene_path
			var root = scene.instantiate()
			if root:
				output += "  - Root: %s (%s)\n" % [root.name, root.get_class()]
				root.queue_free()
		else:
			output += "FAIL: %s NOT FOUND\n" % scene_path

	# Test 4: Check player scene structure
	output += "\n--- Player Scene Structure ---\n"
	var player_scene = ResourceLoader.load("res://scenes/player.tscn")
	if player_scene:
		var player = player_scene.instantiate()
		if player:
			output += "Root: %s\n" % player.name
			output += "  - Has script: %s\n" % (player.get_script() != null)
			if player.get_script():
				output += "  - Script: %s\n" % player.get_script().resource_path

			var camera = player.get_node_or_null("Camera3D")
			var collision = player.get_node_or_null("CollisionShape3D")
			var mesh = player.get_node_or_null("MeshInstance3D")
			var remote_mesh = player.get_node_or_null("RemoteMesh")
			var name_label = player.get_node_or_null("NameLabel")
			var sync = player.get_node_or_null("MultiplayerSynchronizer")

			output += "  - Camera3D: %s\n" % ("OK" if camera else "MISSING")
			output += "  - CollisionShape3D: %s\n" % ("OK" if collision else "MISSING")
			output += "  - MeshInstance3D (local): %s\n" % ("OK" if mesh else "MISSING")
			output += "  - RemoteMesh: %s\n" % ("OK" if remote_mesh else "MISSING")
			output += "  - NameLabel: %s\n" % ("OK" if name_label else "MISSING")
			output += "  - MultiplayerSynchronizer: %s\n" % ("OK" if sync else "MISSING")

			if sync:
				output += "    Replicate paths: %s\n" % sync.replicate_paths
				output += "    Replicate interval: %s\n" % sync.replicate_interval

			player.queue_free()

	# Test 5: Check sector scene structure
	output += "\n--- Sector Scene Structure ---\n"
	var sector_scene = ResourceLoader.load("res://scenes/sector.tscn")
	if sector_scene:
		var sector = sector_scene.instantiate()
		if sector:
			output += "Root: %s\n" % sector.name
			var spawner = sector.get_node_or_null("PlayerSpawner")
			var spawn_points = sector.get_node_or_null("SpawnPoints")
			var floor = sector.get_node_or_null("Floor")

			output += "  - PlayerSpawner: %s\n" % ("OK" if spawner else "MISSING")
			if spawner:
				output += "    Spawn path: %s\n" % spawner.spawn_path
			output += "  - SpawnPoints: %s\n" % ("OK" if spawner else "MISSING")
			if spawn_points:
				output += "    Children: %s\n" % spawn_points.get_children().size()
			output += "  - Floor: %s\n" % ("OK" if floor else "MISSING")

			sector.queue_free()

	# Test 6: Check balance.json loads
	output += "\n--- Balance Data ---\n"
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if file:
		var json = file.get_as_text()
		file.close()
		var balance = JSON.parse_string(json)
		if balance:
			output += "OK: balance.json loads and parses\n"
			output += "  - protocol_version: %s\n" % balance.network_proposal.protocol_version
			output += "  - max_players: %s\n" % balance.max_players
			output += "  - materials: %s\n" % balance.materials.keys()
			output += "  - contracts: %s\n" % balance.contracts.size()
			output += "  - upgrades: %s\n" % balance.upgrades.keys()
		else:
			output += "FAIL: balance.json parse error\n"
	else:
		output += "FAIL: balance.json not found\n"

	# Test 7: Check input map
	output += "\n--- Input Map ---\n"
	var actions = [
		"move_forward", "move_back", "move_left", "move_right",
		"jump", "sprint", "interact", "collect", "pause", "toggle_team"
	]
	for action in actions:
		if InputMap.has_action(action):
			output += "OK: %s\n" % action
		else:
			output += "FAIL: %s MISSING\n" % action

	output += "\n=== Verification Complete ===\n"

	# Write to file
	var out_file = FileAccess.open("user://verify_output.txt", FileAccess.WRITE)
	if out_file:
		out_file.store_string(output)
		out_file.close()
		print("Output written to user://verify_output.txt")
	else:
		print("Failed to write output file")

	# Also print to stdout
	print(output)

	quit()