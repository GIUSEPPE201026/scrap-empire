extends RefCounted
## Single-player logistics and component transactions share the existing checkpoint.
var state

func _init(game_state) -> void:
	state = game_state

func visit_site(id: String) -> bool:
	if id not in ["crash","cave","anomaly"] or id in state.operations.get("visited_sites",[]): return false
	var before: Dictionary=state.serialize().duplicate(true)
	state.operations["visited_sites"]=state.operations.get("visited_sites",[]).duplicate()
	state.operations.visited_sites.append(id)
	return _finish(before)

func record_lap(vehicle: int, seconds: float) -> bool:
	if vehicle not in [1,2,3,4] or not is_finite(seconds) or seconds<1 or seconds>3600: return false
	var key: String=str(vehicle)
	var records: Dictionary=state.operations.get("park_records",{})
	if seconds>=float(records.get(key,INF)): return false
	var before: Dictionary=state.serialize().duplicate(true)
	state.operations["park_records"]=records.duplicate()
	state.operations.park_records[key]=seconds
	return _finish(before)

static func empty_state() -> Dictionary:
	return {"epoch":0,"serial":0,"cargo":{},"cargo_parts":[],"stored_parts":[],"held":{},"field":{},"claims":{},"press_queue":0,"autofeed":false,"deliveries":0,"active_delivery":{}}

static func normalized_data(source: Dictionary) -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	for key in ["epoch","serial","press_queue","deliveries"]:
		data[key] = int(data[key])
	for material in data.cargo:
		data.cargo[material] = int(data.cargo[material])
	var items: Array = data.cargo_parts.duplicate()
	items.append_array(data.stored_parts)
	items.append_array(data.field.values())
	for job in data.get("crafting",{}).get("queue",[]):
		items.append_array(job.parts)
	if not data.held.is_empty():
		items.append(data.held)
	for item in items:
		item.quality = int(item.quality)
	for key in data.claims:
		if data.claims[key] is Array:
			data.claims[key] = data.claims[key].map(func(value): return int(value))
	if not data.active_delivery.is_empty():
		data.active_delivery.ticket = int(data.active_delivery.ticket)
	for id in data.get("delivery_history",{}):
		data.delivery_history[id]=int(data.delivery_history[id])
	return data

func _finish(before: Dictionary, bags: Dictionary = {}) -> bool:
	if not SaveService.save_checkpoint():
		state.deserialize(before)
		if not bags.is_empty():
			state.player_inventories = bags
		state.machine_message.emit(Localization.text("Operazione annullata: checkpoint non riuscito."))
		return false
	if state.player_inventories.has(1):
		state.inventory_changed.emit(1,state.player_inventories[1].duplicate())
	state.deposit_changed.emit(state.team_credits,state.team_deposit_counts.duplicate())
	state.credits_changed.emit(state.team_credits)
	state.operations_changed.emit()
	return true

func begin_expedition(fresh: bool = false) -> bool:
	if not fresh and int(state.operations.epoch) > 0:
		return true
	if fresh:
		for item in state.crafting.data().objects.values():
			if not item.get("hitch","").is_empty():
				state.machine_message.emit(Localization.text("Sgancia il carrello prima di iniziare una nuova spedizione."))
				return false
	if fresh and not state.operations.held.is_empty():
		return false
	if fresh and cargo_mass()>0:
		state.machine_message.emit(Localization.text("Scarica il cassone prima di rinnovare il settore."))
		return false
	if fresh:
		for item in state.operations.field.values():
			if item.get("dropped",false):
				state.machine_message.emit(Localization.text("Recupera il componente lasciato a terra prima di rinnovare il settore."))
				return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.epoch += 1
	state.operations.field.clear()
	state.operations.claims.clear()
	state.operations.erase("loose_positions")
	state.operations.erase("loose_rotations")
	state.operations.erase("pile_layers")
	return _finish(before)

