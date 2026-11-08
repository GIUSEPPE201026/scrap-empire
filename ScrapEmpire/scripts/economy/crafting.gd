extends RefCounted
## Crafting uses free warehouse materials and working recovered components only.
var state
const DEPLOYABLES=["handcart","work_lamp","field_depot","yard_wall","yard_canopy","yard_platform"]

func _init(game) -> void:
	state = game

func data() -> Dictionary:
	if not state.operations.has("crafting"):
		state.operations.crafting = {"stock":{},"objects":{}}
	return state.operations.crafting

func definitions() -> Dictionary:
	return state.logistics_def.crafting

func count(kind: String) -> int:
	var amount: int = int(data().stock.get(kind,0))+state.fabrication.count(kind)
	for item in data().objects.values():
		if item.kind==kind:
			amount += 1
	return amount

func can_craft(kind: String) -> bool:
	if not definitions().has(kind):
		return false
	var recipe: Dictionary = definitions()[kind]
	if state.yard_level<int(recipe.get("land",0)) or int(state.workshop_modules.get(str(recipe.get("module","")),0))<int(recipe.get("module_level",0)):
		return false
	if float(recipe.get("seconds",0))>0 and state.fabrication.jobs().size()>=state.fabrication.capacity():
		return false
	if state.completed_orders.size()<int(recipe.orders) or state.team_upgrade_levels.tool<int(recipe.tool) or count(kind)>=int(recipe.limit):
		return false
	for material in recipe.materials:
		if int(state.team_deposit_counts.get(material,0))<int(recipe.materials[material]):
			return false
	for part in recipe.parts:
		if state.ops.usable_parts(part)<int(recipe.parts[part]):
			return false
	return true

func next_requirement(kind: String) -> Dictionary:
	if not definitions().has(kind):
		return {}
	var recipe: Dictionary = definitions()[kind]
	if state.completed_orders.size()<int(recipe.orders):
		return state.story._step("Prima completa le commesse","Servono %d commesse per %s. Il monitor mostra quella attuale." % [recipe.orders,recipe.name],"tools")
	if int(state.team_upgrade_levels.tool)<int(recipe.tool):
		return state.story._step("Prepara l'attrezzo","Acquista %s al monitor dell'ufficio." % state.tool_defs[int(recipe.tool)].name,"tools")
	if state.yard_level<int(recipe.get("land",0)):
		return state.story._step("Apri il lotto richiesto","%s richiede il lotto %d: controlla il progetto sulla planimetria." % [recipe.name,recipe.land],"land")
	if int(state.workshop_modules.get(str(recipe.get("module","")),0))<int(recipe.get("module_level",0)):
		return state.story._step("Installa il banco","Acquista %s L%d al monitor → Officina." % [state.module_defs[recipe.module].name,recipe.module_level],"tools")
	if float(recipe.get("seconds",0))>0 and state.fabrication.jobs().size()>=state.fabrication.capacity():
		return state.story._step("Il banco è occupato","Chiudi i menu per far lavorare il banco, oppure gestisci la coda al tavolo assemblaggio.","fabrication")
	if count(kind)>=int(recipe.limit):
		return state.story._step("Limite di prodotto raggiunto","Usa o vendi i prodotti già pronti prima di costruirne altri.","craft")
	for part in recipe.parts:
		if state.ops.usable_parts(part)>=int(recipe.parts[part]):
			continue
		var pending: Array = state.operations.cargo_parts.duplicate()
		if not state.operations.held.is_empty():
			pending.append(state.operations.held)
		if pending.any(func(item):return item.kind==part):
			return state.story._step("Porta il componente al magazzino","%s è in mano o nel cassone. Il banco usa componenti depositati e funzionanti." % state.part_defs[part].name,"warehouse")
		if state.operations.stored_parts.any(func(item):return item.kind==part and int(item.quality)==0):
			if int(data().stock.get("repair_kit",0))>0:
				return state.story._step("Usa il kit pronto","Al garage scegli Kit di riparazione e ripara "+state.part_defs[part].name+" con il kit già costruito.","craft")
			if int(state.workshop_modules.get("workbench",0))>0 and int(data().stock.get("repair_kit",0))==0:
				for material in state.logistics_def.repair_materials:
					var missing: int = int(state.logistics_def.repair_materials[material])-int(state.team_deposit_counts.get(material,0))
					if missing>0:
						return _material_requirement(material,missing,"riparare "+state.part_defs[part].name)
			return state.story._step("Ripara il componente","%s è danneggiato: usa il banco recupero o un kit dal garage." % state.part_defs[part].name,"recovery" if int(state.workshop_modules.get("workbench",0))>0 else "craft")
		var step: Dictionary = state.story._step("Recupera "+state.part_defs[part].name,"Cerca il pezzo intero oppure smontalo con R in modalità recupero intero. I pezzi danneggiati vanno riparati.","salvage")
		step.part=part
		return step
	for material in recipe.materials:
		var missing: int = int(recipe.materials[material])-int(state.team_deposit_counts.get(material,0))
		if missing<=0:
			continue
		return _material_requirement(material,missing,recipe.name)
	return state.story._step("La ricetta è pronta",recipe.name+": torna al banco del garage e conferma la costruzione.","craft")

