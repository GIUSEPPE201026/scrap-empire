extends RefCounted
const IDS=["skateboard","dirtbike"]
static func owned(id: String) -> bool:
	return id in GameState.operations.get("mobility",{}).get("owned",[])

static func purchase(id: String) -> bool:
	if id not in IDS or owned(id): return false
	var spec: Dictionary=GameState.logistics_def.mobility[id]
	if GameState.yard_level<int(spec.requires_land) or GameState.team_credits<int(spec.cost): return false
	var before: Dictionary=GameState.serialize().duplicate(true)
	if not GameState.operations.has("mobility"): GameState.operations.mobility={"owned":[],"portable":"scooter"}
	GameState.operations.mobility.owned.append(id)
	GameState.team_credits-=int(spec.cost)
	if id=="skateboard": GameState.operations.mobility.portable=id
	return GameState.ops._finish(before)

static func select_portable(id: String) -> bool:
	if id not in ["scooter","skateboard"] or (id=="skateboard" and not owned(id)) or (id=="scooter" and GameState.vehicle_level<1): return false
	var before: Dictionary=GameState.serialize().duplicate(true)
	if not GameState.operations.has("mobility"): GameState.operations.mobility={"owned":[],"portable":"scooter"}
	GameState.operations.mobility.portable=id
	return GameState.ops._finish(before)

static func validate(value: Variant) -> bool:
	if not value is Dictionary or not value.get("owned") is Array or value.owned.size()>2: return false
	for id in value.owned:
		if id not in IDS or value.owned.count(id)!=1: return false
	return value.get("portable","scooter") in ["scooter","skateboard"] and (value.get("portable")!="skateboard" or "skateboard" in value.owned)