func seed_field_parts() -> void:
	var changed: bool = false
	for spec in state.bulk_defs:
		if int(spec.land) > state.yard_level:
			continue
		var id: String = "e%d_%s" % [state.operations.epoch,spec.id]
		# Issued identities stay recorded even after unloading or selling.
		if state.operations.claims.has("issued_"+id):
			continue
		state.operations.field[id] = {"id":id,"kind":spec.kind,"quality":int(spec.quality),"position":spec.position.duplicate(),"dropped":false}
		if maxf(absf(float(spec.position[0])),absf(float(spec.position[2]))) > 83:
			var point = Vector3(spec.position[0],0,spec.position[2])
			state.operations.field[id].position[1] = preload("res://scripts/gameplay/desert_world.gd").height_at(point)+0.08
		state.operations.claims["issued_"+id] = true
		changed = true
	if changed:
		SaveService.save_checkpoint()

func record_discovery(type: int, variant: int) -> bool:
	var key: String = "%d_%d" % [type,variant]
	var album: Array = state.operations.get("scrap_album",[])
	if key in album:
		return true
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.scrap_album = album.duplicate()
	state.operations.scrap_album.append(key)
	return _finish(before)

func cargo_capacity() -> int:
	var level: int = int(state.workshop_modules.get("cargo_rack",0))
	return int(state.module_defs.cargo_rack.levels[level-1].effect) if level > 0 else int(state.logistics_def.cargo_capacity_kg)

func cargo_mass() -> float:
	var mass: float = state.specifics.mass("cargo")
	for material in state.operations.cargo:
		mass += int(state.operations.cargo[material])*float(state.material_defs[material].mass_kg)
	for item in state.operations.cargo_parts:
		mass += float(state.part_defs[item.kind].mass_kg)
	return mass

func transfer_bag_to_cargo(peer: int) -> bool:
	if state.vehicle_level < 2 or not state.player_inventories.has(peer) or state.get_inventory_mass(peer) <= 0:
		return false
	if cargo_mass()+state.get_inventory_mass(peer) > cargo_capacity():
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var bags: Dictionary = state.player_inventories.duplicate(true)
	for id in state.player_inventories[peer]:
		state.operations.cargo[id] = int(state.operations.cargo.get(id,0))+int(state.player_inventories[peer][id])
		state.player_inventories[peer][id] = 0
	state.specifics.transfer("bag","cargo")
	return _finish(before,bags)

func unload_cargo() -> bool:
	if cargo_mass() <= 0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	for id in state.operations.cargo:
		state.team_deposit_counts[id] += int(state.operations.cargo[id])
	state.operations.cargo.clear()
	for item in state.operations.cargo_parts:
		var stored: Dictionary = item.duplicate(true)
		stored.erase("position")
		stored.erase("dropped")
		state.operations.stored_parts.append(stored)
	state.operations.cargo_parts.clear()
	state.specifics.transfer("cargo","stock")
	return _finish(before)

func store_bag(peer: int) -> bool:
	if not state.player_inventories.has(peer) or state.get_inventory_mass(peer) <= 0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var bags: Dictionary = state.player_inventories.duplicate(true)
	for material in state.player_inventories[peer]:
		state.team_deposit_counts[material] += int(state.player_inventories[peer][material])
		state.player_inventories[peer][material] = 0
	state.specifics.transfer("bag","stock")
	return _finish(before,bags)

func pickup_part(id: String) -> bool:
	if not state.operations.held.is_empty() or not state.operations.field.has(id):
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.held = state.operations.field[id].duplicate(true)
	state.operations.field.erase(id)
	return _finish(before)

func drop_part(location: Vector3) -> bool:
	if state.operations.held.is_empty() or not location.is_finite():
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var item: Dictionary = state.operations.held.duplicate(true)
	item.position = [location.x,location.y,location.z]
	item.dropped = true
	state.operations.field[item.id] = item
	state.operations.held.clear()
	return _finish(before)

