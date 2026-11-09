extends RefCounted
var state

func _init(game) -> void:
	state = game

func definition() -> Dictionary:
	return state.logistics_def.story

func data() -> Dictionary:
	if not state.operations.has("career"):
		# Only proven sales in the existing receipt can be migrated.
		var sales: Dictionary = state.crafting.data().get("sales",{})
		state.operations.career = {"claimed":[],"stats":{"marta_sales":int(sales.get("marta",{}).get("units",0)),"enzo_sales":int(sales.get("enzo",{}).get("units",0))}}
	return state.operations.career

func record(metric: String, units: int) -> void:
	if metric in ["marta_sales","enzo_sales"] and units>0:
		data().stats[metric] = mini(1000000,int(data().stats.get(metric,0))+units)

func has_project(id: String) -> bool:
	return id in data().claimed

func metric(id: String) -> int:
	match id:
		"marta_sales","enzo_sales": return int(data().stats.get(id,0))
		"deliveries": return int(state.operations.deliveries)
		"album": return state.operations.get("scrap_album",[]).size()
		"specifics": return state.operations.get("specific_completed",[]).size()
		_: return int(state.workshop_modules.get(id,0))

func project(id: String) -> Dictionary:
	for item in definition().projects:
		if item.id==id:
			return item
	return {}

func ready(id: String) -> bool:
	var item: Dictionary = project(id)
	if item.is_empty() or has_project(id) or state.completed_orders.size()<int(item.orders):
		return false
	for rule in item.rules:
		if metric(rule.metric)<int(rule.amount):
			return false
	return true

func claim(id: String) -> bool:
	if not ready(id):
		return false
	var before: Dictionary = state.serialize().duplicate(true)
	data().claimed.append(id)
	state.team_credits += int(project(id).reward)
	if not state.ops._finish(before):
		return false
	state.machine_message.emit(Localization.text("Progetto completato: ")+project(id).name)
	return true

func complete() -> bool:
	return state.completed_orders.size()>=state.order_defs.size() and data().claimed.size()==definition().projects.size()

func chapter() -> Dictionary:
	if state.current_order().is_empty():
		return definition().aftermath
	return definition().chapters[mini(state.completed_orders.size(),definition().chapters.size()-1)]

func _step(title: String, detail: String, route: String, material: String = "") -> Dictionary:
	return {"title":title,"detail":detail,"route":route,"material":material}

