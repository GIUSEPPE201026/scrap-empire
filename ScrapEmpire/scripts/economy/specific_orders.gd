extends RefCounted
var state
const MATERIALS = ["metal","plastic","electronics","copper","aluminum","glass","rubber"]

func _init(game_state) -> void:
	state = game_state

func definition(id: String = "") -> Dictionary:
	if id.is_empty():
		id = str(state.operations.get("specific_request",{}).get("id",""))
	for job in state.logistics_def.specific_orders:
		if job.id==id:
			return job
	return {}

func payload() -> Dictionary:
	return state.operations.get("specific_request",{})

func mass(location: String) -> float:
	var result: float = 0
	for key in payload().get(location,{}):
		result += int(payload()[location][key])*float(state.material_defs[MATERIALS[key.get_slice("_",0).to_int()]].mass_kg)
	return result

func total(key: String) -> int:
	var result: int = 0
	for place in ["bag","cargo","stock"]:
		result += int(payload().get(place,{}).get(key,0))
	return result

func needs(key: String) -> bool:
	var job: Dictionary = definition()
	return not job.is_empty() and int(job.items.get(key,0))>total(key)

func accept(id: String) -> bool:
	var job: Dictionary = definition(id)
	if job.is_empty() or not payload().is_empty() or id in state.operations.get("specific_completed",[]) or state.completed_orders.size()<int(job.orders) or state.yard_level<int(job.land):
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.serial += 1
	state.operations.specific_request = {"id":id,"ticket":state.operations.serial,"bag":{},"cargo":{},"stock":{}}
	return state.ops._finish(before)

func capture(key: String, entity: String) -> bool:
	var material: String = entity.get_slice("_",0)
	var family: int = MATERIALS.find(material)
	var unit: int = entity.get_slice("_",1).to_int()
	if family<0 or unit<0 or unit>=int(state.sector_initial_counts.get(material,0)) or entity!="%s_%03d" % [material,unit] or key!="%d_%d" % [family,preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(entity)]:
		return false
	if not state.can_add_to_inventory(1,material) or not needs(key) or entity in state.sector_consumed_ids:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var consumed: Array = state.sector_consumed_ids.duplicate()
	var revision: int = state.sector_revision
	payload().bag[key] = int(payload().bag.get(key,0))+1
	state.mark_scrap_consumed(entity)
	if not state.ops._finish(before):
		state.sector_consumed_ids = consumed
		state.sector_revision = revision
		return false
	return true

func transfer(source: String, destination: String) -> void:
	if payload().is_empty():
		return
	for key in payload()[source]:
		payload()[destination][key] = int(payload()[destination].get(key,0))+int(payload()[source][key])
	payload()[source].clear()

func ready() -> bool:
	var job: Dictionary = definition()
	if job.is_empty():
		return false
	for key in job.items:
		if int(payload().stock.get(key,0))<int(job.items[key]):
			return false
	return true

func deliver(ticket: int) -> bool:
	if not ready() or int(payload().ticket)!=ticket:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var job: Dictionary = definition()
	state.team_credits += int(job.reward)
	if not state.operations.has("specific_completed"):
		state.operations.specific_completed = []
	state.operations.specific_completed.append(job.id)
	state.operations.specific_request = {}
	return state.ops._finish(before)

func cancel() -> bool:
	if payload().is_empty() or not state.player_inventories.has(1):
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var bags: Dictionary = state.player_inventories.duplicate(true)
	for place in ["bag","cargo","stock"]:
		var target: Dictionary = state.player_inventories[1] if place=="bag" else (state.operations.cargo if place=="cargo" else state.team_deposit_counts)
		for key in payload()[place]:
			var material: String = MATERIALS[key.get_slice("_",0).to_int()]
			target[material] = int(target.get(material,0))+int(payload()[place][key])
	state.operations.specific_request = {}
	return state.ops._finish(before,bags)

static func validate(data: Dictionary, game, save: Dictionary) -> bool:
	var completed = data.get("specific_completed",[])
	if not completed is Array:
		return false
	var jobs: Dictionary = {}
	for job in game.logistics_def.specific_orders:
		jobs[job.id] = job
	for id in completed:
		if not id is String or not jobs.has(id) or completed.count(id)!=1:
			return false
	var request = data.get("specific_request",{})
	if not request is Dictionary:
		return false
	if request.is_empty():
		return true
	if not request.get("id") is String or not jobs.has(request.id) or request.id in completed or not SaveService._valid_count(request.get("ticket")) or request.ticket>data.serial:
		return false
	var job: Dictionary = jobs[request.id]
	if save.get("completed_orders",[]).size()<int(job.orders) or int(save.get("yard_level",0))<int(job.land):
		return false
	var totals: Dictionary = {}
	for place in ["bag","cargo","stock"]:
		if not request.get(place) is Dictionary:
			return false
		for key in request[place]:
			if not job.items.has(key) or not SaveService._valid_count(request[place][key]):
				return false
			totals[key] = int(totals.get(key,0))+int(request[place][key])
	for key in totals:
		if totals[key]>int(job.items[key]):
			return false
	return true

static func saved_mass(data: Dictionary, location: String, game) -> float:
	var result: float = 0
	for key in data.get("specific_request",{}).get(location,{}):
		result += int(data.specific_request[location][key])*float(game.material_defs[MATERIALS[key.get_slice("_",0).to_int()]].mass_kg)
	return result

func units(place: String) -> int:
	var result: int = 0
	for count in payload().get(place,{}).values():
		result += int(count)
	return result