func load_held() -> bool:
	if state.vehicle_level < 2 or state.operations.held.is_empty():
		return false
	if cargo_mass()+float(state.part_defs[state.operations.held.kind].mass_kg) > cargo_capacity():
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.cargo_parts.append(state.operations.held.duplicate(true))
	state.operations.held.clear()
	return _finish(before)

func store_held() -> bool:
	if state.operations.held.is_empty():
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var item: Dictionary = state.operations.held.duplicate(true)
	item.erase("position")
	item.erase("dropped")
	state.operations.stored_parts.append(item)
	state.operations.held.clear()
	return _finish(before)

func take_stored(id: String) -> bool:
	if not state.operations.held.is_empty():
		return false
	var index: int = _part_index(id)
	if index < 0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.held = state.operations.stored_parts.pop_at(index)
	return _finish(before)

func _part_index(id: String) -> int:
	for index in state.operations.stored_parts.size():
		if state.operations.stored_parts[index].id == id:
			return index
	return -1

func part_value(item: Dictionary) -> int:
	return roundi(float(state.part_defs[item.kind].value)*(1.0 if int(item.quality) == 1 else float(state.logistics_def.damaged_value_multiplier)))

func sell_part(id: String) -> bool:
	var index: int = _part_index(id)
	if index < 0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var item: Dictionary = state.operations.stored_parts.pop_at(index)
	state.team_credits += part_value(item)
	return _finish(before)

func repair_part(id: String) -> bool:
	var index: int = _part_index(id)
	if index < 0 or state.yard_level < 1 or int(state.workshop_modules.get("workbench",0)) < 1 or int(state.operations.stored_parts[index].quality) == 1:
		return false
	for material in state.logistics_def.repair_materials:
		if int(state.team_deposit_counts[material]) < int(state.logistics_def.repair_materials[material]):
			return false
	var before: Dictionary = state.serialize().duplicate(true)
	for material in state.logistics_def.repair_materials:
		state.team_deposit_counts[material] -= int(state.logistics_def.repair_materials[material])
	state.operations.stored_parts[index].quality = 1
	return _finish(before)

func recycle_part(id: String) -> bool:
	var index: int = _part_index(id)
	if index < 0 or state.yard_level < 1 or int(state.workshop_modules.get("workbench",0)) < 1:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var item: Dictionary = state.operations.stored_parts.pop_at(index)
	for material in state.part_defs[item.kind].recycle:
		state.team_deposit_counts[material] += int(state.part_defs[item.kind].recycle[material])
	return _finish(before)

func completed_components(entity: String) -> Array:
	if state.operations.claims.has(entity):
		return state.operations.claims[entity].map(func(value): return int(value))
	var completed: Array = []
	for index in int(state.salvage_steps.get(entity,0)):
		completed.append(index)
	return completed

func component_requirement(entity: String, definition: String, index: int, tool: int, intact: bool, peer: int) -> String:
	if not state.salvage_defs.has(definition) or index < 0 or index >= state.salvage_defs[definition].steps.size():
		return "Componente non disponibile."
	var completed: Array = completed_components(entity)
	if index in completed:
		return "Componente già recuperato."
	var step: Dictionary = state.salvage_defs[definition].steps[index]
	for dependency in step.get("requires",[]):
		if int(dependency) not in completed:
			return "Prima: " + str(state.salvage_defs[definition].steps[int(dependency)].get("component_name","apri il rivestimento"))
	if state.yard_level < int(step.land):
		return "PROGETTO NECESSARIO\nApri il Lotto Est."
	if not state.owns_tool(tool) or tool != int(step.tool):
		return Localization.format_text("Serve %s [%d].", [state.tool_defs[int(step.tool)].name,int(state.tool_defs[int(step.tool)].key)])
	if intact:
		if not state.operations.held.is_empty():
			return "Carica o deposita il componente che stai trasportando."
	else:
		var mass: float = 0
		for material in step["yield"]:
			mass += int(step["yield"][material])*float(state.material_defs[material].mass_kg)
		if state.get_inventory_mass(peer)+mass > state.get_inventory_capacity(peer):
			return "SACCA PIENA\nServe spazio per l’intero recupero."
	return ""

