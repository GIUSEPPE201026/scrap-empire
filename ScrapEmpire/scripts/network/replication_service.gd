## ReplicationService.gd
## Servizio replica: snapshot, interpolazione, gestione entità.
## Per MVP: stub con struttura base.

extends Node

# Riferimento all'autoload SessionState (inizializzato in _ready)
var session_state

signal entity_spawned(entity_id: String, def_id: String, transform: Transform3D, owner_peer: int)
signal entity_despawned(entity_id: String)
signal snapshot_received(tick: int, entities: Array[Dictionary])

# Configurazione rete
const SNAPSHOT_HZ: int = 10
const INTERPOLATION_MS: int = 100
const STALE_INPUT_MS: int = 250

var _snapshot_timer: float = 0.0
var _last_snapshot_tick: int = 0
var _entity_registry: Dictionary = {}  # entity_id -> {def_id, transform, state, reserved_peer, lease_deadline}

func _ready() -> void:
	set_process_mode(3)  # PROCESS_MODE_WHEN_PHYSICS
	session_state = get_node("/root/SessionState")

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	_snapshot_timer += delta
	if _snapshot_timer >= (1.0 / SNAPSHOT_HZ):
		_send_snapshot()
		_snapshot_timer = 0.0

	# Check leases
	check_leases()

func _send_snapshot() -> void:
	_last_snapshot_tick += 1
	var entities_data: Array[Dictionary] = []

	for entity_id in _entity_registry:
		var e = _entity_registry[entity_id]
		entities_data.append({
			"id": entity_id,
			"def_id": e.def_id,
			"transform": e.transform,
			"state": e.state,
			"reserved_peer": e.reserved_peer,
			"lease_deadline": e.lease_deadline
		})

	rpc("rpc_receive_snapshot", _last_snapshot_tick, entities_data)

@rpc("authority", "call_local", "unreliable")
func rpc_receive_snapshot(tick: int, entities: Array[Dictionary]) -> void:
	# Client: applica snapshot con interpolazione
	snapshot_received.emit(tick, entities)

	# Applica direttamente ai player controller
	for e_data in entities:
		if e_data.id.begins_with("player_"):
			_apply_snapshot_to_player(e_data)

func _apply_snapshot_to_player(e_data: Dictionary) -> void:
	# Estrae peer_id dall'entity_id (formato: "player_<peer_id>")
	var peer_id_str = e_data.id.replace("player_", "")
	var peer_id = peer_id_str.to_int()
	if peer_id == 0:
		return

	# Trova il player controller per questo peer
	for node in get_tree().get_nodes_in_group("players"):
		if node.owner_peer_id == peer_id:
			var state = {
				"position": e_data.transform.origin,
				"rotation": e_data.transform.basis.get_euler().y
			}
			node.receive_snapshot(state)
			# Aggiorna anche il transform dell'entità nel registry locale
			if _entity_registry.has(e_data.id):
				_entity_registry[e_data.id].transform = e_data.transform
			break

# Registrazione entità (solo host)
func register_entity(entity_id: String, def_id: String, transform: Transform3D) -> void:
	if not multiplayer.is_server():
		return
	_entity_registry[entity_id] = {
		"def_id": def_id,
		"transform": transform,
		"state": "available",
		"reserved_peer": 0,
		"lease_deadline": 0.0
	}
	entity_spawned.emit(entity_id, def_id, transform, 1)
	# Notifica i client via RPC
	rpc("rpc_entity_spawned", entity_id, def_id, transform, 1)

@rpc("authority", "call_local", "reliable")
func rpc_entity_spawned(entity_id: String, def_id: String, transform: Transform3D, owner_peer: int) -> void:
	# Client: emette il segnale localmente per chi è in ascolto
	entity_spawned.emit(entity_id, def_id, transform, owner_peer)

