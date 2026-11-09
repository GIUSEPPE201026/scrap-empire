extends RefCounted
## Counters advance inside the cargo transaction; rewards are claimed separately.
const KINDS=["crane","loader","forklift"]

static func spec(kind: String) -> Dictionary:
	return GameState.logistics_def.industrial_jobs.get(kind,{})

static func progress(kind: String) -> Dictionary:
	return GameState.operations.get("industrial_jobs",{}).get(kind,{"tier":0,"units":0,"active":false})

static func tier(kind: String) -> Dictionary:
	var index: int=int(progress(kind).tier)
	return spec(kind).tiers[index] if index<spec(kind).tiers.size() else {}

static func start(kind: String, ticket: int) -> bool:
	if kind not in KINDS or ticket!=int(GameState.operations.serial) or progress(kind).active or tier(kind).is_empty() or not preload("res://scripts/economy/extra_mobility.gd").owned(kind): return false
	var before: Dictionary=GameState.serialize().duplicate(true)
	if not GameState.operations.has("industrial_jobs"): GameState.operations.industrial_jobs={}
	GameState.operations.industrial_jobs[kind]={"tier":int(progress(kind).tier),"units":0,"active":true}
	GameState.operations.serial+=1
	return GameState.ops._finish(before)

static func record(kind: String, units: int) -> void:
	if kind not in KINDS or units<=0 or not progress(kind).active or tier(kind).is_empty(): return
	GameState.operations.industrial_jobs[kind].units=mini(int(tier(kind).goal),int(progress(kind).units)+units)

static func claim(kind: String, ticket: int) -> bool:
	if kind not in KINDS or ticket!=int(GameState.operations.serial) or not progress(kind).active or tier(kind).is_empty() or int(progress(kind).units)<int(tier(kind).goal): return false
	var before: Dictionary=GameState.serialize().duplicate(true)
	GameState.team_credits+=int(tier(kind).reward)
	GameState.operations.industrial_jobs[kind]={"tier":int(progress(kind).tier)+1,"units":0,"active":false}
	GameState.operations.serial+=1
	return GameState.ops._finish(before)

static func validate(value: Variant, save: Dictionary) -> bool:
	if not value is Dictionary or value.size()>KINDS.size(): return false
	for kind in value:
		if kind not in KINDS or kind not in save.get("operations",{}).get("mobility",{}).get("owned",[]): return false
		var row=value[kind]
		if not row is Dictionary or not SaveService._valid_count(row.get("tier")) or row.tier>spec(kind).tiers.size() or not SaveService._valid_count(row.get("units")) or not row.get("active") is bool: return false
		if row.tier==spec(kind).tiers.size():
			if row.active or row.units!=0: return false
		elif row.units>int(spec(kind).tiers[int(row.tier)].goal) or (not row.active and row.units!=0): return false
	return true