func claim_component(entity: String, definition: String, index: int, peer: int, tool: int, intact: bool) -> Dictionary:
	var requirement: String = component_requirement(entity,definition,index,tool,intact,peer)
	if not requirement.is_empty():
		return {"success":false,"message":requirement}
	var before: Dictionary = state.serialize().duplicate(true)
	var bags: Dictionary = state.player_inventories.duplicate(true)
	var old_steps: Dictionary = state.salvage_steps.duplicate()
	var step: Dictionary = state.salvage_defs[definition].steps[index]
	if intact:
		state.operations.serial += 1
		state.operations.held = {"id":"part_%d" % state.operations.serial,"kind":step.part,"quality":1}
	else:
		for material in step["yield"]:
			state.player_inventories[peer][material] += int(step["yield"][material])
	var completed: Array = completed_components(entity).duplicate()
	completed.append(index)
	state.operations.claims[entity] = completed
	var prefix: int = 0
	while prefix in completed:
		prefix += 1
	state.salvage_steps[entity] = prefix
	if not _finish(before,bags):
		state.salvage_steps = old_steps
		return {"success":false,"message":"Recupero annullato: errore salvataggio."}
	return {"success":true,"message":"Componente intero recuperato: caricalo o depositalo." if intact else "Materiali separati nella sacca."}

func enqueue_press(count: int) -> bool:
	var waiting: int = int(state.operations.press_queue)
	var units: int = int(state.press_def.input_units)
	if not state.press_owned or count <= 0 or count+waiting+(1 if state.press_remaining > 0 else 0) > int(state.logistics_def.max_press_queue) or state.team_deposit_counts.metal < units*count:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.team_deposit_counts.metal -= units*count
	state.operations.press_queue += count
	if state.press_remaining <= 0:
		state.operations.press_queue -= 1
		state.press_remaining = state.press_cycle_seconds()
		state._press_tick = 0.0
	return _finish(before)

func cancel_press_queue() -> bool:
	if int(state.operations.press_queue) <= 0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.team_deposit_counts.metal += int(state.operations.press_queue)*int(state.press_def.input_units)
	state.operations.press_queue = 0
	return _finish(before)

func set_autofeed(enabled: bool) -> bool:
	if enabled and (not state.press_owned or state.yard_level < 2 or int(state.workshop_modules.get("press_drive",0)) < 2):
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.autofeed = enabled
	return _finish(before)

func delivery_definition() -> Dictionary:
	if state.operations.active_delivery.is_empty():
		return {}
	for definition in state.delivery_defs:
		if definition.id == state.operations.active_delivery.id:
			return definition
	return {}

func accept_delivery(id: String) -> bool:
	if state.completed_orders.size() < state.order_defs.size() or not state.operations.active_delivery.is_empty():
		return false
	for definition in state.delivery_defs:
		if definition.id == id:
			var before: Dictionary = state.serialize().duplicate(true)
			state.operations.serial += 1
			state.operations.active_delivery = {"id":id,"ticket":state.operations.serial}
			return _finish(before)
	return false

func cancel_delivery() -> bool:
	if state.operations.active_delivery.is_empty():
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.active_delivery.clear()
	return _finish(before)

func delivery_ready() -> bool:
	var definition: Dictionary = delivery_definition()
	if definition.is_empty() or state.press_bales < int(definition.bales):
		return false
	for material in definition.materials:
		if state.team_deposit_counts[material] < int(definition.materials[material]):
			return false
	for kind in definition.parts:
		if usable_parts(kind) < int(definition.parts[kind]):
			return false
	for product in definition.get("products",{}):
		if int(state.crafting.data().stock.get(product,0))<int(definition.products[product]):
			return false
	return true

func usable_parts(kind: String) -> int:
	var count: int = 0
	for item in state.operations.stored_parts:
		if item.kind == kind and int(item.quality) == 1:
			count += 1
	return count

