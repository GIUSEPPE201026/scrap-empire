## GameState.gd
## Singleton: stato di gioco per la missione corrente (vivente per sessione).
## Separato da SessionState per separazione responsabilità.

extends Node

var ops
var operations: Dictionary = {}
var specifics
var crafting
var fabrication
var story
var part_defs: Dictionary = {}
var bulk_defs: Array = []
var logistics_def: Dictionary = {}
var delivery_defs: Array = []
signal operations_changed
var applied_local_grants: Array = []
var tool_defs: Array = []
var order_defs: Array = []
var completed_orders: Array = []
var workshop_modules: Dictionary = {}
var module_defs: Dictionary = {}
var upgrade_defs: Dictionary = {}
var secrets_found: Array = []
var secret_defs: Array = []

signal inventory_changed(peer_id: int, inventory: Dictionary)
signal deposit_changed(credits: int, counts: Dictionary)
signal contract_progress_changed(current_value: int, target_value: int, clean_count: int, total_count: int)
signal credits_changed(new_balance: int)
signal upgrade_purchased(category: String, level: int)
signal machine_message(message: String)
signal land_unlocked(level: int)

var press_owned: bool = false
var press_bales: int = 0
var press_remaining: float = 0.0
var press_def: Dictionary = {}
var _press_tick: float = 0.0
var yard_level: int = 0
var land_defs: Array = []
var base_sector_counts: Dictionary = {}
var vehicle_level: int = 0
var vehicle_defs: Array = []
var salvage_defs: Dictionary = {}
var salvage_steps: Dictionary = {}

# Stato squadra (condiviso, solo host autorità)
var team_credits: int = 0
var team_deposit_counts: Dictionary = {"metal": 0, "plastic": 0, "electronics": 0, "copper": 0, "aluminum": 0, "glass": 0, "rubber": 0, "textile": 0, "hazardous": 0}
var team_upgrade_levels: Dictionary = {"bag": 0, "tool": 0, "movement": 0}
var unlocked_contracts: Array[String] = ["C01"]

# Stato missione corrente
var current_mission_id: String = ""
var current_contract_id: String = "C01"
var mission_phase: String = "OFFICINA"  # OFFICINA, CARICAMENTO, MISSIONE, RIEPILOGO, OFFICINA
var sector_initial_counts: Dictionary = {"metal": 25, "plastic": 20, "electronics": 10, "copper": 15, "aluminum": 15, "glass": 10, "rubber": 10, "textile": 10, "hazardous": 5}
var sector_consumed_ids: Array[String] = []
var sector_revision: int = 0
var local_travel: Dictionary = {}

# Stato per player (replicato)
var player_inventories: Dictionary = {}  # peer_id -> {metal: int, plastic: int, electronics: int, copper: int, aluminum: int, glass: int, rubber: int, textile: int, hazardous: int}
var player_positions: Dictionary = {}    # peer_id -> Vector3
var player_rotations: Dictionary = {}    # peer_id -> float (yaw)

# Costanti da balance
var player_capacity_kg: int = 20
var player_walk_mps: float = 4.5
var player_sprint_mps: float = 7.0
var player_interaction_m: float = 3.0
var material_defs: Dictionary = {}

func _ready() -> void:
	_load_balance()
	ops = preload("res://scripts/economy/yard_operations.gd").new(self)
	operations = ops.empty_state()
	specifics = preload("res://scripts/economy/specific_orders.gd").new(self)
	crafting = preload("res://scripts/economy/crafting.gd").new(self)
	fabrication = preload("res://scripts/economy/fabrication.gd").new(self)
	story = preload("res://scripts/economy/career.gd").new(self)

