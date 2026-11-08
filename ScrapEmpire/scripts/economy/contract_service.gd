## ContractService.gd
## Servizio contratti: definizioni, progresso, sblocchi.

extends Node

signal contract_progress(contract_id: String, deposit_value: int, clean_count: int, total: int)
signal contract_unlocked(contract_id: String)

# Riferimento all'autoload GameState (inizializzato in _ready)
var _game_state

func _ready() -> void:
	_game_state = get_node("/root/GameState")

func get_available_contracts() -> Array[Dictionary]:
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		return []
	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	if not balance:
		return []

	var result = []
	for c in balance.contracts:
		var unlocked = c.id in _game_state.unlocked_contracts
		var available = true
		if c.requires and c.requires not in _game_state.unlocked_contracts:
			available = false
		result.append({
			"id": c.id,
			"deposit_value_min": c.deposit_value_min,
			"clean_count_min": c.clean_count_min,
			"bonus": c.bonus,
			"requires": c.requires,
			"unlocked": unlocked,
			"available": available
		})
	return result

func get_current_contract() -> Dictionary:
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		return {}
	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	if not balance:
		return {}

	for c in balance.contracts:
		if c.id == _game_state.current_contract_id:
			return {
				"id": c.id,
				"deposit_value_min": c.deposit_value_min,
				"clean_count_min": c.clean_count_min,
				"bonus": c.bonus,
				"requires": c.requires
			}
	return {}

func check_contract_completion() -> bool:
	var contract = get_current_contract()
	if not contract:
		return false

	var sale_value = 0
	for mat_id in _game_state.team_deposit_counts:
		var count = _game_state.team_deposit_counts[mat_id]
		var def = _game_state.material_defs[mat_id]
		if def:
			sale_value += count * def.credits

	var clean_count = _game_state.sector_consumed_ids.size()
	var total_count = 0
	for c in _game_state.sector_initial_counts.values():
		total_count += c

	var deposit_met = sale_value >= contract.deposit_value_min
	var clean_met = clean_count >= contract.clean_count_min

	contract_progress.emit(contract.id, sale_value, clean_count, total_count)

	return deposit_met and clean_met

func unlock_next_contract() -> void:
	var current = _game_state.current_contract_id
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		return
	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	if not balance:
		return

	for c in balance.contracts:
		if c.requires == current and c.id not in _game_state.unlocked_contracts:
			_game_state.unlocked_contracts.append(c.id)
			contract_unlocked.emit(c.id)
			break