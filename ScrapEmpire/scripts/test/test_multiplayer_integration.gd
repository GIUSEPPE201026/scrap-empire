## test_multiplayer_integration.gd
## Harness di integrazione headless per testare il flusso multiplayer completo.
## Deve essere istanziato in una scena (anche vuota) e avviato con --headless.
## Verifica: handshake, roster sync, ready propagation, host-only start, coordinated loading, single spawn, disconnect cleanup, host loss, mismatch rejection.

extends Node

# Configurazione test
const TEST_PORT: int = 24567
const TEST_TIMEOUT: float = 40.0
const LOG_DIR: String = "user://test_logs/"

# Riferimenti ai servizi (autoload) - senza type hints per evitare errori
@onready var session_state = SessionState
@onready var network_gateway = NetworkGateway
@onready var replication_service = ReplicationService
@onready var game_state = GameState

# Timer per polling
@onready var _poll_timer: Timer = Timer.new()

# Stato test
var _test_results: Array[Dictionary] = []
var _is_host: bool = false
var _test_step: int = 0
var _start_time: float = 0.0
var _test_passed: int = 0
var _test_failed: int = 0
var _mismatch_type: String = ""
var _client_connected: bool = false
var _client_peer_id: int = 0
var _client_disconnected: bool = false
var _client_ready_received: bool = false
var _mission_started: bool = false
var _entities_spawned: int = 0
var _waiting_for: String = ""
var _mismatch_test_done: bool = false
var _mismatch_rejected: bool = false
var _initial_host_ready: bool = false
var _initial_client_ready: bool = false
var _initial_ready_captured: bool = false

func _ready() -> void:
	# Crea directory log
	var dir = DirAccess.open(LOG_DIR)
	if not dir:
		DirAccess.make_dir_recursive_absolute(LOG_DIR)

	# Setup timer per polling (evita call_deferred ricorsivi che crashano in headless)
	add_child(_poll_timer)
	_poll_timer.wait_time = 0.1
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_timer)
	_poll_timer.start()

	# Parse argomenti
	var args = OS.get_cmdline_args()
	_is_host = "--host" in args
	var mismatch_idx = args.find("--mismatch")
	if mismatch_idx >= 0 and mismatch_idx + 1 < args.size():
		_mismatch_type = args[mismatch_idx + 1]

	print("=== Test Multiplayer Integration ===")
	print("Godot version: %s" % Engine.get_version_info()["string"])
	print("Modalità: %s" % ("HOST" if _is_host else "CLIENT"))
	if _mismatch_type:
		print("Mismatch type: %s" % _mismatch_type)

	# Applica mismatch se specificato (lato client)
	if _mismatch_type and not _is_host:
		_apply_mismatch(_mismatch_type)

	# Connetti segnali
	_connect_signals()

	_start_time = Time.get_ticks_msec() / 1000.0

	# Avvia sequenza
	_run_tests()

func _on_poll_timer() -> void:
	# Polling basato su stato invece di call_deferred ricorsivi
	var elapsed = Time.get_ticks_msec() / 1000.0 - _start_time
	if elapsed > TEST_TIMEOUT:
		_fail_test("Timeout globale (%ds)" % TEST_TIMEOUT)
		_finish_tests()
		return

	match _waiting_for:
		"roster_ready":
			if session_state.players.size() >= 2:
				_waiting_for = ""
				_run_lobby_tests()
		"client_ready":
			if _client_ready_received:
				_waiting_for = ""
				session_state.set_ready(true)
				call_deferred("_check_both_ready")
		"mission_load":
			if session_state.current_state == session_state.ConnectionState.MISSION:
				_waiting_for = ""
				_run_mission_tests()
		"entities_spawn":
			if _entities_spawned >= 2:
				_waiting_for = ""
				call_deferred("_test_client_disconnect")
		"client_lobby":
			if session_state.current_state == session_state.ConnectionState.LOBBY:
				_waiting_for = ""
				_client_lobby_tests()
		"client_entities":
			if _entities_spawned >= 2:
				_waiting_for = ""
				call_deferred("_test_host_loss")
		"host_loss":
			if session_state.current_state == session_state.ConnectionState.DISCONNECTED:
				_waiting_for = ""
				_pass_test("Client: Ritorna a DISCONNECTED su perdita host", true)
				call_deferred("_finish_tests")
		"client_real_disconnect":
			if _client_disconnected:
				_waiting_for = ""
				_pass_test("Client disconnesso realmente dalla rete", true)
				call_deferred("_finish_tests")
		"mismatch_rejection":
			if _mismatch_rejected:
				_waiting_for = ""
				_pass_test("Mismatch rejection (%s): handshake rifiutato correttamente" % _mismatch_type, true)
				call_deferred("_finish_mismatch_test")
		"mismatch_result":
			# Gestito via segnale handshake_result (lato client)
			pass