func _material_requirement(material: String, missing: int, purpose: String) -> Dictionary:
	var bag: Dictionary = state.player_inventories.get(1,{})
	if int(bag.get(material,0))>=missing or state.get_inventory_mass(1)+float(state.material_defs[material].mass_kg)>state.get_inventory_capacity(1):
		return state.story._step("Deposita i materiali","Scarica la sacca senza vendere gli ingredienti della ricetta.","depot")
	if int(state.operations.cargo.get(material,0))+int(bag.get(material,0))>=missing:
		return state.story._step("Scarica il cassone","Gli ingredienti sono nel buggy. Parcheggialo vicino al magazzino e trasferiscili nel deposito.","warehouse")
	var name: String = {"metal":"metallo","plastic":"plastica","electronics":"elettronica","copper":"rame","aluminum":"alluminio","glass":"vetro","rubber":"gomma"}.get(material,material)
	return state.story._step("Recupera materiali per "+purpose,"Nel deposito mancano %d unità di %s. Raccogli con l'attrezzo indicato e deposita." % [missing,name],"salvage",material)

func craft(kind: String, ticket: int) -> bool:
	if ticket!=int(state.operations.serial) or not can_craft(kind):
		return false
	if float(definitions()[kind].get("seconds",0))>0:
		return state.fabrication.enqueue(kind,ticket)
	var before: Dictionary = state.serialize().duplicate(true)
	var recipe: Dictionary = definitions()[kind]
	for material in recipe.materials:
		state.team_deposit_counts[material] -= int(recipe.materials[material])
	for part in recipe.parts:
		var remaining: int = int(recipe.parts[part])
		for index in range(state.operations.stored_parts.size()-1,-1,-1):
			var item: Dictionary = state.operations.stored_parts[index]
			if remaining>0 and item.kind==part and int(item.quality)==1:
				state.operations.stored_parts.remove_at(index)
				remaining -= 1
	data().stock[kind] = int(data().stock.get(kind,0))+1
	state.operations.serial += 1
	return state.ops._finish(before)

func install_requirement(kind: String) -> String:
	if not definitions().has(kind) or not definitions()[kind].has("install"):
		return "Nessuna installazione."
	var target: Dictionary=definitions()[kind].install
	if target.has("module"):
		var requirement: String=state.module_requirement(target.module,false)
		if not requirement.is_empty():
			return requirement
	else:
		var category: String=target.upgrade
		if int(state.team_upgrade_levels[category])>=state._get_upgrade_defs(category).size():
			return "Completo."
	if int(data().stock.get(kind,0))<1:
		return "Costruisci il kit."
	return ""