func recover_buggy(vehicle: Node3D) -> bool:
	var cost: int = int(state.logistics_def.buggy_recovery_cost)
	if NetworkGateway.is_network_connected() or state.vehicle_level<2 or not is_instance_valid(vehicle) or not vehicle.is_in_group("yard_vehicles") or vehicle.level!=2 or not vehicle.parked or state.team_credits<cost:
		return false
	var coordinates: Array = state.logistics_def.buggy_parking
	var target = Vector3(coordinates[0],coordinates[1],coordinates[2])
	if vehicle.global_position.distance_to(target)<1:
		return false
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape=BoxShape3D.new()
	query.shape.size=Vector3(2.5,2.4,4.2)
	query.transform=Transform3D(Basis.IDENTITY,target+Vector3.UP*1.3)
	query.collision_mask=1
	query.exclude=[vehicle.body.get_rid()]
	if not vehicle.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var old_transform: Transform3D = vehicle.global_transform
	var old_visual: Transform3D = vehicle.visual.transform
	state.team_credits-=cost
	state.operations.serial+=1
	vehicle.global_transform=Transform3D(Basis.IDENTITY,target)
	vehicle.visual.position=Vector3.ZERO
	vehicle.visual.rotation=Vector3.ZERO
	if not _finish(before):
		vehicle.global_transform=old_transform
		vehicle.visual.transform=old_visual
		return false
	for wheel in vehicle.wheels:
		wheel.position=wheel.get_meta("rest_position")
		wheel.rotation.y=0.0
	return true

func complete_delivery(ticket: int) -> bool:
	if not delivery_ready() or int(state.operations.active_delivery.ticket) != ticket:
		return false
	var definition: Dictionary = delivery_definition()
	var before: Dictionary = state.serialize().duplicate(true)
	for product in definition.get("products",{}):
		state.crafting.data().stock[product]-=int(definition.products[product])
	for material in definition.materials:
		state.team_deposit_counts[material] -= int(definition.materials[material])
	for kind in definition.parts:
		var remaining: int = int(definition.parts[kind])
		for index in range(state.operations.stored_parts.size()-1,-1,-1):
			var item: Dictionary = state.operations.stored_parts[index]
			if remaining > 0 and item.kind == kind and int(item.quality) == 1:
				state.operations.stored_parts.remove_at(index)
				remaining -= 1
	state.press_bales -= int(definition.bales)
	state.team_credits += int(definition.reward)
	state.operations.deliveries += 1
	if not state.operations.has("delivery_history"):
		state.operations.delivery_history={}
	state.operations.delivery_history[definition.id]=int(state.operations.delivery_history.get(definition.id,0))+1
	state.operations.active_delivery.clear()
	return _finish(before)