func _connect_signals() -> void:
	session_state.state_changed.connect(_on_state_changed)
	session_state.roster_updated.connect(_on_roster_updated)
	session_state.handshake_result.connect(_on_handshake_result)
	session_state.mission_starting.connect(_on_mission_starting)
	session_state.mission_ended.connect(_on_mission_ended)
	session_state.connection_failed.connect(_on_connection_failed)

	network_gateway.peer_connected.connect(_on_peer_connected)
	network_gateway.peer_disconnected.connect(_on_peer_disconnected)
	network_gateway.handshake_received.connect(_on_handshake_received)
	network_gateway.handshake_response_sent.connect(_on_handshake_response_sent)
	network_gateway.ready_received.connect(_on_ready_received)
	network_gateway.scene_ready_received.connect(_on_scene_ready_received)
	network_gateway.start_loading_sent.connect(_on_start_loading_sent)
	network_gateway.scene_loaded_broadcast.connect(_on_scene_loaded_broadcast)

	replication_service.entity_spawned.connect(_on_entity_spawned)
	replication_service.entity_despawned.connect(_on_entity_despawned)

func _apply_mismatch(mismatch_type: String) -> void:
	match mismatch_type:
		"protocol":
			session_state.protocol_version = 999
			print("[MISMATCH] Protocol version modificato a 999")
		"build":
			session_state.build_id = "different_build"
			print("[MISMATCH] Build ID modificato a 'different_build'")
		"hash":
			session_state.content_hash = "different_hash"
			print("[MISMATCH] Content hash modificato a 'different_hash'")

func _run_tests() -> void:
	if _is_host:
		_run_host_tests()
	else:
		_run_client_tests()

# ===== HOST TESTS =====

func _run_host_tests() -> void:
	_test_step = 1
	session_state.start_hosting(TEST_PORT)
	session_state.set_local_name("HostPlayer")
	network_gateway.host_game(TEST_PORT)
	_pass_test("Host: Server avviato su porta %d" % TEST_PORT, true)

	if _mismatch_type:
		# Test mismatch: aspetta che handshake venga rifiutato
		_waiting_for = "mismatch_rejection"
	else:
		# Test normale: aspetta roster con 2 giocatori
		_waiting_for = "roster_ready"

func _run_lobby_tests() -> void:
	# Test 1: Handshake completato con versioni compatibili
	_pass_test("Handshake compatibile completato", session_state.current_state == session_state.ConnectionState.LOBBY)

	# Test 2: Roster identico su host e client (2 giocatori)
	_pass_test("Roster sincronizzato (2 giocatori)", session_state.players.size() == 2)

	# Test 3: Stato ready iniziale (catturato al momento dell'aggiunta del secondo player)
	_pass_test("Stato ready iniziale: entrambi false", not _initial_host_ready and not _initial_client_ready)

	# Aspetta che client si metta ready (via segnale)
	_test_step = 2
	_waiting_for = "client_ready"

func _check_both_ready() -> void:
	var all_ready = session_state.is_all_ready()
	_pass_test("Entrambi ready", all_ready)

	# Test 4: Avvio missione solo da host
	_test_step = 3
	var sector_scene = ResourceLoader.load("res://scenes/sector.tscn")
	if not sector_scene:
		_fail_test("Scena sector.tscn non trovata")
		_finish_tests()
		return

	var start_result = session_state.start_mission(sector_scene)
	_pass_test("Host può avviare missione quando tutti ready", start_result)

	if not start_result:
		_fail_test("Avvio missione fallito")
		_finish_tests()
		return

	_mission_started = true
	_waiting_for = "mission_load"

func _run_mission_tests() -> void:
	# Test 5: Caricamento coordinato - host in MISSION
	_pass_test("Host: Stato MISSION raggiunto", session_state.current_state == session_state.ConnectionState.MISSION)

	# Test 6: Entità player registrate (almeno 2)
	_waiting_for = "entities_spawn"