func _load_balance() -> void:
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		push_error("Impossibile caricare balance.json")
		return
	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	if not balance:
		push_error("JSON non valido")
		return

	player_capacity_kg = balance.player.capacity_kg
	player_walk_mps = balance.player.walk_mps
	player_sprint_mps = balance.player.sprint_mps
	player_interaction_m = balance.player.interaction_m
	material_defs = balance.materials
	press_def = balance.machines.press
	sector_initial_counts = balance.sector_counts.duplicate()
	base_sector_counts = sector_initial_counts.duplicate()
	land_defs = balance.land_expansions
	vehicle_defs = balance.vehicles
	salvage_defs = balance.salvage_objects
	secret_defs = balance.get("secrets", [])
	tool_defs = balance.tools
	order_defs = balance.orders
	part_defs = balance.parts
	bulk_defs = balance.bulk_salvage
	logistics_def = balance.logistics
	delivery_defs = balance.delivery_jobs
	module_defs = balance.workshop_modules
	upgrade_defs = balance.upgrades
	team_upgrade_levels = {"bag": 0, "tool": 0, "movement": 0}
	unlocked_contracts = ["C01"]

func reset_for_new_mission(contract_id: String, fresh_haul: bool = false) -> bool:
	var local_resume: bool = SessionState.is_single_player_session and not fresh_haul and int(operations.get("epoch",0))>0
	if fresh_haul and SessionState.is_single_player_session and get_inventory_mass(1)>0:
		return false
	var before_ids: Array[String] = sector_consumed_ids.duplicate()
	var before_revision: int = sector_revision
	var before_bags: Dictionary = player_inventories.duplicate(true)
	if not local_resume:
		sector_consumed_ids.clear()
		sector_revision = 0
	if ops != null and not ops.begin_expedition(fresh_haul):
		sector_consumed_ids = before_ids
		sector_revision = before_revision
		player_inventories = before_bags
		return false
	salvage_steps.clear()
	sector_initial_counts = base_sector_counts.duplicate()
	for land in land_defs:
		if int(land.level)<=yard_level:
			sector_initial_counts.merge(land.materials,true)
	current_contract_id = contract_id
	mission_phase = "MISSIONE"
	if not local_resume:
		player_inventories.clear()
	for peer in SessionState.players:
		if local_resume and int(peer.peer_id)==1 and player_inventories.has(1):
			continue
		var bag: Dictionary = {}
		for material in material_defs:
			bag[material] = 0
		player_inventories[peer.peer_id] = bag
	return true

func get_inventory_mass(peer_id: int) -> float:
	var inv = player_inventories.get(peer_id, {})
	if not inv:
		return 0.0
	var mass = specifics.mass("bag") if peer_id==1 and specifics!=null else 0.0
	for mat_id in inv:
		var count = inv[mat_id]
		var def = material_defs[mat_id]
		if def:
			mass += count * def.mass_kg
	return mass

func get_inventory_value(peer_id: int) -> int:
	var inv = player_inventories.get(peer_id, {})
	if not inv:
		return 0
	var value = 0
	for mat_id in inv:
		var count = inv[mat_id]
		var def = material_defs[mat_id]
		if def:
			value += count * def.credits
	return value

func get_inventory_capacity(peer_id: int) -> int:
	# Restituisce la capacità dello zaino in kg (include upgrade bag)
	var level = team_upgrade_levels["bag"]
	if level == 0:
		return player_capacity_kg
	var upgrades = _get_upgrade_defs("bag")
	var upgrade = _find_upgrade(upgrades, level)
	if upgrade:
		return upgrade.capacity_kg
	return player_capacity_kg

func can_add_to_inventory(peer_id: int, material_id: String) -> bool:
	var current_mass = get_inventory_mass(peer_id)
	var mat = material_defs.get(material_id, {})
	if not mat:
		return false
	return player_inventories.has(peer_id) and (current_mass + mat.mass_kg) <= get_inventory_capacity(peer_id)

func add_to_inventory(peer_id: int, material_id: String) -> bool:
	if not can_add_to_inventory(peer_id, material_id):
		return false

	var inv = player_inventories[peer_id]
	if not inv:
		inv = {"metal": 0, "plastic": 0, "electronics": 0}
		player_inventories[peer_id] = inv

	inv[material_id] = inv.get(material_id, 0) + 1
	inventory_changed.emit(peer_id, inv.duplicate())
	return true