static func validate(data: Variant, game, save: Dictionary) -> bool:
	if data is Dictionary and data.has("mobility") and not preload("res://scripts/economy/extra_mobility.gd").validate(data.mobility): return false
	if data is Dictionary:
		var records: Variant=data.get("park_records",{})
		if not records is Dictionary or records.size()>4: return false
		for vehicle in records:
			if vehicle not in ["1","2","3","4"] or not (records[vehicle] is float or records[vehicle] is int): return false
			if not is_finite(float(records[vehicle])) or records[vehicle]<1 or records[vehicle]>3600: return false
		var visits: Variant=data.get("visited_sites",[])
		if not visits is Array or visits.size()>3: return false
		for id in visits:
			if id not in ["crash","cave","anomaly"] or visits.count(id)!=1: return false
	if not data is Dictionary:
		return false
	if data.has("identity") and not preload("res://scripts/economy/yard_identity.gd").validate(data.identity):
		return false
	var history = data.get("delivery_history",{})
	if not history is Dictionary:
		return false
	var proven: int = 0
	for id in history:
		if not id is String or not game.delivery_defs.any(func(job):return job.id==id) or not SaveService._valid_count(history[id]):
			return false
		proven+=int(history[id])
	if not SaveService._valid_count(data.get("deliveries")) or proven>int(data.deliveries):
		return false
	if data.has("career") and not preload("res://scripts/economy/career.gd").validate(data.career,game,save):
		return false
	if data.has("industrial_jobs") and not preload("res://scripts/economy/industrial_jobs.gd").validate(data.industrial_jobs,save): return false
	if data.has("crafting") and not preload("res://scripts/economy/crafting.gd").validate(data.crafting,game,float(data.get("world_seconds",0)), "community" in data.get("career",{}).get("claimed",[]),int(save.get("workshop_modules",{}).get("assembly",0)),save):
		return false
	for job in data.get("crafting",{}).get("queue",[]):
		if not SaveService._valid_count(data.get("serial")) or job.id.get_slice("_",1).to_int()>int(data.serial):
			return false
	var album = data.get("scrap_album",[])
	if not album is Array or album.size()>35:
		return false
	for key in album:
		if not key is String or album.count(key)!=1 or key.get_slice("_",0).to_int() not in range(7) or key.get_slice("_",1).to_int() not in range(5) or key!="%d_%d" % [key.get_slice("_",0).to_int(),key.get_slice("_",1).to_int()]:
			return false
	var layers = data.get("pile_layers",{})
	if not layers is Dictionary or layers.size()>1000:
		return false
	for key in layers:
		if not key is String or key.length()>100 or not SaveService._valid_count(layers[key]) or layers[key]>3:
			return false
	var rotations = data.get("loose_rotations",{})
	if not rotations is Dictionary or rotations.size()>50000:
		return false
	for key in rotations:
		if not key is String or not (rotations[key] is int or rotations[key] is float) or not is_finite(float(rotations[key])) or absf(float(rotations[key]))>TAU:
			return false
	var positions = data.get("loose_positions",{})
	if not positions is Dictionary or positions.size()>50000:
		return false
	for id in positions:
		if not id is String or not positions[id] is Array or positions[id].size()!=3:
			return false
		for coordinate in positions[id]:
			if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(coordinate)>650:
				return false
	var seconds = data.get("world_seconds",0.0)
	if not (seconds is float or seconds is int) or not is_finite(float(seconds)) or seconds < 0 or seconds > 1000000000:
		return false
	var defaults: Dictionary = empty_state()
	for key in defaults:
		if not data.has(key):
			return false
	for key in ["epoch","serial","press_queue","deliveries"]:
		if not SaveService._valid_count(data[key]):
			return false
	if data.press_queue > int(game.logistics_def.max_press_queue) or not data.autofeed is bool:
		return false
	if not data.cargo is Dictionary or not data.field is Dictionary or not data.claims is Dictionary or not data.held is Dictionary or not data.active_delivery is Dictionary:
		return false
	if not data.cargo_parts is Array or not data.stored_parts is Array or data.field.size() > 1000 or data.stored_parts.size() > 1000 or data.cargo_parts.size() > 100 or data.claims.size() > 5000:
		return false
	var requests = preload("res://scripts/economy/specific_orders.gd")
	if not requests.validate(data,game,save):
		return false
	var mass: float = requests.saved_mass(data,"cargo",game)
	for material in data.cargo:
		if not game.material_defs.has(material) or not SaveService._valid_count(data.cargo[material]):
			return false
		mass += float(game.material_defs[material].mass_kg)*int(data.cargo[material])
	var identities: Dictionary = {}
	var all_parts: Array = data.cargo_parts.duplicate()
	all_parts.append_array(data.stored_parts)
	all_parts.append_array(data.field.values())
	for job in data.get("crafting",{}).get("queue",[]):
		all_parts.append_array(job.parts)
	if not data.held.is_empty():
		all_parts.append(data.held)
	for item in all_parts:
		if not item is Dictionary or not item.get("id") is String or item.id.is_empty() or item.id.length() > 100 or identities.has(item.id):
			return false
		if not item.get("kind") is String or not game.part_defs.has(item.kind) or not SaveService._valid_count(item.get("quality")) or item.quality > 1:
			return false
		identities[item.id] = true
	for item in data.cargo_parts:
		mass += float(game.part_defs[item.kind].mass_kg)
	for id in data.field:
		var item: Dictionary = data.field[id]
		if item.id != id or not item.get("position") is Array or item.position.size() != 3 or not item.get("dropped") is bool:
			return false
		for coordinate in item.position:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(float(coordinate)) > 650:
				return false
	for entity in data.claims:
		if not entity is String or entity.length() > 150:
			return false
		var value = data.claims[entity]
		if entity.begins_with("issued_"):
			if not value is bool or not value:
				return false
		elif value is Array:
			if value.size() > 8:
				return false
			for index in value:
				if not SaveService._valid_count(index) or index > 7 or value.count(index) != 1:
					return false
		else:
			return false
	var modules: Dictionary = save.get("workshop_modules",{})
	var cargo_level: int = int(modules.get("cargo_rack",0))
	var capacity: float = float(game.logistics_def.cargo_capacity_kg)
	if cargo_level > 0:
		if cargo_level > game.module_defs.cargo_rack.levels.size():
			return false
		capacity = float(game.module_defs.cargo_rack.levels[cargo_level-1].effect)
	if mass > capacity or (mass > 0 and int(save.get("vehicle_level",0)) < 2):
		return false
	var press: Dictionary = save.get("press",{})
	if data.press_queue > 0 and (not press.get("owned",false) or float(press.get("remaining_seconds",0)) <= 0):
		return false
	if data.autofeed and (not press.get("owned",false) or int(save.get("yard_level",0)) < 2 or int(modules.get("press_drive",0)) < 2):
		return false
	if not data.active_delivery.is_empty():
		if not data.active_delivery.get("id") is String or not SaveService._valid_count(data.active_delivery.get("ticket")) or data.active_delivery.ticket > data.serial:
			return false
		var found: bool = false
		for definition in game.delivery_defs:
			found = found or definition.id == data.active_delivery.id
		if not found or save.get("completed_orders",[]).size() < game.order_defs.size():
			return false
	return true

