## NetworkGateway.gd
## Singleton: gestisce connessione ENet, handshake, RPC routing.
## Percorso stabile: /root/Session/NetworkGateway

extends Node

# Canali ENet
const CHANNEL_RELIABLE: int = 0
const CHANNEL_UNRELIABLE_ORDERED: int = 1
const CHANNEL_STATE: int = 2

# Riferimenti agli autoload singleton (inizializzati in _ready)
var session_state
var game_state
var command_service
var replication_service

# Traccia peer che hanno caricato la scena
var _peers_loaded: Array[int] = []

# Riferimento alla scena settore istanziata (per cleanup)
var _sector_instance: Node = null

func _ready() -> void:
	# Inizializza riferimenti agli autoload
	session_state = get_node("/root/SessionState")
	game_state = get_node("/root/GameState")
	command_service = get_node("/root/CommandService")
	replication_service = get_node("/root/ReplicationService")

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed(reason: String)
signal handshake_received(peer_id: int, protocol: int, build: String, hash: String, name: String)
signal handshake_response_sent(peer_id: int, success: bool)
signal ready_received(peer_id: int, ready: bool)
signal scene_ready_received(peer_id: int)
signal start_loading_sent(scene_path: String)
signal scene_loaded_broadcast()

@rpc("any_peer", "call_local", "reliable")
func rpc_register_player(name: String) -> void:
	# Solo host processa
	if multiplayer.is_server():
		_on_player_registered(multiplayer.get_remote_sender_id(), name)

@rpc("any_peer", "call_local", "reliable")
func rpc_set_ready(ready: bool) -> void:
	if multiplayer.is_server():
		_on_player_ready(multiplayer.get_remote_sender_id(), ready)

@rpc("any_peer", "call_local", "reliable")
func rpc_scene_ready() -> void:
	if multiplayer.is_server():
		_on_scene_ready(multiplayer.get_remote_sender_id())

# Metodi pubblici per SessionState