func install(kind: String, ticket: int) -> bool:
	if ticket!=int(state.operations.serial) or not install_requirement(kind).is_empty():
		return false
	var before: Dictionary=state.serialize().duplicate(true)
	var target: Dictionary=definitions()[kind].install
	data().stock[kind]-=1
	if target.has("module"):
		state.workshop_modules[target.module]=int(state.workshop_modules.get(target.module,0))+1
	else:
		state.team_upgrade_levels[target.upgrade]+=1
	state.operations.serial+=1
	return state.ops._finish(before)

func deploy(kind: String, point: Vector3, yaw: float, up: Vector3=Vector3.UP) -> bool:
	if not up.is_finite() or not up.is_normalized() or up.y<0.9: return false
	if kind not in DEPLOYABLES or data().objects.size()>=32 or int(data().stock.get(kind,0))<=0 or not point.is_finite() or not is_finite(yaw) or maxf(absf(point.x),absf(point.z))>650 or absf(point.y)>100:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	state.operations.serial += 1
	var id: String = "craft_%d" % state.operations.serial
	data().stock[kind] -= 1
	data().objects[id] = {"kind":kind,"position":[point.x,point.y,point.z],"yaw":wrapf(yaw,-PI,PI),"up":[up.x,up.y,up.z],"cargo":{}}
	return state.ops._finish(before)

func pack(id: String) -> bool:
	if not data().objects.has(id) or not data().objects[id].cargo.is_empty():
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var kind: String = data().objects[id].kind
	data().stock[kind] = int(data().stock.get(kind,0))+1
	data().objects.erase(id)
	return state.ops._finish(before)

func move_object(id: String, point: Vector3, yaw: float) -> bool:
	if not data().objects.has(id) or not point.is_finite() or not is_finite(yaw) or maxf(absf(point.x),absf(point.z))>650 or absf(point.y)>100:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	data().objects[id].position = [point.x,point.y,point.z]
	data().objects[id].yaw = wrapf(yaw,-PI,PI)
	data().objects[id].erase("up")
	return state.ops._finish(before)

func cart_mass(id: String) -> float:
	var result: float = 0
	for material in data().objects.get(id,{}).get("cargo",{}):
		result += int(data().objects[id].cargo[material])*float(state.material_defs[material].mass_kg)
	return result

func load_cart(id: String) -> bool:
	if not data().objects.has(id) or data().objects[id].kind!="handcart" or not state.player_inventories.has(1):
		return false
	var mass: float = 0
	for material in state.player_inventories[1]:
		mass += int(state.player_inventories[1][material])*float(state.material_defs[material].mass_kg)
	if mass<=0 or mass+cart_mass(id)>float(definitions().handcart.capacity_kg):
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var bags: Dictionary = state.player_inventories.duplicate(true)
	for material in state.player_inventories[1]:
		var quantity: int = int(state.player_inventories[1][material])
		if quantity>0:
			data().objects[id].cargo[material] = int(data().objects[id].cargo.get(material,0))+quantity
			state.player_inventories[1][material] = 0
	return state.ops._finish(before,bags)

func unload_cart(id: String) -> bool:
	if not data().objects.has(id) or data().objects[id].kind!="handcart" or cart_mass(id)<=0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	for material in data().objects[id].cargo:
		state.team_deposit_counts[material] += int(data().objects[id].cargo[material])
	data().objects[id].cargo.clear()
	return state.ops._finish(before)

func repair(id: String) -> bool:
	if int(data().stock.get("repair_kit",0))<=0:
		return false
	var index: int = state.ops._part_index(id)
	if index<0 or int(state.operations.stored_parts[index].quality)!=0:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	data().stock.repair_kit -= 1
	state.operations.stored_parts[index].quality = 1
	return state.ops._finish(before)