func deposit_inventory(peer_id: int) -> int:
	if peer_id==1 and (specifics.mass("bag")>0 or not NetworkGateway.is_network_connected()):
		if not player_inventories.has(peer_id):
			return 0
		var value: int = get_inventory_value(peer_id)+(1 if specifics.mass("bag")>0 else 0)
		return value if ops.store_bag(peer_id) else 0
	var inv = player_inventories[peer_id]
	if not inv:
		return 0

	var deposited_value = 0
	for mat_id in inv:
		var count = inv[mat_id]
		if count > 0:
			team_deposit_counts[mat_id] = team_deposit_counts.get(mat_id, 0) + count
			var def = material_defs[mat_id]
			if def:
				deposited_value += count * def.credits
			inv[mat_id] = 0

	deposit_changed.emit(team_credits, team_deposit_counts.duplicate())
	inventory_changed.emit(peer_id, inv.duplicate())
	credits_changed.emit(team_credits)
	return deposited_value

func settle_mission() -> Dictionary:
	if mission_phase != "MISSIONE":
		return {"success": false, "reason": "Non in missione"}

	mission_phase = "RIEPILOGO"

	# Calcola vendita e bonus
	var contract = _get_current_contract()
	var sale_value = 0
	for mat_id in team_deposit_counts:
		var count = team_deposit_counts[mat_id]
		var def = material_defs[mat_id]
		if def:
			sale_value += count * def.credits

	var clean_count = sector_consumed_ids.size()
	var total_count = 0
	for c in sector_initial_counts.values():
		total_count += c

	var bonus = 0
	var contract_met = false
	if sale_value >= contract.deposit_value_min and clean_count >= contract.clean_count_min:
		bonus = contract.bonus
		contract_met = true

	var total_revenue = sale_value + bonus
	for material_id in team_deposit_counts:
		team_deposit_counts[material_id] = 0
	team_credits += total_revenue

	# Marca missione liquidata
	current_mission_id = ""
	sector_consumed_ids.clear()

	credits_changed.emit(team_credits)
	deposit_changed.emit(team_credits, team_deposit_counts.duplicate())

	return {
		"success": true,
		"sale_value": sale_value,
		"clean_count": clean_count,
		"total_count": total_count,
		"bonus": bonus,
		"contract_met": contract_met,
		"total_revenue": total_revenue,
		"new_balance": team_credits
	}

func purchase_upgrade(category: String, next_level: int) -> bool:
	if not team_upgrade_levels.has(category) or next_level != team_upgrade_levels[category] + 1:
		return false
	var upgrades = _get_upgrade_defs(category)
	var upgrade = _find_upgrade(upgrades, next_level)
	if not upgrade:
		return false

	if team_credits < upgrade.cost:
		return false

	team_credits -= upgrade.cost
	team_upgrade_levels[category] = next_level
	credits_changed.emit(team_credits)
	upgrade_purchased.emit(category, next_level)
	return true

func get_upgrade_effect(category: String) -> Variant:
	var level = team_upgrade_levels[category]
	if level == 0:
		return _get_base_value(category)

	var upgrades = _get_upgrade_defs(category)
	var upgrade = _find_upgrade(upgrades, level)
	if not upgrade:
		return _get_base_value(category)

	match category:
		"bag": return upgrade.capacity_kg
		"tool": return upgrade.time_multiplier
		"movement": return upgrade.speed_multiplier
	return _get_base_value(category)

func _get_base_value(category: String) -> Variant:
	match category:
		"bag": return player_capacity_kg
		"tool": return 1.0
		"movement": return 1.0
	return 1.0

func _get_upgrade_defs(category: String) -> Array:
	return upgrade_defs.get(category, [])

func _find_upgrade(upgrades: Array, level: int) -> Dictionary:
	for u in upgrades:
		if u.level == level:
			return u
	return {}

func _get_current_contract() -> Dictionary:
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		return {}
	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	if not balance:
		return {}

	for c in balance.contracts:
		if c.id == current_contract_id:
			return c
	return {}

func mark_scrap_consumed(entity_id: String) -> void:
	if entity_id in sector_consumed_ids:
		return
	sector_consumed_ids.append(entity_id)
	sector_revision += 1

	var clean_count = sector_consumed_ids.size()
	var total_count = 0
	for c in sector_initial_counts.values():
		total_count += c

	var sale_value = 0
	for mat_id in team_deposit_counts:
		var count = team_deposit_counts[mat_id]
		var def = material_defs[mat_id]
		if def:
			sale_value += count * def.credits

	var contract_data = _get_current_contract()
	var deposit_min = contract_data.deposit_value_min if contract_data.has("deposit_value_min") else 0
	contract_progress_changed.emit(sale_value, deposit_min, clean_count, total_count)