func next_step() -> Dictionary:
	var order: Dictionary = state.current_order()
	if order.is_empty():
		for item in definition().projects:
			if ready(item.id):
				return _step(Localization.text("Riconoscimento pronto: ")+Localization.text(item.name),Localization.text("Apri il diario e conferma il progetto per attivarne il beneficio."),"career")
		if not state.operations.active_delivery.is_empty():
			var delivery: Dictionary = state.ops.delivery_definition()
			for product in delivery.get("products",{}):
				if int(state.crafting.data().stock.get(product,0))<int(delivery.products[product]):
					return _step(Localization.text("Prepara ")+Localization.text(state.crafting.definitions()[product].name),Localization.format_text("La fornitura richiede %d prodotti pronti; %d sono ancora in assemblaggio. Chiudi i menu per far lavorare il banco.", [delivery.products[product],state.fabrication.count(product)]),"fabrication" if state.fabrication.count(product)>0 else "craft")
			return _step(Localization.text("Completa la fornitura attiva"),Localization.text("Porta materiali e componenti al deposito. La banchina nel Lotto dune mostra cosa manca."),"dispatch")
		if not complete():
			return _step(Localization.text("Mantieni le tre promesse"),Localization.text("Clienti, richieste di pezzi e forniture fanno avanzare i progetti del diario."),"career")
		if not state.owns_tool(3) or not state.owns_tool(4):
			return _step(Localization.text("Prepara gli attrezzi da esplorazione"),Localization.text("Costruisci piede di porco e cesoie al banco; le casse nei nuovi punti di recupero richiedono entrambi."),"craft")
		if int(state.operations.deliveries)<5:
			return _step(Localization.text("Allarga la tua attività"),Localization.text("Completa cinque forniture per i moduli industriali L4. Puoi costruire kit e depositi da campo."),"dispatch")
		for id in ["cargo_rack","suspension","press_drive"]:
			if int(state.workshop_modules.get(id,0))<4:
				return _step(Localization.text("Costruisci il prossimo miglioramento"),Localization.text("Scegli un kit al banco oppure un modulo al monitor. Esplora i relitti oltre i cancelli per nuovi componenti."),"craft")
		return _step(Localization.text("Esplora oltre il deposito"),Localization.text("I tre siti delle dune hanno recuperi sigillati; prosegui con clienti, collezione e forniture."),"north_cache")
	if state.can_complete_order():
		return _step(Localization.text("Consegna: ")+Localization.text(order.name),Localization.text("Tutti i requisiti sono pronti nel deposito. Conferma al monitor dell'ufficio."),"tools")
	var stage: int = state.completed_orders.size()
	var desired_land: int = 0 if stage==0 else (1 if stage==1 else 2)
	if state.yard_level<desired_land:
		var land: Dictionary = state.land_defs[state.yard_level]
		if int(state.team_upgrade_levels.tool)<int(land.requires_tool):
			return _step(Localization.text("Prepara l'attrezzo per il prossimo lotto"),Localization.text("Al monitor compra ")+Localization.text(state.tool_defs[int(land.requires_tool)].name)+Localization.text(". Vendi soltanto le scorte che non ti servono."),"tools")
		for material in land.project_materials:
			if int(state.team_deposit_counts.get(material,0))<int(land.project_materials[material]):
				return _collect_step(Localization.text("Prepara il progetto del terreno"),Localization.format_text("Deposita %d %s per aprire il nuovo lotto.", [land.project_materials[material],material]),material)
		return _step(Localization.text("Apri ")+Localization.text(land.name),Localization.text("Vai alla planimetria. Servono %d Bulloni e i materiali del progetto.") % land.cost,"land")
	if state.vehicle_level<int(order.get("requires_vehicle",0)):
		return _step(Localization.text("Porta il buggy in officina"),Localization.text("Acquista i mezzi al chiosco del garage; il buggy richiede prima il monopattino."),"vehicles")
	if int(order.bales)>state.press_bales:
		if not state.press_owned:
			return _step(Localization.text("Installa la prima pressa"),Localization.format_text("Servono %d Bulloni. L'impianto trasforma %d metalli in una balla.", [state.press_def.cost,state.press_def.input_units]),"press")
		if state.press_remaining>0 or int(state.operations.press_queue)>0:
			return _step(Localization.text("La pressa sta lavorando"),Localization.text("Chiudi i menu per far proseguire il tempo. Puoi raccogliere altri materiali nel frattempo."),"press")
		if int(state.team_deposit_counts.metal)<int(state.press_def.input_units):
			return _collect_step(Localization.text("Rifornisci la pressa"),Localization.text("Deposita almeno %d metalli per il prossimo lotto.") % state.press_def.input_units,"metal")
		return _step(Localization.text("Accoda le balle della commessa"),Localization.text("Alla pressa prenota i lotti necessari e torna al recupero."),"press")
	var bag: Dictionary = state.player_inventories.get(1,{})
	for material in order.materials:
		var missing: int = int(order.materials[material])-int(state.team_deposit_counts.get(material,0))
		if missing<=0:
			continue
		if int(bag.get(material,0))>=missing or state.get_inventory_mass(1)+float(state.material_defs[material].mass_kg)>state.get_inventory_capacity(1):
			return _step(Localization.text("Riporta i materiali al deposito"),Localization.text("Scarica alla bilancia: depositare conserva le scorte, vendere le consuma."),"depot")
		return _collect_step(Localization.text("Recupera ")+Localization.text({"metal":"metallo","plastic":"plastica","electronics":"elettronica","copper":"rame","aluminum":"alluminio","glass":"vetro","rubber":"gomma"}.get(material,material)),Localization.format_text("Nel deposito: %d / %d. Cerca nel settore indicato, poi scarica senza vendere le scorte della commessa.", [state.team_deposit_counts.get(material,0),order.materials[material]]),material)
	return _step(Localization.text("Controlla i requisiti della commessa"),state.order_requirement(),"tools")