func claim_pile(entity: String, definition: String, expected: int, peer: int, tool: int, point: Vector3) -> Dictionary:
	var completed: int = int(state.operations.get("pile_layers",{}).get(entity,0))
	if completed!=expected or not definition.begins_with("pile") or not state.salvage_defs.has(definition) or completed>=state.salvage_defs[definition].steps.size():
		return {"success":false,"message":"Strato già recuperato."}
	if not point.is_finite() or maxf(absf(point.x),maxf(absf(point.y),absf(point.z)))>340:
		return {"success":false,"message":"Posizione di recupero non valida."}
	var before: Dictionary = state.serialize().duplicate(true)
	var bags: Dictionary = state.player_inventories.duplicate(true)
	var previous_steps: Dictionary = state.salvage_steps.duplicate(true)
	state.salvage_steps[entity] = completed
	var result: Dictionary = state.claim_salvage(entity,definition,completed,peer,tool)
	if not result.success:
		state.salvage_steps = previous_steps
		return result
	if not state.operations.has("pile_layers"):
		state.operations.pile_layers = {}
	state.operations.pile_layers[entity] = completed+1
	var reveals: Array = state.logistics_def.pile_reveals_by_definition.get(definition,state.logistics_def.pile_reveals)
	var reveal: Dictionary = reveals[completed]
	var id: String = "e%d_%s_layer%d" % [state.operations.epoch,entity,completed]
	state.operations.field[id] = {"id":id,"kind":reveal.kind,"quality":int(reveal.quality),"position":[point.x,point.y+0.15,point.z],"dropped":false}
	if not _finish(before,bags):
		state.salvage_steps = previous_steps
		return {"success":false,"message":"Recupero annullato: errore salvataggio."}
	result.message = "Strato %d/%d recuperato · emerso %s." % [completed+1,state.salvage_defs[definition].steps.size(),state.part_defs[reveal.kind].name]
	return result

