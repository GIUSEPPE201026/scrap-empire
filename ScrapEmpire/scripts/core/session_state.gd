## SessionState.gd
## Singleton: gestisce il ciclo di vita della sessione multiplayer.
## Stati: DISCONNECTED -> CONNECTING -> HANDSHAKE -> LOBBY -> LOADING -> READY -> MISSION

extends Node

signal state_changed(new_state: String)
signal roster_updated(players: Array[Dictionary])
signal handshake_result(success: bool, reason: String)
signal mission_starting()
signal mission_ended(reason: String)
signal connection_failed(reason: String)

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	HANDSHAKE,
	LOBBY,
	LOADING,
	READY,
	MISSION
}

@export var protocol_version: int = 1
@export var build_id: String = "dev_001"
@export var content_hash: String = ""

var current_state: ConnectionState = ConnectionState.DISCONNECTED
var is_host: bool = false
var local_peer_id: int = 0
var local_player_name: String = "Player"
var host_peer_id: int = 1
var players: Array[Dictionary] = []  # [{peer_id, name, ready, is_host}]
var mission_id: String = ""
var pending_scene: PackedScene = null
var is_single_player_session: bool = false
var progression_loaded: bool = false
var progression_notice: String = ""

func _ready() -> void:
	# print("[SESSION_STATE] SessionState initialized")
	# Genera content_hash da balance.json se non impostato
	if content_hash.is_empty():
		content_hash = _compute_content_hash()

func _compute_content_hash() -> String:
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		return "unknown"
	var text = file.get_as_text()
	file.close()
	return str(text.hash())

func set_local_name(name: String) -> void:
	local_player_name = name.left(24)

func get_state_name() -> String:
	match current_state:
		ConnectionState.DISCONNECTED: return "DISCONNECTED"
		ConnectionState.CONNECTING: return "CONNECTING"
		ConnectionState.HANDSHAKE: return "HANDSHAKE"
		ConnectionState.LOBBY: return "LOBBY"
		ConnectionState.LOADING: return "LOADING"
		ConnectionState.READY: return "READY"
		ConnectionState.MISSION: return "MISSION"
	return "UNKNOWN"