func serialize() -> Dictionary:
	var result: Dictionary = {
		"schema_version": 2,
		"operations": operations.duplicate(true),
		"yard_level": yard_level,
		"vehicle_level": vehicle_level,
		"press": {"owned": press_owned, "bales": press_bales, "remaining_seconds": press_remaining},
		"content_version": 1,
		"save_id": str(Time.get_ticks_msec()),
		"checkpoint_revision": sector_revision,
		"team_credits": team_credits,
		"applied_local_grants": applied_local_grants.duplicate(),
		"secrets_found": secrets_found.duplicate(),
		"completed_orders": completed_orders.duplicate(),
		"workshop_modules": workshop_modules.duplicate(),
		"team_deposit_counts": team_deposit_counts,
		"team_upgrade_levels": team_upgrade_levels,
		"unlocked_contracts": unlocked_contracts,
		"completed_mission_ids": []  # Stub
	}
	if not NetworkGateway.is_network_connected():
		result.local_expedition = preload("res://scripts/save/expedition_snapshot.gd").capture(self)
	return result

func deserialize(data: Dictionary) -> bool:
	if not SaveService._validate_save_schema(data):
		return false
	if not data.has("schema_version") or (data.schema_version != 1 and data.schema_version != 2):
		push_error("Schema version mismatch")
		return false

	operations = preload("res://scripts/economy/yard_operations.gd").normalized_data(data.get("operations",preload("res://scripts/economy/yard_operations.gd").empty_state()))
	applied_local_grants = data.get("applied_local_grants", []).duplicate()
	secrets_found = data.get("secrets_found", []).duplicate()
	completed_orders = data.get("completed_orders", []).duplicate()
	workshop_modules = data.get("workshop_modules", {}).duplicate()
	team_credits = data.team_credits if data.has("team_credits") else 0
	team_deposit_counts = data.team_deposit_counts if data.has("team_deposit_counts") else {"metal": 0, "plastic": 0, "electronics": 0}
	team_upgrade_levels = data.team_upgrade_levels if data.has("team_upgrade_levels") else {"bag": 0, "tool": 0, "movement": 0}
	unlocked_contracts.assign(data.unlocked_contracts)
	var press_data: Dictionary = data.get("press", {}) if data.schema_version == 2 else {}
	press_owned = press_data.get("owned", false)
	press_bales = int(press_data.get("bales", 0))
	press_remaining = float(press_data.get("remaining_seconds", 0.0))
	_press_tick = 0.0
	yard_level = int(data.get("yard_level", 0))
	vehicle_level = int(data.get("vehicle_level", 0))
	if not NetworkGateway.is_network_connected():
		preload("res://scripts/save/expedition_snapshot.gd").apply(self,data.get("local_expedition",{}))
	return true

func sell_deposit() -> int:
	if get_deposit_value()<=0:
		return 0
	var before: Dictionary = serialize().duplicate(true)
	var revenue: int = press_bales * get_bale_value()
	press_bales = 0
	for material_id in team_deposit_counts:
		revenue += int(team_deposit_counts[material_id]) * int(material_defs[material_id].credits)
		team_deposit_counts[material_id] = 0
	team_credits += revenue
	return revenue if ops._finish(before) else 0

func get_bale_value() -> int:
	return int(press_def.input_units * material_defs[press_def.input_material].credits * press_def.value_multiplier)

