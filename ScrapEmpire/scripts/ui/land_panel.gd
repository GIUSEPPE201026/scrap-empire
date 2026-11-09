extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func open(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("PLANIMETRIA / TERRENI")
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	player._panel_box.add_child(row)
	var preview=UI.column(row,310)
	UI.picture(preview,"land",Vector2(270,160))
	preview.add_child(ART.label(Localization.text("TERRENO / %d DI 2") % GameState.yard_level,21,UI.PAPER))
	preview.add_child(ART.label("+24 rottami · 3 cumuli",16,UI.ORANGE))
	preview.add_child(ART.label("2 smontaggi · scarico satellite",14,UI.MUTED))
	var detail=UI.column(row,350)
	if GameState.yard_level<GameState.land_defs.size():
		var land: Dictionary=GameState.land_defs[GameState.yard_level]
		detail.add_child(ART.label("LOTTO EST" if GameState.yard_level==0 else "LOTTO DUNE",25,UI.PAPER))
		detail.add_child(ART.label(Localization.text("%d Bulloni") % land.cost,23,UI.ORANGE))
		var tool=HBoxContainer.new()
		detail.add_child(tool)
		UI.picture(tool,"screwdriver" if int(land.requires_tool)==1 else "hammer",Vector2(44,44))
		tool.add_child(ART.label(GameState.tool_defs[int(land.requires_tool)].name,16,UI.PAPER))
		for id in land.project_materials:
			preload("res://scripts/ui/office_pages.gd").stock_row(detail,id,preload("res://scripts/ui/yard_panels.gd")._material_name(id),int(GameState.team_deposit_counts.get(id,0)),int(land.project_materials[id]))
		var button=Button.new()
		var reason: String=GameState.land_requirement_message()
		button.disabled=not reason.is_empty()
		button.pressed.connect(player._buy_land)
		UI.action(button,"Apri lotto",not button.disabled)
		button.set_meta("action_label","ALLESTISCI E APRI IL LOTTO")
		button.tooltip_text=reason if not reason.is_empty() else "Consuma il progetto solo all'apertura riuscita."
		detail.add_child(button)
	else:
		detail.add_child(ART.label("DUE LOTTI OPERATIVI",23,UI.PAPER))
		detail.add_child(ART.label("EST · RECUPERO",17,UI.ORANGE))
		detail.add_child(ART.label("DUNE · LOGISTICA",17,UI.ORANGE))
	var close=Button.new()
	close.pressed.connect(player._close_pause_menu)
	UI.action(close,"Chiudi")
	player._panel_box.add_child(close)
	player._pause_menu.popup_centered(Vector2i(760,500))
