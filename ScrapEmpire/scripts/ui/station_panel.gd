extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func button(parent: Node, caption: String, action: Callable, primary: bool=false) -> Button:
	var control=Button.new()
	control.pressed.connect(action)
	UI.action(control,caption,primary)
	control.tooltip_text={"Deposita":"DEPOSITA LA SACCA","Vendi avanzi":"VENDI SOLO GLI AVANZI","Materiali":"MATERIALI / SINGOLE UNITÀ","Componenti":"COMPONENTI / MAGAZZINO"}.get(caption,caption)
	parent.add_child(control)
	return control

static func open(player: Node, page: String) -> void:
	player._close_pause_menu()
	player._open_panel("BILANCIA / SCARICO E VENDITA")
	player._panel_box.add_theme_constant_override("separation",14)
	player._station_deposit=null
	player._station_surplus=null
	player._station_all_sale=null
	var tabs=HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	player._panel_box.add_child(tabs)
	for entry in [["trade","Scarico · Vendita"],["stock","Scorte"],["expedition","Spedizioni"]]:
		button(tabs,entry[1],player._open_station.bind(entry[0]),page==entry[0])
	player._station_status=Label.new()
	player._panel_box.add_child(player._station_status)
	player._station_status.hide()
	player._station_buy=Button.new()
	player._panel_box.add_child(player._station_buy)
	player._station_buy.hide()
	var values: Dictionary={}
	if page=="trade":
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",16)
		player._panel_box.add_child(row)
		var bag=UI.column(row,330)
		bag.add_child(ART.label("01 / SCARICA",13,UI.MUTED))
		UI.picture(bag,"field_depot",Vector2(290,112))
		values.bag=ART.label("",26,UI.PAPER)
		bag.add_child(values.bag)
		player._station_deposit=button(bag,"Deposita",player._try_deposit,true)
		var stock=UI.column(row,330)
		stock.add_child(ART.label("02 / VENDI GLI AVANZI",13,UI.MUTED))
		var material_row=HBoxContainer.new()
		stock.add_child(material_row)
		for key in ["metal","plastic","electronics"]: UI.picture(material_row,key,Vector2(90,112))
		values.surplus=ART.label("",26,UI.ORANGE)
		stock.add_child(values.surplus)
		player._station_surplus=button(stock,"Vendi avanzi",player._sell_surplus,true)
		values.stock=ART.label("",14,UI.MUTED)
		player._panel_box.add_child(values.stock)
		player._station_all_sale=button(player._panel_box,"Vendi tutto…",player._confirm_sell_all)
		player._station_all_sale.tooltip_text="VENDI TUTTE LE SCORTE LIBERE… · include materiali utili agli obiettivi"
	elif page=="stock":
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",16)
		player._panel_box.add_child(row)
		for item in [["metal","Materiali",player._open_cargo],["engine","Componenti",player._open_parts_storage]]:
			var column=UI.column(row,330)
			UI.picture(column,item[0],Vector2(300,180))
			button(column,item[1],item[2],true)
	else:
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",18)
		player._panel_box.add_child(row)
		UI.picture(row,"buggy",Vector2(310,220))
		var column=VBoxContainer.new()
		column.custom_minimum_size.x=320
		column.add_theme_constant_override("separation",18)
		row.add_child(column)
		column.add_child(ART.label("UN ALTRO GIRO",26,UI.PAPER))
		var note=ART.label("Nuovi recuperi. Proprietà e scorte rimangono.\nScarica sacca e cassone prima di partire.",16,UI.MUTED)
		note.custom_minimum_size.x=300
		note.size.x=300
		note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(note)
		var expedition=button(column,"Nuova spedizione",player._new_expedition,true)
		expedition.tooltip_text="NUOVA SPEDIZIONE · RINNOVA I RECUPERI"
	player._pause_menu.set_meta("station_values",values)
	player._refresh_station()
	player._pause_menu.popup_centered(Vector2i(760,500))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(760,500))

static func refresh(player: Node) -> void:
	if not is_instance_valid(player._pause_menu) or not player._pause_menu.has_meta("station_values"): return
	var values: Dictionary=player._pause_menu.get_meta("station_values")
	if values.is_empty(): return
	values.bag.text="%.1f / %d kg" % [player.get_inventory_mass(),GameState.get_inventory_capacity(1)]
	values.surplus.text=Localization.text("%d Bulloni") % GameState.story.surplus_value()
	values.stock.text=Localization.format_text("Deposito: %d Bulloni · %d balle   /   Le scorte per gli obiettivi sono protette.", [GameState.get_deposit_value(),GameState.press_bales])
