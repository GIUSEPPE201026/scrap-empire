extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")
const MOBILITY=preload("res://scripts/economy/extra_mobility.gd")

static func open(player: Node, kind: String) -> void:
	player._close_pause_menu()
	player._open_panel("GARAGE / PARCO MEZZI")
	var layout=HBoxContainer.new()
	layout.add_theme_constant_override("separation",20)
	player._panel_box.add_child(layout)
	var navigation=UI.column(layout,230)
	navigation.add_child(ART.label("CATALOGO MEZZI",13,UI.MUTED))
	for index in 7:
		var button=Button.new()
		button.icon=ART.SYMBOLS.icon(["scooter","truck","skateboard","dirtbike","forklift","crane","loader"][index])
		button.pressed.connect(player._select_vehicle.bind(index))
		UI.action(button,["Monopattino","Buggy","Skateboard","Moto da cross","Muletto","Gru magnetica","Minipala"][index],index==(["skateboard","dirtbike","forklift","crane","loader"].find(kind)+2))
		button.add_theme_constant_override("icon_max_width",40)
		button.custom_minimum_size.y=52
		navigation.add_child(button)
	var personalize=Button.new()
	personalize.icon=ART.SYMBOLS.icon("tools")
	UI.action(personalize,"Insegna e colori",false)
	personalize.pressed.connect(player._open_personalization)
	navigation.add_child(personalize)
	var shell=UI.column(layout,510)
	var pages=TabContainer.new()
	pages.custom_minimum_size.y=380
	pages.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	shell.add_child(pages)
	var scroll=ScrollContainer.new()
	scroll.name="Mezzo"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pages.add_child(scroll)
	pages.set_tab_title(0,Localization.text("Mezzo"))
	var detail=VBoxContainer.new()
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",8)
	scroll.add_child(detail)
	var spec: Dictionary=GameState.logistics_def.mobility[kind]
	UI.picture(detail,kind,Vector2(510,160))
	detail.add_child(ART.label(spec.name.to_upper(),24,UI.PAPER))
	detail.add_child(ART.label(Localization.format_text("%.0f km/h · %d Bulloni", [float(spec.speed_mps)*3.6,spec.cost]),20,UI.ORANGE))
	var role: String="SPINTA · OLLIE · PORTATILE" if kind=="skateboard" else ("FORCHE · PALLET · LOGISTICA" if kind=="forklift" else "MOTORE · SALTI · DUE RUOTE")
	if kind=="crane": role="MAGNETE · COMPONENTI FERROSI"
	if kind=="loader": role="BENNA · ROTTAMI SPARSI"
	detail.add_child(ART.label(role,15,UI.MUTED))
	if kind not in ["forklift","crane","loader"]: ART.details(detail,"4 equipaggia/riponi il portatile scelto. W spinge, S frena, A/D curva, Spazio ollie. Non occupa il mondo quando riposto." if kind=="skateboard" else "Nessun cassone. W/S gas/freno, A/D sterzo, Shift impenna, Spazio salta, V visuale, P parcheggio, E scendi. Lotto Est richiesto.","Comandi")
	if kind=="forklift": ART.details(detail,"G aggancia/rilascia il pallet a bassa velocità. Sinistro alza le forche, destro abbassa. H da fermo apre il terminale: carica al deposito o spedisci alla banchina senza scendere. V visuale, E scendi.","Forche")
	if kind in ["crane","loader"]: ART.details(detail,"G prende/rilascia il carico. Sinistro alza, destro abbassa. Fermati e avvicina il magnete ai componenti ferrosi oppure la benna ai rottami sparsi. Non modifica il terreno.","Carico")
	if kind in ["crane","loader"]: ART.details(detail,"G vicino a bilancia o magazzino scarica direttamente, senza vendere. Fermati e solleva il carico sopra gli ostacoli: compare G · SCARICA.","Deposito")
	if kind=="loader": ART.details(detail,"H con benna bassa e vuota spinge un frammento leggero del cumulo, se lo spazio è libero. Nessun materiale aggiuntivo viene generato; il terreno rimane invariato.","Macerie")
	if kind in ["forklift","crane","loader"]:
		var job_scroll=ScrollContainer.new()
		job_scroll.name="Incarichi"
		job_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		pages.add_child(job_scroll)
		pages.set_tab_title(1,Localization.text("Incarichi"))
		var work=VBoxContainer.new()
		work.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		work.add_theme_constant_override("separation",10)
		job_scroll.add_child(work)
		UI.picture(work,kind,Vector2(420,110))
		preload("res://scripts/ui/industrial_job_panel.gd").build(work,player,kind)
		player._pause_menu.set_meta("vehicle_job_tabs",pages)
		if preload("res://scripts/economy/industrial_jobs.gd").progress(kind).active: pages.current_tab=1
	var action=Button.new()
	action.icon=ART.SYMBOLS.icon(kind)
	if MOBILITY.owned(kind):
		UI.action(action,"Equipaggia" if kind=="skateboard" else "Indica il mezzo",true)
		action.pressed.connect(equip.bind(player,kind))
	else:
		UI.action(action,"Acquista",true)
		action.disabled=GameState.yard_level<int(spec.requires_land) or GameState.team_credits<int(spec.cost)
		action.pressed.connect(buy.bind(player,kind))
		if GameState.yard_level<int(spec.requires_land): action.tooltip_text="Apri prima il Lotto Est."
	shell.add_child(action)
	player._pause_menu.popup_centered(Vector2i(880,650))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(880,650))

static func buy(player: Node, kind: String) -> void:
	if player._near_service("vehicles")!="vehicles": return
	if MOBILITY.purchase(kind):
		player.get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
		player._notify(Localization.text("Acquisto salvato · ")+GameState.logistics_def.mobility[kind].name)
	open(player,kind)

static func equip(player: Node, kind: String) -> void:
	if kind=="skateboard":
		player._choose_portable(kind)
	else:
		for vehicle in player.get_tree().get_nodes_in_group("yard_vehicles"):
			if vehicle.vehicle_kind==kind: player._track_location(vehicle.global_position,GameState.logistics_def.mobility[kind].name.to_upper())