@rpc("authority", "call_local", "reliable")
func rpc_entity_despawned(entity_id: String) -> void:
	# Client: emette il segnale localmente per chi è in ascolto
	entity_despawned.emit(entity_id)

func unregister_entity(entity_id: String) -> void:
	if not multiplayer.is_server():
		return
	if _entity_registry.has(entity_id):
		_entity_registry.erase(entity_id)
		entity_despawned.emit(entity_id)
		# Notifica i client via RPC
		rpc("rpc_entity_despawned", entity_id)

func reserve_entity(entity_id: String, peer_id: int, lease_seconds: float = 3.0) -> bool:
	if not multiplayer.is_server():
		return false
	if not _entity_registry.has(entity_id):
		return false
	var e = _entity_registry[entity_id]
	if e.state != "available":
		return false
	e.state = "reserved"
	e.reserved_peer = peer_id
	e.lease_deadline = Time.get_ticks_msec() / 1000.0 + lease_seconds
	return true

func release_entity(entity_id: String, peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _entity_registry.has(entity_id):
		var e = _entity_registry[entity_id]
		if e.reserved_peer == peer_id:
			e.state = "available"
			e.reserved_peer = 0
			e.lease_deadline = 0.0

func consume_entity(entity_id: String, peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if not _entity_registry.has(entity_id):
		return false
	var e = _entity_registry[entity_id]
	if e.state != "reserved" or e.reserved_peer != peer_id:
		return false
	e.state = "consumed"
	entity_despawned.emit(entity_id)
	# Rimuovi dopo breve delay per sincronizzazione
	call_deferred("_delayed_remove", entity_id)
	return true

func _delayed_remove(entity_id: String) -> void:
	await get_tree().create_timer(0.1).timeout
	if _entity_registry.has(entity_id):
		_entity_registry.erase(entity_id)

func update_lease(entity_id: String, peer_id: int, lease_seconds: float = 3.0) -> bool:
	if not multiplayer.is_server():
		return false
	if not _entity_registry.has(entity_id):
		return false
	var e = _entity_registry[entity_id]
	if e.state != "reserved" or e.reserved_peer != peer_id:
		return false
	e.lease_deadline = Time.get_ticks_msec() / 1000.0 + lease_seconds
	return true

func check_leases() -> void:
	if not multiplayer.is_server():
		return
	var now = Time.get_ticks_msec() / 1000.0
	for entity_id in _entity_registry:
		var e = _entity_registry[entity_id]
		if e.state == "reserved" and now > e.lease_deadline:
			e.state = "available"
			e.reserved_peer = 0
			e.lease_deadline = 0.0

func get_entity(entity_id: String) -> Dictionary:
	return _entity_registry.get(entity_id, {})

func get_all_entities() -> Array[Dictionary]:
	var result = []
	for k in _entity_registry:
		var e = _entity_registry[k].duplicate()
		e.id = k
		result.append(e)
	return result

# Manifest settore per sincronizzazione iniziale
func generate_sector_manifest() -> Dictionary:
	var entities: Array[Dictionary] = []
	for entity_id in _entity_registry:
		var e = _entity_registry[entity_id]
		entities.append({
			"id": entity_id,
			"def_id": e.def_id,
			"transform": e.transform,
			"state": e.state
		})
	return {
		"protocol_version": 1,
		"content_hash": session_state.content_hash,
		"entities": entities
	}

func apply_sector_manifest(manifest: Dictionary) -> void:
	if manifest.content_hash != session_state.content_hash:
		push_error("Content hash mismatch nel manifest")
		return

	for e_data in manifest.entities:
		var entity_id = e_data.id
		if not _entity_registry.has(entity_id):
			_entity_registry[entity_id] = {
				"def_id": e_data.def_id,
				"transform": e_data.transform,
				"state": e_data.state,
				"reserved_peer": 0,
				"lease_deadline": 0.0
			}
			entity_spawned.emit(entity_id, e_data.def_id, e_data.transform, 1)