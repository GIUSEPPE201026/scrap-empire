extends RefCounted
const JOBS=preload("res://scripts/economy/industrial_jobs.gd")
const ART=preload("res://scripts/ui/menu_art.gd")
const CRAFT=preload("res://scripts/ui/crafting_panel.gd")

static func build(parent: Node, player: Node, kind: String) -> void:
	var box=VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	parent.add_child(box)
	box.add_child(ART.label("INCARICO DEL MEZZO",13))
	var name=ART.label("",18)
	box.add_child(name)
	var status=ART.label("",15)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var button=CRAFT.button(box,"Accetta incarico",act.bind(player,kind,box),true,true)
	var route=CRAFT.button(box,"Indica il lavoro",navigate.bind(player,kind))
	box.set_meta("job_controls",{"name":name,"status":status,"button":button,"route":route,"ticket":0})
	refresh(box,kind)

static func refresh(box: Node, kind: String) -> void:
	var controls: Dictionary=box.get_meta("job_controls")
	var step: Dictionary=JOBS.tier(kind)
	var progress: Dictionary=JOBS.progress(kind)
	controls.ticket=int(GameState.operations.serial)
	if step.is_empty():
		controls.name.text="Serie completata"
		controls.status.text="Il mezzo resta disponibile per trasporti e forniture."
		controls.button.hide()
		controls.route.hide()
		return
	controls.name.text=step.name
	controls.status.text=Localization.format_text("%d / %d · %d Bulloni",[progress.units,step.goal,step.reward])+"\n"+Localization.text(JOBS.spec(kind).description)
	controls.button.text="Ritira ricompensa" if int(progress.units)>=int(step.goal) else ("In corso" if progress.active else "Accetta incarico")
	controls.button.disabled=not preload("res://scripts/economy/extra_mobility.gd").owned(kind) or (progress.active and int(progress.units)<int(step.goal))
	ART.button_style(controls.button,not controls.button.disabled)
	controls.route.visible=progress.active

static func act(player: Node, kind: String, box: Node) -> void:
	var controls: Dictionary=box.get_meta("job_controls")
	var success: bool=JOBS.claim(kind,int(controls.ticket)) if JOBS.progress(kind).active else JOBS.start(kind,int(controls.ticket))
	refresh(box,kind)
	if not success: controls.status.text="Operazione non riuscita: controlla requisiti o salvataggio."

static func navigate(player: Node, kind: String) -> void:
	var at=Vector3(25,0,-28)
	var label: String="ROTTAMI DA TRASPORTARE"
	if kind=="loader":
		var loose=player.get_tree().get_nodes_in_group("scrap").filter(func(node):return not node.is_queued_for_deletion() and not node.is_in_group("hidden_salvage") and node.scrap_type in [0,1] and not node.has_meta("industrial_carrier"))
		loose.sort_custom(func(a,b):return a.global_position.distance_squared_to(player.global_position)<b.global_position.distance_squared_to(player.global_position))
		if not loose.is_empty(): at=loose[0].global_position
		else:
			at=player.get_tree().get_first_node_in_group("sector").get_node("DepositZone").global_position
			label="NUOVA SPEDIZIONE"
	if kind=="forklift":
		var machine=player.get_tree().get_nodes_in_group("yard_vehicles").filter(func(node):return node.vehicle_kind=="forklift")
		var loaded: bool=not machine.is_empty() and is_instance_valid(machine[0].carried) and int(GameState.crafting.data().objects.get(machine[0].carried.craft_id,{}).get("bales",0))>0
		var dock=player.get_tree().get_nodes_in_group("operations_service").filter(func(node):return node.get_meta("operation","")=="dispatch")
		at=dock[0].global_position if loaded and not dock.is_empty() else player.get_tree().get_first_node_in_group("sector").get_node("DepositZone").global_position
		label="BANCHINA SPEDIZIONI" if loaded else "DEPOSITO BALLE"
	elif kind=="crane":
		var parts=player.get_tree().get_nodes_in_group("bulk_parts").filter(func(node):return node.kind in ["engine","frame","panel"])
		if not parts.is_empty(): at=parts[0].global_position
		else:
			var assemblies=player.get_tree().get_nodes_in_group("salvage_assemblies").filter(func(node):return not node.get_step().is_empty())
			if not assemblies.is_empty(): at=assemblies[0].global_position
		label="COMPONENTI DA RECUPERARE"
	player._track_location(at,Localization.text(label))