static func validate(value: Variant, game, elapsed: float = 0, community: bool = false, assembly_level: int = 0) -> bool:
	if not value is Dictionary or not value.get("stock") is Dictionary or not value.get("objects") is Dictionary or value.objects.size()>32:
		return false
	if not preload("res://scripts/economy/fabrication.gd").validate(value.get("queue",[]),game,value,assembly_level):
		return false
	var sales = value.get("sales",{})
	if not sales is Dictionary:
		return false
	for id in sales:
		var customer: Dictionary = {}
		for spec in game.logistics_def.customers:
			if spec.id==id:
				customer = spec
		if customer.is_empty() or not sales[id] is Dictionary or not SaveService._valid_count(sales[id].get("day")) or not SaveService._valid_count(sales[id].get("units")) or int(sales[id].units)>int(customer.daily_units)+int(community) or int(sales[id].day)>int(elapsed/float(game.logistics_def.day_seconds)):
			return false
	var totals: Dictionary = {}
	for kind in value.stock:
		if not game.logistics_def.crafting.has(kind) or not SaveService._valid_count(value.stock[kind]):
			return false
		totals[kind] = int(value.stock[kind])
	for id in value.objects:
		var item = value.objects[id]
		if item is Dictionary and item.has("up"):
			if not item.up is Array or item.up.size()!=3: return false
			for coordinate in item.up:
				if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)): return false
			var up=Vector3(item.up[0],item.up[1],item.up[2])
			if not up.is_normalized() or up.y<0.9: return false
		if not id is String or id.length()>50 or not id.begins_with("craft_") or not item is Dictionary or item.get("kind","") not in DEPLOYABLES or not item.get("cargo") is Dictionary:
			return false
		if not item.get("position") is Array or item.position.size()!=3 or not (item.get("yaw") is int or item.get("yaw") is float) or not is_finite(float(item.yaw)) or absf(item.yaw)>PI:
			return false
		for coordinate in item.position:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(coordinate)>650:
				return false
		var mass: float = 0
		for material in item.cargo:
			if not game.material_defs.has(material) or not SaveService._valid_count(item.cargo[material]):
				return false
			mass += int(item.cargo[material])*float(game.material_defs[material].mass_kg)
		if item.kind!="handcart" and not item.cargo.is_empty() or mass>float(game.logistics_def.crafting.handcart.capacity_kg):
			return false
		totals[item.kind] = int(totals.get(item.kind,0))+1
	for kind in totals:
		if totals[kind]>int(game.logistics_def.crafting[kind].limit):
			return false
	return true

func customer(id: String) -> Dictionary:
	for spec in state.logistics_def.customers:
		if spec.id==id:
			return spec
	return {}

func day() -> int:
	return int(float(state.operations.get("world_seconds",0))/float(state.logistics_def.day_seconds))

func demand(id: String) -> int:
	var spec: Dictionary = customer(id)
	if spec.is_empty() or state.completed_orders.size()<int(spec.orders):
		return 0
	var receipt: Dictionary = data().get("sales",{}).get(id,{})
	return customer_limit(id)-(int(receipt.get("units",0)) if int(receipt.get("day",-1))==day() else 0)

func sell_product(id: String, units: int, ticket: int) -> bool:
	var spec: Dictionary = customer(id)
	if spec.is_empty() or ticket!=int(state.operations.serial) or units<=0 or units>demand(id) or int(data().stock.get(spec.product,0))<units:
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	var sold: int = customer_limit(id)-demand(id)
	state.story.record(id+"_sales",units)
	if not data().has("sales"):
		data().sales = {}
	data().sales[id] = {"day":day(),"units":sold+units}
	data().stock[spec.product] -= units
	state.team_credits += units*int(spec.price)
	state.operations.serial += 1
	return state.ops._finish(before)

func customer_limit(id: String) -> int:
	var spec: Dictionary = customer(id)
	return int(spec.daily_units)+(1 if state.story.has_project("community") else 0) if not spec.is_empty() else 0


