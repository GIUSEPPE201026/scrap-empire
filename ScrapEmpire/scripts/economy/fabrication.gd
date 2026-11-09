extends RefCounted
## Complex products reserve exact components. Completion and cancellation checkpoint atomically.
var state
var _tick: float = 0.0
var _retry: float = 0.0

func _init(game) -> void:
	state=game

func jobs() -> Array:
	return state.crafting.data().get("queue",[])

func capacity() -> int:
	return 6 if int(state.workshop_modules.get("assembly",0))>=2 else 3

func duration(kind: String) -> float:
	return float(state.crafting.definitions()[kind].get("seconds",0))*state.module_effect("assembly")

func count(kind: String) -> int:
	return jobs().filter(func(job):return job.kind==kind).size()

func enqueue(kind: String, ticket: int) -> bool:
	if ticket!=int(state.operations.serial) or jobs().size()>=capacity() or not state.crafting.can_craft(kind) or duration(kind)<=0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var recipe: Dictionary = state.crafting.definitions()[kind]
	var reserved: Array = []
	for material in recipe.materials:
		state.team_deposit_counts[material]-=int(recipe.materials[material])
	for part in recipe.parts:
		var amount: int = int(recipe.parts[part])
		for index in range(state.operations.stored_parts.size()-1,-1,-1):
			var item: Dictionary = state.operations.stored_parts[index]
			if amount>0 and item.kind==part and int(item.quality)==1:
				reserved.append(state.operations.stored_parts.pop_at(index))
				amount-=1
	state.operations.serial+=1
	if not state.crafting.data().has("queue"):
		state.crafting.data().queue=[]
	state.crafting.data().queue.append({"id":"build_%d" % state.operations.serial,"kind":kind,"duration":duration(kind),"remaining":duration(kind),"materials":recipe.materials.duplicate(),"parts":reserved})
	return state.ops._finish(before)

func cancel(id: String) -> bool:
	for index in jobs().size():
		var job: Dictionary = jobs()[index]
		if job.id!=id:
			continue
		if state.operations.stored_parts.size()+job.parts.size()>1000:
			return false
		var before: Dictionary = state.serialize().duplicate(true)
		for material in job.materials:
			state.team_deposit_counts[material]+=int(job.materials[material])
		state.operations.stored_parts.append_array(job.parts.duplicate(true))
		state.crafting.data().queue.remove_at(index)
		state.operations.serial+=1
		return state.ops._finish(before)
	return false

func tick(delta: float) -> void:
	if jobs().is_empty() or delta<=0:
		return
	_retry=maxf(0,_retry-delta)
	if _retry>0:
		return
	_tick+=delta
	if _tick<0.2:
		return
	var elapsed: float = _tick
	_tick=0
	var before: Dictionary = state.serialize().duplicate(true)
	var finished: PackedStringArray = []
	while not jobs().is_empty() and elapsed>=float(jobs()[0].remaining):
		var job: Dictionary = state.crafting.data().queue.pop_front()
		elapsed-=float(job.remaining)
		state.crafting.data().stock[job.kind]=int(state.crafting.data().stock.get(job.kind,0))+1
		state.operations.serial+=1
		finished.append(state.crafting.definitions()[job.kind].name)
	if not jobs().is_empty():
		jobs()[0].remaining=maxf(0.001,float(jobs()[0].remaining)-elapsed)
	if not finished.is_empty():
		if not state.ops._finish(before):
			_retry=3.0
			return
		state.machine_message.emit(Localization.text("PRONTO IN GARAGE · ")+", ".join(finished))

static func validate(value: Variant, game, crafting: Dictionary, assembly_level: int = 0) -> bool:
	if assembly_level<0 or assembly_level>game.module_defs.assembly.levels.size():
		return false
	if not value is Array or value.size()>(6 if assembly_level>=2 else 3):
		return false
	var ids: Dictionary = {}
	var queued: Dictionary = {}
	for job in value:
		if not job is Dictionary or not job.get("id") is String or not job.id.begins_with("build_") or job.id.get_slice("_",1).to_int()<=0 or job.id!="build_%d" % job.id.get_slice("_",1).to_int() or ids.has(job.id) or not game.logistics_def.crafting.has(job.get("kind","")):
			return false
		ids[job.id]=true
		var recipe: Dictionary = game.logistics_def.crafting[job.kind]
		var speed: float = float(game.module_defs.assembly.levels[assembly_level-1].effect) if assembly_level>0 else 1.0
		if float(recipe.get("seconds",0))<=0 or not (job.get("duration") is float or job.get("duration") is int) or not is_finite(float(job.duration)) or job.duration<=0 or job.duration>float(recipe.seconds) or job.duration<float(recipe.seconds)*0.5:
			return false
		if float(job.duration)+0.0001<float(recipe.seconds)*speed:
			return false
		if not (job.get("remaining") is float or job.get("remaining") is int) or not is_finite(float(job.remaining)) or job.remaining<=0 or job.remaining>job.duration or not job.get("materials") is Dictionary or job.materials.size()!=recipe.materials.size() or not job.get("parts") is Array:
			return false
		for material in recipe.materials:
			if not SaveService._valid_count(job.materials.get(material)) or int(job.materials[material])!=int(recipe.materials[material]):
				return false
		var parts: Dictionary = {}
		for item in job.parts:
			if not item is Dictionary or not item.get("kind") is String or int(item.get("quality",0))!=1:
				return false
			parts[item.kind]=int(parts.get(item.kind,0))+1
		if parts.size()!=recipe.parts.size():
			return false
		for kind in recipe.parts:
			if int(parts.get(kind,0))!=int(recipe.parts[kind]):
				return false
		queued[job.kind]=int(queued.get(job.kind,0))+1
	for kind in queued:
		if int(queued[kind])+int(crafting.stock.get(kind,0))>int(game.logistics_def.crafting[kind].limit):
			return false
	return true
