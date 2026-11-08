## EconomyService.gd
## Servizio economia: contratti, vendite, bonus, upgrade.
## Solo host autorità.

extends Node

signal contract_completed(contract_id: String, sale_value: int, bonus: int, total: int)
signal upgrade_purchased(category: String, level: int, cost: int)
signal credits_changed(new_balance: int)

# Riferimento all'autoload GameState (inizializzato in _ready)
var _game_state

func _ready() -> void:
	_game_state = get_node("/root/GameState")

# Avvia nuovo contratto
func start_contract(contract_id: String) -> bool:
	var contracts = _get_contract_defs()
	var contract = _find_contract(contracts, contract_id)
	if not contract:
		return false

	# Verifica prerequisiti
	if contract.requires and contract.requires not in _game_state.unlocked_contracts:
		return false

	_game_state.current_contract_id = contract_id
	_game_state.mission_phase = "MISSIONE"
	_game_state.sector_consumed_ids.clear()
	_game_state.sector_revision = 0
	return true

# Liquidazione missione
func settle_mission() -> Dictionary:
	return _game_state.settle_mission()

func sell_deposit() -> int:
	return _game_state.sell_deposit()

# Acquisto upgrade
func purchase_upgrade(category: String) -> bool:
	var current_level = _game_state.team_upgrade_levels[category]
	var next_level = current_level + 1
	var success = _game_state.purchase_upgrade(category, next_level)
	if success:
		var upgrades = _get_upgrade_defs(category)
		var upgrade = _find_upgrade(upgrades, next_level)
		if upgrade:
			upgrade_purchased.emit(category, next_level, upgrade.cost)
			credits_changed.emit(_game_state.team_credits)
	return success

# Verifica se può permettersi upgrade
func can_afford_upgrade(category: String) -> bool:
	var current_level = _game_state.team_upgrade_levels[category]
	var next_level = current_level + 1
	var upgrades = _get_upgrade_defs(category)
	var upgrade = _find_upgrade(upgrades, next_level)
	if not upgrade:
		return false
	return _game_state.team_credits >= upgrade.cost

# Ottieni costo prossimo upgrade
func get_next_upgrade_cost(category: String) -> int:
	var current_level = _game_state.team_upgrade_levels[category]
	var next_level = current_level + 1
	var upgrades = _get_upgrade_defs(category)
	var upgrade = _find_upgrade(upgrades, next_level)
	return upgrade.cost if upgrade else -1

# Ottieni effetto upgrade corrente
func get_upgrade_effect(category: String) -> Variant:
	return _game_state.get_upgrade_effect(category)

func _get_contract_defs() -> Array:
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		return []
	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	return balance.contracts if balance and balance.has("contracts") else []

func _find_contract(contracts: Array, id: String) -> Dictionary:
	for c in contracts:
		if c.id == id:
			return c
	return {}

func _get_upgrade_defs(category: String) -> Array:
	return _game_state._get_upgrade_defs(category)

func _find_upgrade(upgrades: Array, level: int) -> Dictionary:
	for u in upgrades:
		if u.level == level:
			return u
	return {}

func sell_surplus() -> int:
	var keep: Dictionary = _game_state.story.reserves()
	var revenue: int = _game_state.story.surplus_value()
	if revenue<=0:
		return 0
	var before: Dictionary = _game_state.serialize().duplicate(true)
	for material in _game_state.team_deposit_counts:
		_game_state.team_deposit_counts[material] = mini(int(_game_state.team_deposit_counts[material]),int(keep.materials.get(material,0)))
	_game_state.press_bales = mini(_game_state.press_bales,int(keep.bales))
	_game_state.team_credits += revenue
	return revenue if _game_state.ops._finish(before) else 0

