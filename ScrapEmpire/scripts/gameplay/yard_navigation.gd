extends RefCounted
const HUB = preload("res://scripts/gameplay/hub_layout.gd")
const CAREER = Vector3(-15,0,5)

static func points(player: Node) -> Dictionary:
	var result: Dictionary = {
		"depot":{"name":"Bilancia / deposito","position":Vector3(0,0,14)},
		"tools":{"name":"Ufficio / upgrade e commesse","position":HUB.TOOLS},
		"land":{"name":"Planimetria / espansioni","position":HUB.LAND},
		"vehicles":{"name":"Garage / acquisto mezzi","position":HUB.VEHICLES},
		"press":{"name":"Pressa / produzione","position":HUB.PRESS},
		"career":{"name":"Bacheca di Riva Secca","position":CAREER},
		"salvage":{"name":"Settore di recupero iniziale","position":Vector3(-12,0,-30)},
		"lot1":{"name":"Lotto Est","position":Vector3(96,0,0),"locked":GameState.yard_level<1},
		"lot2":{"name":"Lotto dune","position":Vector3(181,0,0),"locked":GameState.yard_level<2}
	}
	for site in GameState.logistics_def.get("outposts",[]):
		result[site.id]={"name":site.name,"position":Vector3(site.position[0],preload("res://scripts/gameplay/desert_world.gd").height_at(Vector3(site.position[0],0,site.position[2])),site.position[2])}
	result.oasis={"name":"Oasi / scarico satellite","position":preload("res://scripts/gameplay/leisure_sites.gd").OASIS+Vector3(-22,3,-8)}
	result.dune_park={"name":"Dune Park / rampe e giro a tempo","position":preload("res://scripts/gameplay/leisure_sites.gd").PARK+Vector3(0,0,42)}
	var landmarks=preload("res://scripts/gameplay/desert_landmarks.gd")
	for id in landmarks.SITES:
		if id=="crash" or id in GameState.operations.get("visited_sites",[]):
			result[id]={"name":landmarks.SITES[id].name,"position":landmarks.point(id)}
	for node in player.get_tree().get_nodes_in_group("operations_service"):
		var key: String = str(node.get_meta("operation"))
		if key=="customer":
			key = "customer_"+str(node.get_meta("customer"))
		var caption: String = {"fabrication":"Banco assemblaggio","craft":"Banco costruzione","warehouse":"Magazzino componenti","recovery":"Banco recupero","dispatch":"Banchina spedizioni","customer_marta":"Marta / lampade","customer_enzo":"Enzo / cassette"}.get(key,"Bacheca")
		if key.begins_with("customer_"):
			var customer: Dictionary = GameState.crafting.customer(str(node.get_meta("customer")))
			caption=customer.name.get_slice(" · ",0)+" / "+GameState.crafting.definitions()[customer.product].name
		result[key] = {"name":caption,"position":node.global_position}
	if result.has("customer_marta"):
		result.customer = result.customer_marta
	if not GameState.operations.get("delivery_history",{}).is_empty():
		if int(GameState.operations.delivery_history.get("town_square",0))+int(GameState.operations.delivery_history.get("neighborhood_gardens",0))>0:
			result.square={"name":"Piazza del riuso","position":preload("res://scripts/gameplay/town_projects.gd").SQUARE}
	return result

static func objective(player: Node, step: Dictionary) -> Dictionary:
	var all: Dictionary = points(player)
	if not str(step.get("part","")).is_empty():
		var kind: String = step.part
		var best: float = INF
		var source: Dictionary = {}
		for node in player.get_tree().get_nodes_in_group("bulk_parts"):
			if not node.is_queued_for_deletion() and node.kind==kind and player.global_position.distance_squared_to(node.global_position)<best:
				best=player.global_position.distance_squared_to(node.global_position)
				source={"name":GameState.part_defs[kind].name+" / recupero intero","position":node.global_position}
		if not source.is_empty():
			return source
		for node in player.get_tree().get_nodes_in_group("salvage_assemblies"):
			if node.is_queued_for_deletion():
				continue
			var steps: Array = GameState.salvage_defs[node.definition_id].steps
			for index in steps.size():
				if steps[index].part==kind and index not in GameState.ops.completed_components(node.entity_id) and player.global_position.distance_squared_to(node.global_position)<best:
					best=player.global_position.distance_squared_to(node.global_position)
					source={"name":GameState.salvage_defs[node.definition_id].name+" / smontaggio","position":node.global_position}
		if not source.is_empty():
			return source
		return {"name":"Bilancia / nuova spedizione per altri componenti","position":all.depot.position}
	var id: String = step.route
	if id=="salvage":
		if step.material in ["copper","aluminum"]:
			id = "lot1"
		elif step.material in ["glass","rubber"]:
			id = "lot2"
	return all.get(id,all.career)