static func validate(value: Variant, game, save: Dictionary) -> bool:
	if not value is Dictionary or not value.get("claimed") is Array or not value.get("stats") is Dictionary:
		return false
	var known: Dictionary = {}
	for spec in game.logistics_def.story.projects:
		known[spec.id] = spec
	for id in value.claimed:
		if not id is String or not known.has(id) or value.claimed.count(id)!=1 or save.get("completed_orders",[]).size()<int(known[id].orders):
			return false
	for key in value.stats:
		if key not in ["marta_sales","enzo_sales"] or not SaveService._valid_count(value.stats[key]) or value.stats[key]>1000000:
			return false
	return true

func reserves() -> Dictionary:
	var counts: Dictionary = {}
	var bales: int = 0
	var order: Dictionary = state.current_order()
	if not order.is_empty():
		for material in order.materials:
			counts[material] = int(order.materials[material])
		bales += int(order.bales)
	var desired_land: int = 0 if state.completed_orders.is_empty() else (1 if state.completed_orders.size()==1 else 2)
	if state.yard_level<desired_land:
		for material in state.land_defs[state.yard_level].project_materials:
			counts[material] = int(counts.get(material,0))+int(state.land_defs[state.yard_level].project_materials[material])
	var delivery: Dictionary = state.ops.delivery_definition()
	if not delivery.is_empty():
		for material in delivery.materials:
			counts[material] = int(counts.get(material,0))+int(delivery.materials[material])
		# Queued products have already reserved their ingredients. Finished stock needs none.
		for product in delivery.get("products",{}):
			var missing: int = maxi(0,int(delivery.products[product])-int(state.crafting.data().stock.get(product,0))-state.fabrication.count(product))
			var recipe: Dictionary = state.crafting.definitions()[product]
			for material in recipe.materials:
				counts[material] = int(counts.get(material,0))+missing*int(recipe.materials[material])
		bales += int(delivery.bales)
	var waiting: int = maxi(0,bales-state.press_bales-int(state.operations.press_queue)-(1 if state.press_remaining>0 else 0))
	if state.press_owned:
		counts.metal = int(counts.get("metal",0))+waiting*int(state.press_def.input_units)
	return {"materials":counts,"bales":bales}

func surplus_value() -> int:
	var keep: Dictionary = reserves()
	var result: int = maxi(0,state.press_bales-int(keep.bales))*state.get_bale_value()
	for material in state.team_deposit_counts:
		result += maxi(0,int(state.team_deposit_counts[material])-int(keep.materials.get(material,0)))*int(state.material_defs[material].credits)
	return result

func _collect_step(title: String, detail: String, material: String) -> Dictionary:
	var initial: int = int(state.sector_initial_counts.get(material,0))
	var consumed: int = 0
	for id in state.sector_consumed_ids:
		if id.begins_with(material+"_"):
			consumed += 1
	if initial>0 and consumed>=initial and int(state.player_inventories.get(1,{}).get(material,0))==0:
		return _step(Localization.text("Prepara una nuova spedizione"),Localization.text("I rottami sciolti di questa famiglia sono esauriti. Puoi cercare nei cumuli oppure scaricare la sacca e rinnovare i recuperi alla bilancia."),"depot")
	return _step(title,detail,"salvage",material)


