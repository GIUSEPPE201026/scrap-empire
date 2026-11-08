## CommandService.gd
## Servizio comandi: validazione e applicazione mutazioni host.
## Tutti i comandi mutanti passano attraverso qui (solo host).

extends Node

signal command_result(request_id: String, success: bool, code: String, revision: int, payload: Dictionary)
signal collection_completed(peer_id: int, entity_id: String, material_id: String)
signal deposit_completed(peer_id: int, value: int)
signal error_logged(peer_id: int, code: String, message: String)

# Riferimenti agli autoload (inizializzati in _ready per evitare problemi di ordine di caricamento)
var _game_state
var _inventory
var _economy
var _replication

# Cache anti-duplicazione richieste
var _request_cache: Dictionary = {}  # peer_id -> Array[{request_id, result, tick}]
const MAX_CACHE_PER_PEER: int = 256

# Codici errore
const OK_CODE: String = "OK"
const ERR_OUT_OF_RANGE: String = "OUT_OF_RANGE"
const ERR_FULL: String = "FULL"
const ERR_BUSY: String = "BUSY"
const ERR_INVALID_STATE: String = "INVALID_STATE"
const ERR_INSUFFICIENT_CREDITS: String = "INSUFFICIENT_CREDITS"
const ERR_VERSION_MISMATCH: String = "VERSION_MISMATCH"
const ERR_UNKNOWN_ENTITY: String = "UNKNOWN_ENTITY"
const ERR_LEASE_EXPIRED: String = "LEASE_EXPIRED"

func _ready() -> void:
	_game_state = get_node("/root/GameState")
	_inventory = get_node("/root/InventoryService")
	_economy = get_node("/root/EconomyService")
	_replication = get_node("/root/ReplicationService")

# Verifica duplicazione richiesta
func _check_duplicate(peer_id: int, request_id: String) -> Dictionary:
	if not _request_cache.has(peer_id):
		return {}

	var cache = _request_cache[peer_id]
	for entry in cache:
		if entry.request_id == request_id:
			return entry.result
	return {}

func _cache_result(peer_id: int, request_id: String, result: Dictionary) -> void:
	if not _request_cache.has(peer_id):
		_request_cache[peer_id] = []

	var cache = _request_cache[peer_id]
	cache.append({
		"request_id": request_id,
		"result": result,
		"tick": _game_state.sector_revision
	})

	# Limita dimensione cache
	if cache.size() > MAX_CACHE_PER_PEER:
		cache.pop_front()

# Inizia raccolta
func collect_begin(request_id: String, peer_id: int, entity_id: String) -> Dictionary:
	# Controllo duplicati
	var cached = _check_duplicate(peer_id, request_id)
	if not cached.is_empty():
		return cached

	# Verifica stato missione
	if _game_state.mission_phase != "MISSIONE":
		var result = _make_result(false, ERR_INVALID_STATE, "Non in fase missione")
		_cache_result(peer_id, request_id, result)
		return result

	# Verifica entità
	var entity = _replication.get_entity(entity_id)
	if entity.is_empty():
		var result = _make_result(false, ERR_UNKNOWN_ENTITY, "Entità sconosciuta")
		_cache_result(peer_id, request_id, result)
		return result

	if entity.state != "available":
		var result = _make_result(false, ERR_BUSY, "Oggetto non disponibile (stato: %s)" % entity.state)
		_cache_result(peer_id, request_id, result)
		return result

	# Verifica distanza e LOS (semplificato per MVP)
	var player_pos = _game_state.player_positions[peer_id]
	if player_pos:
		var dist = player_pos.distance_to(entity.transform.origin)
		if dist > _game_state.player_interaction_m:
			var result = _make_result(false, ERR_OUT_OF_RANGE, "Fuori portata")
			_cache_result(peer_id, request_id, result)
			return result

	# Riserva entità (lease 3s)
	var lease_sec = 3.0
	if not _replication.reserve_entity(entity_id, peer_id, lease_sec):
		var result = _make_result(false, ERR_BUSY, "Impossibile riservare")
		_cache_result(peer_id, request_id, result)
		return result

	var material_id = _get_material_from_def(entity.def_id)
	var result = _make_result(true, OK_CODE, "Raccolta iniziata", {
		"entity_id": entity_id,
		"material_id": material_id,
		"collect_seconds": _get_collect_time(material_id),
		"lease_deadline": Time.get_ticks_msec() / 1000.0 + lease_sec
	})
	_cache_result(peer_id, request_id, result)
	return result