func claim_salvage(entity_id: String, definition_id: String, expected_stage: int, peer_id: int, tool: int = 0) -> Dictionary:
	if not salvage_defs.has(definition_id) or not player_inventories.has(peer_id):
		return {"success": false, "message": "Oggetto non disponibile."}
	var steps: Array = salvage_defs[definition_id].steps
	var stage: int = int(salvage_steps.get(entity_id, 0))
	if expected_stage != stage or stage >= steps.size():
		return {"success": false, "message": "Fase già completata."}
	var step: Dictionary = steps[stage]
	if not owns_tool(tool) or tool != int(step.get("tool", 0)):
		return {"success": false, "message": Localization.format_text("Serve %s [%d].", [tool_defs[int(step.get("tool", 0))].name, int(step.get("tool", 0)) + 1])}
	if yard_level < int(step.land):
		return {"success": false, "message": "Servono attrezzature del Lotto Est: acquistalo al garage."}
	var added_mass: float = 0
	for material_id in step["yield"]:
		added_mass += int(step["yield"][material_id]) * float(material_defs[material_id].mass_kg)
	if get_inventory_mass(peer_id) + added_mass > get_inventory_capacity(peer_id):
		return {"success": false, "message": "Sacca piena: serve spazio per l'intera fase (%.0f kg)." % added_mass}
	var inventory: Dictionary = player_inventories[peer_id]
	for material_id in step["yield"]:
		inventory[material_id] = inventory.get(material_id, 0) + int(step["yield"][material_id])
	salvage_steps[entity_id] = stage + 1
	inventory_changed.emit(peer_id, inventory.duplicate())
	return {"success": true, "message": "%s completato · +%.0f kg recuperati." % [step.name, added_mass], "materials": step["yield"].duplicate()}

func purchase_vehicle() -> bool:
	if vehicle_level >= vehicle_defs.size():
		return false
	var definition: Dictionary = vehicle_defs[vehicle_level]
	if yard_level < int(definition.requires_land) or team_credits < int(definition.cost):
		return false
	team_credits -= int(definition.cost)
	vehicle_level += 1
	if not SaveService.save_checkpoint():
		vehicle_level -= 1
		team_credits += int(definition.cost)
		return false
	credits_changed.emit(team_credits)
	return true

func sell_material(material_id: String, amount: int = 1) -> int:
	if amount <= 0 or not material_defs.has(material_id) or team_deposit_counts.get(material_id, 0) < amount:
		return 0
	team_deposit_counts[material_id] -= amount
	var value: int = int(material_defs[material_id].credits) * amount
	team_credits += value
	credits_changed.emit(team_credits)
	deposit_changed.emit(team_credits, team_deposit_counts.duplicate())
	return value

func sell_inventory_item(peer_id: int, material_id: String) -> int:
	if not material_defs.has(material_id) or not player_inventories.has(peer_id):
		return 0
	var inventory: Dictionary = player_inventories[peer_id]
	if inventory.get(material_id, 0) <= 0:
		return 0
	inventory[material_id] -= 1
	var value: int = int(material_defs[material_id].credits)
	team_credits += value
	inventory_changed.emit(peer_id, inventory.duplicate())
	credits_changed.emit(team_credits)
	return value

func purchase_land() -> bool:
	if not land_requirement_message().is_empty():
		return false
	var definition: Dictionary = land_defs[yard_level]
	var snapshot: Dictionary = serialize().duplicate(true)
	team_credits -= int(definition.cost)
	for id in definition.get("project_materials", {}):
		team_deposit_counts[id] -= int(definition.project_materials[id])
	yard_level += 1
	if not SaveService.save_checkpoint():
		deserialize(snapshot)
		return false
	credits_changed.emit(team_credits)
	deposit_changed.emit(team_credits, team_deposit_counts.duplicate())
	land_unlocked.emit(yard_level)
	machine_message.emit(Localization.text("Lotto aperto! Passa dal varco Est: rottami e scarico satellite già disponibili."))
	return true

func get_deposit_value() -> int:
	var value: int = press_bales * get_bale_value()
	for material_id in team_deposit_counts:
		value += int(team_deposit_counts[material_id]) * int(material_defs[material_id].credits)
	return value

func purchase_press() -> bool:
	if press_owned or team_credits < int(press_def.cost):
		return false
	team_credits -= int(press_def.cost)
	press_owned = true
	if not SaveService.save_checkpoint():
		press_owned = false
		team_credits += int(press_def.cost)
		machine_message.emit(Localization.text("Acquisto annullato: salvataggio non riuscito."))
		return false
	credits_changed.emit(team_credits)
	machine_message.emit(Localization.text("Pressa acquistata! Deposita metallo e avvia un ciclo."))
	return true

func start_press() -> bool:
	if press_remaining > 0:
		return false
	return ops.enqueue_press(1)