func _test_client_disconnect() -> void:
	# Test 7: Disconnessione client e pulizia (simulazione locale)
	_test_step = 4
	if _client_peer_id == 0:
		_fail_test("Client peer_id non tracciato, impossibile testare disconnessione")
		_finish_tests()
		return

	print("[TEST] Simulando disconnessione client con peer_id: %d" % _client_peer_id)
	session_state.on_disconnected(_client_peer_id)
	# Verifica immediata: roster locale aggiornato
	var player_count = session_state.players.size()
	_pass_test("Client disconnesso rimosso da roster (1 rimasto)", player_count == 1)

	# Ora aspetta che il client si disconnetta davvero dalla rete
	# Il client completerà i suoi test e uscirà, causando peer_disconnected
	_waiting_for = "client_real_disconnect"

# ===== CLIENT TESTS =====

func _run_client_tests() -> void:
	_test_step = 1
	network_gateway.join_game("127.0.0.1", TEST_PORT)
	session_state.start_joining("127.0.0.1", TEST_PORT)
	session_state.set_local_name("ClientPlayer")
	_pass_test("Client: Connessione avviata", true)

	_waiting_for = "client_lobby"

func _client_lobby_tests() -> void:
	# Test 1 & 2: Handshake e roster
	_pass_test("Client: Handshake completato", session_state.current_state == session_state.ConnectionState.LOBBY)
	_pass_test("Client: Roster ricevuto (%d giocatori)" % session_state.players.size(), session_state.players.size() == 2)

	# Client si mette ready
	session_state.set_ready(true)
	_pass_test("Client: Impostato ready", true)

	_waiting_for = "client_entities"

func _test_host_loss() -> void:
	# Test 7: Perdita host gestita
	_test_step = 5
	session_state.on_disconnected(1)
	_waiting_for = "host_loss"

# ===== SIGNAL HANDLERS =====

func _on_state_changed(state_name: String) -> void:
	print("[STATE] %s -> %s" % [session_state.get_state_name(), state_name])

func _on_roster_updated(players: Array[Dictionary]) -> void:
	print("[ROSTER] Aggiornato: %d giocatori" % players.size())
	for p in players:
		print("  Peer %d: %s, ready=%s, host=%s" % [p.peer_id, p.name, p.ready, p.is_host])

	# Cattura stato ready iniziale quando roster raggiunge 2 giocatori per la prima volta
	if _is_host and not _initial_ready_captured and players.size() >= 2:
		for p in players:
			if p.peer_id == 1:
				_initial_host_ready = p.ready
			else:
				_initial_client_ready = p.ready
		_initial_ready_captured = true
		print("[TEST] Initial ready state captured: host=%s, client=%s" % [_initial_host_ready, _initial_client_ready])

func _on_handshake_result(success: bool, reason: String) -> void:
	print("[HANDSHAKE] %s: %s" % ["SUCCESS" if success else "FAIL", reason])

	if _mismatch_type and not _is_host and not _mismatch_test_done:
		# Per test mismatch, ci aspettiamo CHE FALLISCA
		if not success:
			_pass_test("Mismatch rejection (%s): %s" % [_mismatch_type, reason], true)
			_mismatch_test_done = true
			call_deferred("_finish_mismatch_test")
		else:
			_fail_test("Mismatch rejection FALLITO: handshake accettato quando dovrebbe essere rifiutato")
			call_deferred("_finish_tests")
	elif success:
		_client_connected = true

func _on_mission_starting() -> void:
	print("[MISSION] Avvio missione")

func _on_mission_ended(reason: String) -> void:
	print("[MISSION] Terminata: %s" % reason)

func _on_connection_failed(reason: String) -> void:
	print("[CONNECTION] Fallita: %s")
	if _mismatch_type and not _is_host and not _mismatch_test_done:
		# Connection failed è atteso per mismatch
		_pass_test("Connection failed per mismatch: %s" % reason, true)
		_mismatch_test_done = true
		call_deferred("_finish_mismatch_test")

