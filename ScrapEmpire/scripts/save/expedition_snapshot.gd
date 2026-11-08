extends RefCounted
## Local bag and consumed raw identities are one checkpoint.
## Legacy saves without this optional block begin with an empty bag/renewed loose scrap.
static func capture(game) -> Dictionary:
	var bag: Dictionary = {}
	for material in game.material_defs:
		bag[material] = int(game.player_inventories.get(1,{}).get(material,0))
	return {"bag":bag,"consumed":game.sector_consumed_ids.duplicate(),"revision":game.sector_revision,"travel":preload("res://scripts/save/travel_snapshot.gd").capture(game)}

static func apply(game, value: Dictionary) -> void:
	var bag: Dictionary = {}
	for material in game.material_defs:
		bag[material] = int(value.get("bag",{}).get(material,0))
	game.player_inventories[1] = bag
	game.sector_consumed_ids.assign(value.get("consumed",[]))
	game.sector_revision = int(value.get("revision",0))
	game.local_travel = value.get("travel",{}).duplicate(true)

static func validate(value: Variant, game, save: Dictionary) -> bool:
	if not value is Dictionary or not value.get("bag") is Dictionary or not value.get("consumed") is Array or not SaveService._valid_count(value.get("revision")):
		return false
	if not preload("res://scripts/save/travel_snapshot.gd").validate(value.get("travel",{}),save):
		return false
	var counts: Dictionary = game.base_sector_counts.duplicate()
	for land in game.land_defs:
		if int(land.level)<=int(save.get("yard_level",0)):
			counts.merge(land.materials,true)
	var total: int = 0
	for amount in counts.values():
		total += int(amount)
	if value.consumed.size()>total or int(value.revision)<value.consumed.size():
		return false
	var identities: Dictionary = {}
	for id in value.consumed:
		if not id is String:
			return false
		var material: String = id.get_slice("_",0)
		var unit: int = id.get_slice("_",1).to_int()
		if not counts.has(material) or unit<0 or unit>=int(counts[material]) or id!="%s_%03d" % [material,unit] or identities.has(id):
			return false
		identities[id] = true
	var mass: float = 0
	for material in value.bag:
		if not game.material_defs.has(material) or not SaveService._valid_count(value.bag[material]):
			return false
		mass += int(value.bag[material])*float(game.material_defs[material].mass_kg)
	var capacity: float = float(game.player_capacity_kg)
	var level: int = int(save.team_upgrade_levels.get("bag",0))
	if level>0:
		capacity = float(game._find_upgrade(game._get_upgrade_defs("bag"),level).capacity_kg)
	var operations: Dictionary = save.get("operations",{})
	mass += preload("res://scripts/economy/specific_orders.gd").saved_mass(operations,"bag",game)
	return mass<=capacity