func host_game(port: int) -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 4)
	if err != OK:
		connection_failed.emit("Errore creazione server: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Host is always peer 1, initialize immediately since connected_to_server doesn't fire for server
	_on_connected()

	print("Server avviato su porta %d" % port)

func join_game(ip: String, port: int) -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		connection_failed.emit("Errore connessione: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("Connessione a %s:%d..." % [ip, port])

func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	# Cleanup sector instance
	if _sector_instance:
		_sector_instance.queue_free()
		_sector_instance = null

func is_network_connected() -> bool:
	var peer = multiplayer.multiplayer_peer
	# OfflineMultiplayerPeer is used for single-player multiplayer API, not real networking
	return peer != null and peer is ENetMultiplayerPeer

func send_handshake(protocol: int, build: String, hash: String, name: String) -> void:
	rpc_id(1, "rpc_receive_handshake", protocol, build, hash, name)

@rpc("any_peer", "call_local", "reliable")
func rpc_receive_handshake(protocol: int, build: String, hash: String, name: String) -> void:
	var sender = multiplayer.get_remote_sender_id()
	handshake_received.emit(sender, protocol, build, hash, name)

	# Solo host valida handshake e risponde
	if multiplayer.is_server():
		var validation = validate_handshake(sender, protocol, build, hash)
		var roster = session_state.players.duplicate()
		send_handshake_response(sender, validation.success, validation.reason, roster, multiplayer.get_unique_id())
		handshake_response_sent.emit(sender, validation.success)

		if validation.success:
			# Registra il player
			_on_player_registered(sender, name)

func send_handshake_response(peer_id: int, success: bool, reason: String, roster: Array[Dictionary], host_id: int) -> void:
	rpc_id(peer_id, "rpc_handshake_result", success, reason, roster, host_id)

@rpc("authority", "call_local", "reliable")
func rpc_handshake_result(success: bool, reason: String, roster: Array[Dictionary], host_id: int) -> void:
	session_state.on_handshake_response(success, reason, multiplayer.get_unique_id(), roster, host_id)

func send_ready(ready: bool) -> void:
	if multiplayer.is_server():
		_on_player_ready(multiplayer.get_unique_id(), ready)
	else:
		rpc_id(1, "rpc_set_ready", ready)

func send_start_loading(scene_path: String) -> void:
	_peers_loaded.clear()

	# Prima notifica i client di caricare (così iniziano in parallelo)
	if multiplayer.is_server():
		var peers = multiplayer.get_peers()
		for peer_id in peers:
			if peer_id != multiplayer.get_unique_id():
				rpc_id(peer_id, "rpc_start_loading", scene_path)

	# Poi carica localmente (istanziando come child di /root, non cambiando la scena principale)
	if multiplayer.is_server():
		call_deferred("_instance_sector_local", scene_path)

func _instance_sector_local(scene_path: String) -> void:
	# Carica la scena in modo asincrono per non bloccare il thread principale
	# e permettere a ENet di processare i pacchetti
	var err = ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		push_error("Errore richiesta caricamento asincrono: %s" % err)
		return

	# Attendi il completamento del caricamento (non bloccante, polla in _process)
	_pending_scene_path = scene_path
	set_process(true)

func _process(delta: float) -> void:
	if _pending_scene_path:
		var status = ResourceLoader.load_threaded_get_status(_pending_scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene = ResourceLoader.load_threaded_get(_pending_scene_path)
			if scene:
				_sector_instance = scene.instantiate()
				get_tree().root.add_child(_sector_instance)
				start_loading_sent.emit(_pending_scene_path)
			else:
				push_error("Scena non trovata: %s" % _pending_scene_path)
			_pending_scene_path = ""
			set_process(false)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Caricamento fallito: %s" % _pending_scene_path)
			_pending_scene_path = ""
			set_process(false)

# Variabile per tracciare il caricamento asincrono
var _pending_scene_path: String = ""

@rpc("any_peer", "call_remote", "reliable")
func rpc_start_loading(scene_path: String) -> void:
	# Client transizione a LOADING
	if not multiplayer.is_server():
		session_state.on_start_loading(scene_path)

	start_loading_sent.emit(scene_path)
	# Client istanzia la scena come child di /root (deferred per non bloccare)
	call_deferred("_instance_sector_local", scene_path)

func send_scene_ready() -> void:
	if multiplayer.is_server():
		_on_scene_ready(multiplayer.get_unique_id())
	else:
		# Invia direttamente - non stiamo cambiando scena, solo istanziando come child
		rpc_id(1, "rpc_scene_ready")

# Handler interni

func _on_connected() -> void:
	var peer_id = multiplayer.get_unique_id()
	print("Connesso come peer %d" % peer_id)
	session_state.on_connected(peer_id)

func _on_server_disconnected() -> void:
	print("Disconnesso dal server")
	session_state.on_disconnected(1)  # Host è sempre peer 1

func _on_peer_connected(peer_id: int) -> void:
	print("Peer %d connesso" % peer_id)
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer %d disconnesso" % peer_id)
	peer_disconnected.emit(peer_id)
	session_state.on_disconnected(peer_id)

func _on_player_registered(peer_id: int, name: String) -> void:
	var session = session_state
	if session.current_state != session_state.ConnectionState.LOBBY:
		return

	# Verifica duplicati
	for p in session.players:
		if p.peer_id == peer_id:
			return

	var is_host = (peer_id == 1)
	session.players.append({
		"peer_id": peer_id,
		"name": name.left(24),
		"ready": false,
		"is_host": is_host
	})
	session.roster_updated.emit(session.players)

	# Invia roster aggiornato a tutti
	rpc("rpc_update_roster", session.players)

@rpc("authority", "call_local", "reliable")
func rpc_update_roster(roster: Array[Dictionary]) -> void:
	session_state.players = roster
	session_state.roster_updated.emit(roster)

func _on_player_ready(peer_id: int, ready: bool) -> void:
	session_state.on_player_ready(peer_id, ready)
	ready_received.emit(peer_id, ready)

func _on_scene_ready(peer_id: int) -> void:
	print("[NG] _on_scene_ready called for peer %d, is_server=%s" % [peer_id, multiplayer.is_server()])
	# Host traccia i peer che hanno caricato
	if multiplayer.is_server():
		if peer_id not in _peers_loaded:
			_peers_loaded.append(peer_id)
			print("[LOADING] Peer %d caricato (%d/%d)" % [peer_id, _peers_loaded.size(), session_state.players.size()])

		# Verifica se tutti hanno caricato
		if _peers_loaded.size() >= session_state.players.size():
			_peers_loaded.clear()
			session_state.on_all_loaded()

# Handshake validation (chiamato da host)
func validate_handshake(peer_id: int, protocol: int, build: String, hash: String) -> Dictionary:
	var session = session_state
	var success = true
	var reason = ""

	if protocol != session.protocol_version:
		success = false
		reason = "Versione protocollo non compatibile (atteso %d, ricevuto %d)" % [session.protocol_version, protocol]
	elif build != session.build_id:
		success = false
		reason = "Build ID non compatibile (atteso %s, ricevuto %s)" % [session.build_id, build]
	elif hash != session.content_hash:
		success = false
		reason = "Content hash non corrispondente. File dati modificati?"

	return {"success": success, "reason": reason}

# Utility per invio RPC validati
func send_reliable_rpc(method: String, args: Array) -> void:
	rpc(method, args)

func get_peer_id() -> int:
	return multiplayer.get_unique_id()

func is_host() -> bool:
	return multiplayer.is_server()

func get_connected_peers() -> Array[int]:
	var peers: Array[int] = []
	for id in multiplayer.get_peers():
		peers.append(id)
	return peers