func _process(delta: float) -> void:
	if ops == null or not SessionState.is_host or NetworkGateway.is_network_connected() or mission_phase != "MISSIONE":
		return
	fabrication.tick(delta)
	if press_remaining <= 0:
		if bool(operations.autofeed) and team_deposit_counts.metal >= int(press_def.input_units):
			ops.enqueue_press(1)
		else:
			return
	_press_tick += delta
	if _press_tick < 0.2:
		return
	var elapsed: float = _press_tick
	_press_tick = 0.0
	var produced: int = 0
	while press_remaining > 0 and elapsed >= press_remaining:
		elapsed -= press_remaining
		press_remaining = 0.0
		press_bales += 1
		produced += 1
		if int(operations.press_queue) > 0:
			operations.press_queue -= 1
			press_remaining = press_cycle_seconds()
	if press_remaining > 0:
		press_remaining = maxf(0,press_remaining-elapsed)
	if produced > 0:
		deposit_changed.emit(team_credits,team_deposit_counts.duplicate())
		operations_changed.emit()
		if not SaveService.save_checkpoint():
			machine_message.emit(Localization.text("Produzione in memoria: salva prima di uscire."))
		else:
			machine_message.emit(Localization.format_text("Pressa: %d balle pronte, %d lotti in coda.", [press_bales,operations.press_queue]))

func discover_secret(id: String) -> bool:
	if id in secrets_found:
		return false
	for definition in secret_defs:
		if definition.id != id:
			continue
		var before: int = team_credits
		team_credits += int(definition.reward)
		secrets_found.append(id)
		if not SaveService.save_checkpoint():
			team_credits = before
			secrets_found.erase(id)
			return false
		credits_changed.emit(team_credits)
		machine_message.emit(Localization.format_text("Curiosità scoperta: %s · +%d Bulloni!", [definition.name, definition.reward]))
		return true
	return false
func owns_tool(tool: int) -> bool:
	if tool<0 or tool>=tool_defs.size():
		return false
	return tool<=int(team_upgrade_levels.tool) if tool<3 else int(crafting.data().stock.get(tool_defs[tool].id,0))>0

func recovery_allowed(material_id: String, tool: int) -> bool:
	if not material_defs.has(material_id) or not owns_tool(tool):
		return false
	for allowed in material_defs[material_id].get("tools", [0]):
		if int(allowed) == tool:
			return true
	return false

func recovery_seconds(material_id: String, tool: int) -> float:
	if not recovery_allowed(material_id, tool):
		return 0
	return float(material_defs[material_id].collect_seconds) * float(tool_defs[tool].multipliers.get(material_id, 1.0)) * module_effect("gloves")

func recover_world_scrap(peer: int, entity: String, material_id: String, tool: int) -> bool:
	if not recovery_allowed(material_id, tool) or not player_inventories.has(peer) or entity in sector_consumed_ids:
		return false
	var unit: int = entity.get_slice("_", 1).to_int()
	if unit < 0 or unit >= int(sector_initial_counts.get(material_id, 0)) or entity != "%s_%03d" % [material_id, unit]:
		return false
	if not can_add_to_inventory(peer, material_id):
		return false
	var variant: int = preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(entity)
	var family: int = preload("res://scripts/economy/specific_orders.gd").MATERIALS.find(material_id)
	var key: String = "%d_%d" % [family,variant]
	if peer==1 and specifics.needs(key):
		return specifics.capture(key,entity)
	player_inventories[peer][material_id] += 1
	mark_scrap_consumed(entity)
	inventory_changed.emit(peer, player_inventories[peer].duplicate())
	return true

func land_requirement_message() -> String:
	if yard_level >= land_defs.size():
		return "Tutti i lotti sono già tuoi."
	var definition: Dictionary = land_defs[yard_level]
	if team_credits < int(definition.cost):
		return Localization.text("Servono %d Bulloni.") % definition.cost
	if not owns_tool(int(definition.get("requires_tool", 0))):
		return "Acquista prima: " + tool_defs[int(definition.requires_tool)].name
	for id in definition.get("project_materials", {}):
		if team_deposit_counts.get(id, 0) < int(definition.project_materials[id]):
			return "Deposita i materiali del progetto alla bilancia."
	return ""

