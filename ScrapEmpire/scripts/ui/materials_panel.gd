extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")
const NAMES={"metal":"Metallo","plastic":"Plastica","electronics":"Elettronica","copper":"Rame","aluminum":"Alluminio","glass":"Vetro","rubber":"Gomma"}

static func open(player: Node, material: String="") -> void:
	if NAMES.has(material): player._material_selection=material
	var selected: String=player._material_selection
	player._close_pause_menu()
	player._open_panel("BILANCIA / MATERIALI")
	var body=HBoxContainer.new()
	body.add_theme_constant_override("separation",20)
	player._panel_box.add_child(body)
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(354,356)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	for id in NAMES:
		var amount: int=int(player.get_inventory().get(id,0))+int(GameState.team_deposit_counts.get(id,0))
		var tile=UI.tile(grid,id,NAMES[id],player._open_cargo.bind(id),id==selected,true,str(amount))
		tile.custom_minimum_size=Vector2(110,104)
		var art: TextureRect=tile.get_child(0).get_child(0)
		art.custom_minimum_size=Vector2(70,54)
		tile.set_meta("material_id",id)
	var side=VBoxContainer.new()
	side.custom_minimum_size.x=340
	side.add_theme_constant_override("separation",10)
	body.add_child(side)
	UI.hero(side,selected,Vector2(320,112))
	side.add_child(ART.label(NAMES[selected].to_upper(),24,UI.PAPER))
	side.add_child(ART.label(Localization.format_text("%.1f kg / pezzo  ·  %d Bulloni / pezzo", [GameState.material_defs[selected].mass_kg,GameState.material_defs[selected].credits]),14,UI.MUTED))
	for source in ["bag","deposit"]:
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		side.add_child(row)
		var quantity: int=int(player.get_inventory().get(selected,0)) if source=="bag" else int(GameState.team_deposit_counts.get(selected,0))
		var caption=ART.label(Localization.text("Sacca" if source=="bag" else "Deposito")+"  ×%d" % quantity,18,UI.PAPER)
		caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var sell=Button.new()
		sell.icon=ART.SYMBOLS.icon("coin")
		sell.disabled=not player._near_depot() or quantity<=0
		sell.set_meta("material_id",selected)
		sell.set_meta("source",source)
		sell.pressed.connect(player._sell_one.bind(selected,source))
		UI.action(sell,"Vendi 1",not sell.disabled)
		sell.tooltip_text=Localization.format_text("Vendi 1 %s dalla %s per %d Bulloni", [Localization.text(NAMES[selected]),Localization.text("Sacca" if source=="bag" else "Deposito"),GameState.material_defs[selected].credits])
		row.add_child(sell)
	var note=ART.label("Vendita singola · solo alla bilancia",13,UI.MUTED)
	side.add_child(note)
	var back=Button.new()
	back.pressed.connect(player._back_to_station)
	UI.action(back,"Bilancia")
	player._panel_box.add_child(back)
	player._pause_menu.popup_centered(Vector2i(820,520))