# Completa raccolta
func collect_end(request_id: String, peer_id: int, entity_id: String) -> Dictionary:
	var cached = _check_duplicate(peer_id, request_id)
	if not cached.is_empty():
		return cached

	if _game_state.mission_phase != "MISSIONE":
		var result = _make_result(false, ERR_INVALID_STATE, "Non in fase missione")
		_cache_result(peer_id, request_id, result)
		return result

	var entity = _replication.get_entity(entity_id)
	if entity.is_empty():
		var result = _make_result(false, ERR_UNKNOWN_ENTITY, "Entità sconosciuta")
		_cache_result(peer_id, request_id, result)
		return result

	if entity.state != "reserved" or entity.reserved_peer != peer_id:
		var result = _make_result(false, ERR_LEASE_EXPIRED, "Lease scaduto o non tuo")
		_cache_result(peer_id, request_id, result)
		return result

	# Verifica distanza di nuovo
	var player_pos = _game_state.player_positions[peer_id]
	if player_pos:
		var dist = player_pos.distance_to(entity.transform.origin)
		if dist > _game_state.player_interaction_m + 0.5:  # Piccola tolleranza
			_replication.release_entity(entity_id, peer_id)
			var result = _make_result(false, ERR_OUT_OF_RANGE, "Fuori portata al completamento")
			_cache_result(peer_id, request_id, result)
			return result

	# Verifica capacità inventario
	var material_id = _get_material_from_def(entity.def_id)
	if not _inventory.can_collect(peer_id, material_id):
		_replication.release_entity(entity_id, peer_id)
		var result = _make_result(false, ERR_FULL, "Inventario pieno")
		_cache_result(peer_id, request_id, result)
		return result

	# Commit atomico: consuma entità + aggiungi inventario
	if _replication.consume_entity(entity_id, peer_id):
		if _inventory.add_item(peer_id, material_id):
			_game_state.mark_scrap_consumed(entity_id)
			collection_completed.emit(peer_id, entity_id, material_id)

			var result = _make_result(true, OK_CODE, "Raccolta completata", {
				"entity_id": entity_id,
				"material_id": material_id,
				"new_inventory": _inventory.get_inventory(peer_id)
			})
			_cache_result(peer_id, request_id, result)
			return result
		else:
			# Rollback: non dovrebbe succedere se can_collect ha passato
			push_error("Inconsistenza: can_collect true ma add_item false")
			var result = _make_result(false, ERR_BUSY, "Inconsistenza inventario")
			_cache_result(peer_id, request_id, result)
			return result
	else:
		var result = _make_result(false, ERR_BUSY, "Consumo fallito")
		_cache_result(peer_id, request_id, result)
		return result

# Deposito
func deposit(request_id: String, peer_id: int) -> Dictionary:
	var cached = _check_duplicate(peer_id, request_id)
	if not cached.is_empty():
		return cached

	if _game_state.mission_phase != "MISSIONE":
		var result = _make_result(false, ERR_INVALID_STATE, "Non in fase missione")
		_cache_result(peer_id, request_id, result)
		return result

	# Verifica zona deposito (semplificato: sempre vero per MVP)
	var player_pos = _game_state.player_positions[peer_id]
	# TODO: verifica distanza da tramoggia

	var deposited_value = _inventory.deposit_all(peer_id)
	if deposited_value > 0:
		deposit_completed.emit(peer_id, deposited_value)

	var result = _make_result(true, OK_CODE, "Deposito completato", {
		"deposited_value": deposited_value,
		"team_credits": _game_state.team_credits,
		"team_deposits": _game_state.team_deposit_counts
	})
	_cache_result(peer_id, request_id, result)
	return result

# Acquisto upgrade (solo host locale, validato qui per coerenza)
func buy_upgrade(request_id: String, category: String) -> Dictionary:
	var cached = _check_duplicate(1, request_id)  # Host usa peer_id 1
	if not cached.is_empty():
		return cached

	if _game_state.mission_phase != "OFFICINA":
		var result = _make_result(false, ERR_INVALID_STATE, "Solo in officina")
		_cache_result(1, request_id, result)
		return result

	if not _economy.can_afford_upgrade(category):
		var result = _make_result(false, ERR_INSUFFICIENT_CREDITS, "Bulloni insufficienti")
		_cache_result(1, request_id, result)
		return result

	var current_level = _game_state.team_upgrade_levels[category]
	var next_level = current_level + 1

	if _economy.purchase_upgrade(category):
		var result = _make_result(true, OK_CODE, "Upgrade acquistato", {
			"category": category,
			"level": next_level,
			"new_credits": _game_state.team_credits
		})
		_cache_result(1, request_id, result)
		return result
	else:
		var result = _make_result(false, ERR_BUSY, "Acquisto fallito")
		_cache_result(1, request_id, result)
		return result

func _make_result(success: bool, code: String, message: String, payload: Dictionary = {}) -> Dictionary:
	return {
		"success": success,
		"code": code,
		"message": message,
		"revision": _game_state.sector_revision,
		"payload": payload
	}

func _get_material_from_def(def_id: String) -> String:
	# def_id formato: "metal_001", "plastic_005", etc.
	if def_id.begins_with("metal"):
		return "metal"
	elif def_id.begins_with("plastic"):
		return "plastic"
	elif def_id.begins_with("electronics"):
		return "electronics"
	elif def_id.begins_with("copper"):
		return "copper"
	elif def_id.begins_with("aluminum"):
		return "aluminum"
	elif def_id.begins_with("glass"):
		return "glass"
	elif def_id.begins_with("rubber"):
		return "rubber"
	elif def_id.begins_with("textile"):
		return "textile"
	elif def_id.begins_with("hazardous"):
		return "hazardous"
	return "metal"

func _get_collect_time(material_id: String) -> float:
	var defs = _game_state.material_defs
	if defs.has(material_id):
		return defs[material_id].collect_seconds
	return 1.0

# Pulizia lease scaduti (chiamato periodicamente da host)
func cleanup_expired_leases() -> void:
	_replication.check_leases()