func transition_to(new_state: ConnectionState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(get_state_name())

func start_hosting(port: int) -> void:
	is_single_player_session = false
	if current_state != ConnectionState.DISCONNECTED:
		return
	is_host = true
	transition_to(ConnectionState.CONNECTING)
	# NetworkGateway gestisce l'effettiva creazione del server

func start_joining(ip: String, port: int) -> void:
	is_single_player_session = false
	if current_state != ConnectionState.DISCONNECTED:
		return
	is_host = false
	transition_to(ConnectionState.CONNECTING)
	# NetworkGateway gestisce la connessione

func start_single_player() -> void:
	if current_state != ConnectionState.DISCONNECTED:
		return
	is_single_player_session = true
	if not progression_loaded:
		if not SaveService._find_latest_save(0).is_empty() and not SaveService.load_save():
			progression_notice = "Salvataggio non valido conservato. Ripristinato l'ultimo checkpoint valido, se disponibile."
			for checkpoint in SaveService.list_saves():
				if checkpoint.slot == 0 and GameState.deserialize(JSON.parse_string(FileAccess.get_file_as_string(checkpoint.path))):
					break
		progression_loaded = true
	if not SaveService.apply_pending_owner_bonus():
		progression_notice = "Bonus locale non applicato: salvataggio non riuscito. Riprova al prossimo ingresso."
	elif progression_notice.begins_with("Bonus locale"):
		progression_notice=""
	# print("[SESSION_STATE] start_single_player() called")
	if current_state != ConnectionState.DISCONNECTED:
		# print("[SESSION_STATE] Not DISCONNECTED, current state: ", get_state_name())
		return
	# Single player: agiamo come host e client locale
	is_host = true
	local_peer_id = 1
	host_peer_id = 1
	players = [{
		"peer_id": 1,
		"name": local_player_name,
		"ready": true,
		"is_host": true
	}]
	GameState.reset_for_new_mission("C01")
	# Carica direttamente il settore senza networking
	transition_to(ConnectionState.LOADING)
	# Carica la scena del settore
	var sector_scene = preload("res://scenes/sector.tscn")
	pending_scene = sector_scene
	print("[SESSION_STATE] Calling _load_single_player_sector deferred")
	call_deferred("_load_single_player_sector", sector_scene)

func _load_single_player_sector(scene: PackedScene) -> void:
	# print("[SESSION_STATE] _load_single_player_sector() called")
	# Use change_scene_to_packed to properly free old scene and load new one
	get_tree().change_scene_to_packed(scene)
	# Note: mission_starting will be emitted from on_scene_loaded() after sector _ready()

func _enter_single_player_mission() -> void:
	# print("[SESSION_STATE] _enter_single_player_mission() called")
	transition_to(ConnectionState.MISSION)
	mission_starting.emit()

func on_connected(peer_id: int) -> void:
	local_peer_id = peer_id
	if is_host:
		host_peer_id = peer_id
		players = [{
			"peer_id": peer_id,
			"name": local_player_name,
			"ready": false,
			"is_host": true
		}]
		transition_to(ConnectionState.LOBBY)
		roster_updated.emit(players)
	else:
		transition_to(ConnectionState.HANDSHAKE)
		# Invia handshake
		NetworkGateway.send_handshake(protocol_version, build_id, content_hash, local_player_name)

func on_disconnected(peer_id: int) -> void:
	if current_state == ConnectionState.DISCONNECTED:
		return

	if is_host:
		# Host: rimuovi player disconnesso
		_remove_player(peer_id)
		if current_state == ConnectionState.MISSION:
			# Auto-deposita sacca (stub per ora)
			print("Client %d disconnesso durante missione - sacca auto-depositata" % peer_id)
		roster_updated.emit(players)
	else:
		# Client: perso host
		if peer_id == host_peer_id:
			mission_ended.emit("Host disconnesso")
			_cleanup_and_return_to_menu()

func _remove_player(peer_id: int) -> void:
	for i in range(players.size() - 1, -1, -1):
		if players[i].peer_id == peer_id:
			players.remove_at(i)
			break

func on_handshake_response(success: bool, reason: String, assigned_peer_id: int, roster: Array[Dictionary], host_id: int) -> void:
	if current_state != ConnectionState.HANDSHAKE:
		return

	if success:
		local_peer_id = assigned_peer_id
		host_peer_id = host_id
		players = roster
		transition_to(ConnectionState.LOBBY)
		roster_updated.emit(players)
	else:
		handshake_result.emit(false, reason if reason else "")
		transition_to(ConnectionState.DISCONNECTED)
		connection_failed.emit(reason if reason else "")

func set_ready(ready: bool) -> void:
	for p in players:
		if p.peer_id == local_peer_id:
			p.ready = ready
			break
	roster_updated.emit(players)
	NetworkGateway.send_ready(ready)

func on_player_ready(peer_id: int, ready: bool) -> void:
	for p in players:
		if p.peer_id == peer_id:
			p.ready = ready
			break
	roster_updated.emit(players)

func start_mission(scene: PackedScene) -> bool:
	if not is_host:
		return false
	if current_state != ConnectionState.LOBBY:
		return false

	# Verifica che tutti siano pronti (eccetto host se solo)
	var all_ready = true
	for p in players:
		if p.peer_id != host_peer_id and not p.ready:
			all_ready = false
			break

	if not all_ready:
		return false

	mission_id = "%d_%d" % [Time.get_ticks_msec(), Time.get_ticks_msec()]
	pending_scene = scene
	transition_to(ConnectionState.LOADING)
	NetworkGateway.send_start_loading(scene.resource_path)
	return true

func on_scene_loaded() -> void:
	# print("[SESSION_STATE] on_scene_loaded() called, current_state: ", get_state_name())
	if current_state != ConnectionState.LOADING:
		return

	# Check if single player mode
	var is_single_player = is_host and not NetworkGateway.is_network_connected()
	# print("[SESSION_STATE] is_single_player: ", is_single_player, " is_host: ", is_host, " network_connected: ", NetworkGateway.is_network_connected())

	if is_single_player:
		# Single player: transition directly to MISSION
		transition_to(ConnectionState.MISSION)
		mission_starting.emit()
		# print("[SESSION_STATE] Single player mission_starting emitted")
	else:
		# Multiplayer: send scene ready to host
		NetworkGateway.send_scene_ready()

# Chiamato dal client quando riceve rpc_start_loading
func on_start_loading(scene_path: String) -> void:
	if current_state == ConnectionState.LOBBY:
		transition_to(ConnectionState.LOADING)

func on_all_loaded() -> void:
	if not is_host:
		return

	transition_to(ConnectionState.READY)
	# Breve delay poi MISSION
	call_deferred("_enter_mission")

func _enter_mission() -> void:
	transition_to(ConnectionState.MISSION)
	mission_starting.emit()

var _returning_to_menu: bool = false

func _cleanup_and_return_to_menu() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Drain Area3D overlaps before freeing the player and the whole sector.
	# Otherwise Godot 4.3 may try to disconnect an already-freed body.
	var scene = get_tree().current_scene
	if is_instance_valid(scene):
		for player in get_tree().get_nodes_in_group("players"):
			player.set_deferred("collision_layer", 0)
			player.set_deferred("collision_mask", 0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for area in scene.find_children("*", "Area3D", true, false):
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
		await get_tree().physics_frame
		await get_tree().physics_frame
		# Remove bodies while their monitoring areas still exist, then the map.
		for player in get_tree().get_nodes_in_group("players"):
			player.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
	if not is_single_player_session:
		GameState.player_inventories.clear()
	is_single_player_session = false
	GameState.player_positions.clear()
	GameState.player_rotations.clear()
	is_host = false
	players.clear()
	local_peer_id = 0
	host_peer_id = 1
	mission_id = ""
	pending_scene = null
	transition_to(ConnectionState.DISCONNECTED)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	_returning_to_menu = false

func get_local_player() -> Dictionary:
	for p in players:
		if p.peer_id == local_peer_id:
			return p
	return {}

func is_all_ready() -> bool:
	for p in players:
		if p.peer_id != host_peer_id and not p.ready:
			return false
	return true