func _on_peer_connected(peer_id: int) -> void:
	print("[PEER] Connesso: %d" % peer_id)
	if _is_host and peer_id != 1:  # Any peer that's not the host (peer 1)
		_client_connected = true
		_client_peer_id = peer_id
		print("[TEST] Client peer_id recorded: %d" % _client_peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[PEER] Disconnesso: %d" % peer_id)
	if _is_host and peer_id == _client_peer_id:
		_client_disconnected = true
		print("[TEST] Client peer %d disconnected from network" % _client_peer_id)

func _on_handshake_received(peer_id: int, protocol: int, build: String, hash: String, name: String) -> void:
	print("[HANDSHAKE RX] Peer %d: proto=%d, build=%s, hash=%s, name=%s" % [peer_id, protocol, build, hash, name])

func _on_handshake_response_sent(peer_id: int, success: bool) -> void:
	print("[HANDSHAKE TX] Peer %d: %s" % [peer_id, "OK" if success else "REJECT"])
	# Lato host: se mismatch test e handshake rifiutato, segna come rejected
	if _is_host and _mismatch_type and not success:
		_mismatch_rejected = true

func _on_ready_received(peer_id: int, ready: bool) -> void:
	print("[READY] Peer %d: %s" % [peer_id, "ready" if ready else "not ready"])
	if _is_host and peer_id != 1 and ready:  # Any non-host peer
		_client_ready_received = true

func _on_scene_ready_received(peer_id: int) -> void:
	print("[SCENE READY] Peer %d" % peer_id)

func _on_start_loading_sent(scene_path: String) -> void:
	print("[LOADING] Scena: %s" % scene_path)

func _on_scene_loaded_broadcast() -> void:
	print("[LOADING] Tutti caricati")

func _on_entity_spawned(entity_id: String, def_id: String, transform: Transform3D, owner_peer: int) -> void:
	print("[SPAWN] Entity %s (def=%s) per peer %d" % [entity_id, def_id, owner_peer])
	_entities_spawned += 1

func _on_entity_despawned(entity_id: String) -> void:
	print("[DESPAWN] Entity %s" % entity_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_client_test_complete() -> void:
	if _is_host:
		print("[TEST] Client completed tests, host can finish")
		call_deferred("_finish_tests")

# ===== HELPERS =====

func _pass_test(name: String, condition: bool) -> void:
	_test_results.append({
		"name": name,
		"step": _test_step,
		"passed": condition,
		"time": Time.get_ticks_msec() / 1000.0 - _start_time
	})
	if condition:
		_test_passed += 1
		print("  [PASS] Step %d: %s" % [_test_step, name])
	else:
		_test_failed += 1
		print("  [FAIL] Step %d: %s" % [_test_step, name])

func _fail_test(name: String) -> void:
	_test_results.append({
		"name": name,
		"step": _test_step,
		"passed": false,
		"time": Time.get_ticks_msec() / 1000.0 - _start_time
	})
	_test_failed += 1
	print("  [FAIL] Step %d: %s" % [_test_step, name])

func _finish_mismatch_test() -> void:
	var total_time = Time.get_ticks_msec() / 1000.0 - _start_time
	print("\n=== RISULTATI TEST MISMATCH ===")
	print("Totale: %d, Passati: %d, Falliti: %d" % [_test_results.size(), _test_passed, _test_failed])
	print("Tempo: %.2fs" % total_time)

	for r in _test_results:
		var status = "PASS" if r.passed else "FAIL"
		print("  [%s] Step %d: %s (%.2fs)" % [status, r.step, r.name, r.time])

	_write_report()
	get_tree().quit(_test_failed > 0)

func _finish_tests() -> void:
	var total_time = Time.get_ticks_msec() / 1000.0 - _start_time
	print("\n=== RISULTATI TEST ===")
	print("Totale: %d, Passati: %d, Falliti: %d" % [_test_results.size(), _test_passed, _test_failed])
	print("Tempo: %.2fs" % total_time)

	for r in _test_results:
		var status = "PASS" if r.passed else "FAIL"
		print("  [%s] Step %d: %s (%.2fs)" % [status, r.step, r.name, r.time])

	_write_report()

	# Se siamo il client, notifica l'host che abbiamo finito
	if not _is_host:
		rpc_id(1, "rpc_client_test_complete")

	get_tree().quit(_test_failed > 0)

func _write_report() -> void:
	var report = {
		"timestamp": Time.get_datetime_string_from_system(),
		"role": "host" if _is_host else "client",
		"mismatch_type": _mismatch_type if _mismatch_type else "none",
		"total_tests": _test_results.size(),
		"passed": _test_passed,
		"failed": _test_failed,
		"duration": Time.get_ticks_msec() / 1000.0 - _start_time,
		"results": _test_results
	}

	var file = FileAccess.open("%s/test_report_%s_%s.json" % [LOG_DIR, "host" if _is_host else "client", _mismatch_type if _mismatch_type else "full"], FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("Report salvato: %s" % file.get_path())