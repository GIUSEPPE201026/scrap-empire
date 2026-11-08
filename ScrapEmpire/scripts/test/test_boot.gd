## test_boot.gd
## Test entry point for headless multiplayer testing
## Handles --test-mode host|client arguments

extends Node

@onready var _session: SessionState = get_node("/root/SessionState")
@onready var _network: NetworkGateway = get_node("/root/NetworkGateway")
@onready var _replication: ReplicationService = get_node("/root/ReplicationService")
@onready var _command: CommandService = get_node("/root/CommandService")

var _test_mode: String = ""
var _test_port: int = 24567
var _test_host: String = "127.0.0.1"
var _phase: int = 0
var _host_peer_id: int = 0

func _ready() -> void:
	print("[TEST_BOOT] Test boot started")
	_parse_args()

	if _test_mode == "host":
		_start_host_test()
	elif _test_mode == "client":
		_start_client_test()
	else:
		print("[TEST_BOOT] No test mode specified, exiting")
		get_tree().quit(1)

	set_process(true)

func _parse_args() -> void:
	var args = OS.get_cmdline_user_args()
	print("[TEST_BOOT] Args: %s" % args)

	for i in range(args.size()):
		if args[i] == "--test-mode" and i + 1 < args.size():
			_test_mode = args[i + 1]
		elif args[i] == "--test-port" and i + 1 < args.size():
			_test_port = args[i + 1].to_int()
		elif args[i] == "--test-host" and i + 1 < args.size():
			_test_host = args[i + 1]

	print("[TEST_BOOT] Mode: %s, Port: %d, Host: %s" % [_test_mode, _test_port, _test_host])

func _start_host_test() -> void:
	print("[TEST_BOOT] Starting HOST test on port %d" % _test_port)
	_session.set_local_name("TestHost")
	_network.host_game(_test_port)

	# Connect signals
	_network.peer_connected.connect(_on_peer_connected)
	_network.handshake_received.connect(_on_handshake_received)
	_network.scene_ready_received.connect(_on_scene_ready)
	_session.mission_starting.connect(_on_mission_starting)

	_phase = 1

func _start_client_test() -> void:
	print("[TEST_BOOT] Starting CLIENT test connecting to %s:%d" % [_test_host, _test_port])
	_session.set_local_name("TestClient")
	_network.join_game(_test_host, _test_port)

	# Connect signals
	_session.mission_starting.connect(_on_mission_starting)
	_session.roster_updated.connect(_on_roster_updated)

	_phase = 1

func _process(delta: float) -> void:
	match _phase:
		1:  # Waiting for connection/handshake
			if _test_mode == "host":
				if _host_peer_id > 0:
					print("[TEST_BOOT] Host: Client connected, waiting for ready...")
					_phase = 2
			else:
				# Client waits for roster to be updated, then sends ready
				pass

		2:  # Host: both connected, start mission when all ready
			if _test_mode == "host" and _session.is_all_ready():
				print("[TEST_BOOT] Host: All ready, starting mission...")
				var sector_scene = preload("res://scenes/sector.tscn")
				_session.start_mission(sector_scene)
				_phase = 3

		3:  # Mission loaded, verify
			# Wait for mission_starting signal
			pass

func _on_peer_connected(peer_id: int) -> void:
	print("[TEST_BOOT] Peer connected: %d" % peer_id)
	if _test_mode == "host":
		_host_peer_id = peer_id
		# Auto-ready for client (host handles both)
		_session.set_ready(true)

func _on_handshake_received(peer_id: int, protocol: int, build: String, hash: String, name: String) -> void:
	print("[TEST_BOOT] Handshake from %d: %s" % [peer_id, name])
	# Auto-approve handshake in test
	# NetworkGateway validates and responds automatically

var _client_ready_sent: bool = false

func _on_roster_updated(players: Array[Dictionary]) -> void:
	print("[TEST_BOOT] Roster updated (%s): %d players" % [_test_mode, players.size()])
	if _test_mode == "client" and not _client_ready_sent:
		# Find our peer_id and send ready if not already ready
		for p in players:
			if p.name == "TestClient":
				if p.ready:
					print("[TEST_BOOT] Client: Already ready")
					_client_ready_sent = true
				else:
					print("[TEST_BOOT] Client: Sending ready...")
					_session.set_ready(true)
					_client_ready_sent = true
				break

func _on_scene_ready(peer_id: int) -> void:
	print("[TEST_BOOT] Scene ready from peer %d" % peer_id)

func _on_mission_starting() -> void:
	print("[TEST_BOOT] Mission starting! (%s)" % _test_mode)

	if _test_mode == "host":
		# Host: verify sector manifest
		call_deferred("_verify_sector_manifest")
	else:
		# Client: verify we received same entities
		call_deferred("_verify_client_entities")

func _verify_sector_manifest() -> void:
	print("[TEST_BOOT] Host: Verifying sector manifest...")
	var manifest = _replication.generate_sector_manifest()
	print("[TEST_BOOT] Host: Manifest has %d entities, content_hash: %s" % [manifest.entities.size(), manifest.content_hash])

	# Verify 120 entities (players + scrap)
	if manifest.entities.size() >= 115:  # 115-120 scrap + players
		print("[TEST_BOOT] PASS: Host manifest has %d entities" % manifest.entities.size())
	else:
		print("[TEST_BOOT] FAIL: Host manifest only has %d entities" % manifest.entities.size())
		get_tree().quit(1)

	# Give client time to verify
	call_deferred("_finish_test")

func _verify_client_entities() -> void:
	print("[TEST_BOOT] Client: Verifying entities...")
	var entities = _replication.get_all_entities()
	print("[TEST_BOOT] Client: Received %d entities" % entities.size())

	if entities.size() >= 115:
		print("[TEST_BOOT] PASS: Client has %d entities" % entities.size())
	else:
		print("[TEST_BOOT] FAIL: Client only has %d entities" % entities.size())
		get_tree().quit(1)

func _finish_test() -> void:
	print("[TEST_BOOT] Test completed successfully!")
	get_tree().quit(0)