func current_order() -> Dictionary:
	return {} if completed_orders.size() >= order_defs.size() else order_defs[completed_orders.size()]

func can_complete_order() -> bool:
	var order: Dictionary = current_order()
	if order.is_empty() or not order_requirement().is_empty() or press_bales < int(order.bales):
		return false
	for id in order.materials:
		if int(team_deposit_counts.get(id, 0)) < int(order.materials[id]):
			return false
	return true

func complete_order(expected_id: String) -> bool:
	var order: Dictionary = current_order()
	if order.is_empty() or order.id != expected_id or not can_complete_order():
		return false
	var snapshot: Dictionary = serialize().duplicate(true)
	for id in order.materials:
		team_deposit_counts[id] -= int(order.materials[id])
	press_bales -= int(order.bales)
	completed_orders.append(order.id)
	team_credits += int(order.reward)
	if not SaveService.save_checkpoint():
		deserialize(snapshot)
		return false
	credits_changed.emit(team_credits)
	deposit_changed.emit(team_credits, team_deposit_counts.duplicate())
	machine_message.emit(Localization.format_text("Commessa completata: %s · +%d Bulloni", [order.name, order.reward]))
	return true
func module_effect(id: String) -> float:
	var level: int = int(workshop_modules.get(id, 0))
	if level == 0 or not module_defs.has(id):
		return 1.0
	return float(module_defs[id].levels[level - 1].effect)

func press_cycle_seconds() -> float:
	return float(press_def.cycle_seconds) * module_effect("press_drive") * (0.9 if story.has_project("production") else 1.0)

func module_requirement(id: String, include_cost: bool = true) -> String:
	if not module_defs.has(id):
		return "Modulo sconosciuto."
	var definition: Dictionary = module_defs[id]
	var level: int = int(workshop_modules.get(id, 0))
	if level >= definition.levels.size():
		return "Modulo completo."
	if completed_orders.size() < int(definition.levels[level].orders):
		return Localization.format_text("Completa %d commesse (%d/%d).", [definition.levels[level].orders, completed_orders.size(), definition.levels[level].orders])
	if int(operations.deliveries)<int(definition.levels[level].get("deliveries",0)):
		return Localization.format_text("Completa %d forniture (%d/%d).", [definition.levels[level].deliveries,operations.deliveries,definition.levels[level].deliveries])
	if definition.requires == "buggy" and vehicle_level < 2:
		return "Acquista il buggy al garage."
	if definition.requires == "vehicle" and vehicle_level == 0:
		return "Acquista un mezzo al garage."
	if definition.requires == "tool" and not owns_tool(1):
		return "Acquista il cacciavite."
	if definition.requires == "industrial" and not ["forklift","crane","loader"].any(func(kind):return preload("res://scripts/economy/extra_mobility.gd").owned(kind)):
		return "Acquista un muletto, una gru o una minipala."
	if definition.requires == "press" and not press_owned:
		return "Installa la pressa."
	if include_cost and team_credits < int(definition.levels[level].cost):
		return Localization.text("Servono %d Bulloni.") % definition.levels[level].cost
	return ""

func purchase_module(id: String) -> bool:
	if not module_requirement(id).is_empty():
		return false
	var snapshot: Dictionary = serialize().duplicate(true)
	var level: int = int(workshop_modules.get(id, 0))
	team_credits -= int(module_defs[id].levels[level].cost)
	workshop_modules[id] = level + 1
	if not SaveService.save_checkpoint():
		deserialize(snapshot)
		return false
	credits_changed.emit(team_credits)
	upgrade_purchased.emit(id, level + 1)
	operations_changed.emit()
	machine_message.emit(Localization.format_text("%s · livello %d installato.", [module_defs[id].name, level + 1]))
	return true

func order_requirement() -> String:
	var order: Dictionary = current_order()
	if order.is_empty():
		return ""
	if yard_level < int(order.get("requires_land", 0)):
		return "Apri il Lotto delle dune alla planimetria."
	if vehicle_level < int(order.get("requires_vehicle", 0)):
		return "Acquista il buggy al garage."
	return ""



