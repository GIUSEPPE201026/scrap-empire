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
	var navigation=UI.column(layout,200)
	for index in 4:
		var button=Button.new()
		button.icon=ART.SYMBOLS.icon(["scooter","truck","skateboard","dirtbike"][index])
		button.pressed.connect(player._select_vehicle.bind(index))
		UI.action(button,["Monopattino","Buggy","Skateboard","Moto da cross"][index],index==(2 if kind=="skateboard" else 3))
		navigation.add_child(button)
	var detail=UI.column(layout,400)
	var spec: Dictionary=GameState.logistics_def.mobility[kind]
	UI.picture(detail,kind,Vector2(350,150))
	detail.add_child(ART.label(spec.name.to_upper(),24,UI.PAPER))
	detail.add_child(ART.label("%.0f km/h · %d Bulloni" % [float(spec.speed_mps)*3.6,spec.cost],20,UI.ORANGE))
	detail.add_child(ART.label("SPINTA · OLLIE · PORTATILE" if kind=="skateboard" else "MOTORE · SALTI · DUE RUOTE",15,UI.MUTED))
	ART.details(detail,"4 equipaggia/riponi il portatile scelto. W spinge, S frena, A/D curva, Spazio ollie. Non occupa il mondo quando riposto." if kind=="skateboard" else "Nessun cassone. W/S gas/freno, A/D sterzo, Spazio alleggerisce per un salto, V visuale, P parcheggio, E scendi. Lotto Est richiesto.","Comandi")
	var action=Button.new()
	if MOBILITY.owned(kind):
		UI.action(action,"Equipaggia" if kind=="skateboard" else "Indica la moto",true)
		action.pressed.connect(equip.bind(player,kind))
	else:
		UI.action(action,"Acquista",true)
		action.disabled=GameState.yard_level<int(spec.requires_land) or GameState.team_credits<int(spec.cost)
		action.pressed.connect(buy.bind(player,kind))
		if GameState.yard_level<int(spec.requires_land): action.tooltip_text="Apri prima il Lotto Est."
	detail.add_child(action)
	player._pause_menu.popup_centered(Vector2i(780,580))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(780,580))

static func buy(player: Node, kind: String) -> void:
	if player._near_service("vehicles")!="vehicles": return
	if MOBILITY.purchase(kind):
		player.get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
		player._notify("Acquisto salvato · "+GameState.logistics_def.mobility[kind].name)
	open(player,kind)

static func equip(player: Node, kind: String) -> void:
	if kind=="skateboard":
		player._choose_portable(kind)
	else:
		for vehicle in player.get_tree().get_nodes_in_group("yard_vehicles"):
			if vehicle.vehicle_kind==kind: player._track_location(vehicle.global_position,"MOTO DA CROSS")
