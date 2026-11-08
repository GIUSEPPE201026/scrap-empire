## InventoryService.gd
## Servizio inventario: validazione capacità, trasferimento materiali.
## Solo host autorità - client invia intenzioni.

extends Node

signal inventory_full(peer_id: int, material_id: String)
signal item_added(peer_id: int, material_id: String, new_count: int)
signal item_removed(peer_id: int, material_id: String, new_count: int)

# Riferimento all'autoload GameState (inizializzato in _ready)
var _game_state

func _ready() -> void:
	_game_state = get_node("/root/GameState")

# Verifica se player può raccogliere materiale
func can_collect(peer_id: int, material_id: String) -> bool:
	return _game_state.can_add_to_inventory(peer_id, material_id)

# Aggiunge materiale all'inventario (chiamato da CommandService su host)
func add_item(peer_id: int, material_id: String) -> bool:
	var success = _game_state.add_to_inventory(peer_id, material_id)
	if success:
		var inv = _game_state.player_inventories[peer_id]
		var count = inv[material_id]
		item_added.emit(peer_id, material_id, count)
	else:
		inventory_full.emit(peer_id, material_id)
	return success

# Deposita tutto l'inventario (chiamato da CommandService su host)
func deposit_all(peer_id: int) -> int:
	return _game_state.deposit_inventory(peer_id)

# Ottieni massa inventario
func get_mass(peer_id: int) -> float:
	return _game_state.get_inventory_mass(peer_id)

# Ottieni valore inventario
func get_value(peer_id: int) -> int:
	return _game_state.get_inventory_value(peer_id)

# Ottieni inventario completo
func get_inventory(peer_id: int) -> Dictionary:
	return _game_state.player_inventories[peer_id] if _game_state.player_inventories.has(peer_id) else {"metal": 0, "plastic": 0, "electronics": 0}

# Capacità attuale (con upgrade)
func get_capacity() -> int:
	return _game_state.get_inventory_capacity(SessionState.local_peer_id)
