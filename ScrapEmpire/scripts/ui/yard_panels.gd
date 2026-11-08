extends RefCounted
const ART = preload("res://scripts/ui/menu_art.gd")

static func _text(column: Node, value: String, size: int = 18, color: Color = Color("#b9cece")) -> Label:
	var label = ART.label(value,size,color)
	var width: float = float(column.get_meta("text_width",0))
	if width > 0:
		label.custom_minimum_size.x = width
		label.size.x = width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label

static func _button(column: Node, text: String, player: Node, action: String, id: String = "", count: int = 0, enabled: bool = true) -> Button:
	var button = Button.new()
	button.text = text
	button.disabled = not enabled
	if is_instance_valid(player):
		button.pressed.connect(player._ops_action.bind(action,id,count))
	ART.button_style(button,enabled and action in ["complete_delivery","store_bag","unload"])
	column.add_child(button)
	return button

static func _scroll(column: VBoxContainer, height: float = 280) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760,height)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content = VBoxContainer.new()
	content.set_meta("text_width",760)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	return content

static func _close(player: Node) -> void:
	player._add_panel_button("TORNA AL LAVORO",player._close_pause_menu)
	player._pause_menu.popup_centered(Vector2i(880,650))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(880,650))

static func cargo(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("BUGGY / CASSONE")
	player._panel_box.add_theme_constant_override("separation",8)
	player._panel_box.set_meta("text_width",760)
	player._panel_metrics([["CARICO","%.0f / %d kg" % [GameState.ops.cargo_mass(),GameState.ops.cargo_capacity()]],["SACCA","%.0f kg" % GameState.get_inventory_mass(1)],["COMPONENTI",str(GameState.operations.cargo_parts.size())]])
	var meter = ProgressBar.new()
	meter.max_value = GameState.ops.cargo_capacity()
	meter.value = GameState.ops.cargo_mass()
	player._panel_box.add_child(meter)
	ART.details(player._panel_box,"Materiali e componenti condividono il peso del cassone. Per caricare un pezzo intero, sollevalo e premi E dietro al buggy.","Carico")
	var rows = _scroll(player._panel_box,110)
	var request: Dictionary = GameState.specifics.payload()
	for key in request.get("cargo",{}):
		_text(rows,"RICHIESTA · %s ×%d" % [preload("res://scripts/gameplay/scrap_catalog.gd").item_name(key.get_slice("_",0).to_int(),key.get_slice("_",1).to_int()),request.cargo[key]])
	for material in GameState.operations.cargo:
		if int(GameState.operations.cargo[material]) > 0:
			_text(rows,"%s  × %d" % [_material_name(material),GameState.operations.cargo[material]])
	for item in GameState.operations.cargo_parts:
		_text(rows,"%s · %d kg · %s" % [GameState.part_defs[item.kind].name,GameState.part_defs[item.kind].mass_kg,"funzionante" if int(item.quality) == 1 else "da riparare"])
	if GameState.ops.cargo_mass() <= 0:
		_text(rows,"Cassone vuoto. Trasporta materiali o recuperi ingombranti.")
	_button(player._panel_box,"CARICA LA SACCA NEL CASSONE",player,"load_bag","",0,GameState.get_inventory_mass(1)>0 and GameState.ops.cargo_mass()+GameState.get_inventory_mass(1)<=GameState.ops.cargo_capacity())
	_button(player._panel_box,"SCARICA MATERIALI E COMPONENTI NEL DEPOSITO",player,"unload","",0,player._buggy_at_storage() and GameState.ops.cargo_mass()>0)
	ART.details(player._panel_box,"Scarico disponibile vicino alla bilancia, agli scarichi satellite o al banco recupero.","Punti di scarico")
	_close(player)

static func parts(player: Node, workbench: bool) -> void:
	preload("res://scripts/ui/components_panel.gd").open(player,workbench)

static func production(player: Node) -> void:
	preload("res://scripts/ui/press_panel.gd").production(player)

static func delivery_content(column: VBoxContainer, player: Node, enabled: bool = true) -> Dictionary:
	var buttons: Dictionary = {}
	var certified: bool = GameState.completed_orders.size() >= GameState.order_defs.size()
	_text(column,"%d consegne" % GameState.operations.deliveries,20,Color("#83c4ac"))
	if not certified:
		_text(column,"Completa le cinque commesse di avviamento per accettare forniture industriali.",18)
	var current: Dictionary = GameState.ops.delivery_definition()
	if current.is_empty():
		_text(column,"Scegli un incarico. I materiali vengono consumati solo alla consegna.",16)
		for definition in GameState.delivery_defs:
			var panel = PanelContainer.new()
			column.add_child(panel)
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation",18)
			panel.add_child(row)
			var details = VBoxContainer.new()
			details.custom_minimum_size.x = 500
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(details)
			_text(details,definition.name.to_upper(),22,Color("#efcf8a"))
			_text(details,"Completate: %d" % int(GameState.operations.get("delivery_history",{}).get(definition.id,0)),14)
			var needs: PackedStringArray = []
			for kind in definition.parts:
				needs.append("%s ×%d" % [GameState.part_defs[kind].name,definition.parts[kind]])
			for material in definition.materials:
				needs.append("%s ×%d" % [_material_name(material),definition.materials[material]])
			for product in definition.get("products",{}):
				needs.append("%s ×%d" % [GameState.crafting.definitions()[product].name,definition.products[product]])
			if int(definition.bales)>0:
				needs.append("Balle ×%d" % definition.bales)
			_text(details,", ".join(needs),16)
			buttons["delivery_"+definition.id] = _button(row,"ACCETTA\n%d Bulloni" % definition.reward,player,"accept_delivery",definition.id,0,enabled and certified)
	else:
		_text(column,current.name.to_upper(),25,Color("#efcf8a"))
		ART.details(column,current.description,"Incarico")
		for kind in current.parts:
			_text(column,"%s funzionanti  ·  %d / %d" % [GameState.part_defs[kind].name,GameState.ops.usable_parts(kind),current.parts[kind]],20)
		for material in current.materials:
			_text(column,"%s nel deposito  ·  %d / %d" % [_material_name(material),GameState.team_deposit_counts[material],current.materials[material]],20)
		for product in current.get("products",{}):
			_text(column,"%s pronti · %d / %d · %d in assemblaggio" % [GameState.crafting.definitions()[product].name,GameState.crafting.data().stock.get(product,0),current.products[product],GameState.fabrication.count(product)],20)
		if int(current.bales)>0:
			_text(column,"Balle pressate  ·  %d / %d" % [GameState.press_bales,current.bales],20)
		buttons["complete_delivery"] = _button(column,"CONSEGNA · %d BULLONI" % current.reward,player,"complete_delivery","",int(GameState.operations.active_delivery.ticket),enabled and GameState.ops.delivery_ready())
		_button(column,"INDICA UN RECUPERO SUL NAVIGATORE",player,"route_parts","",0,enabled and not current.parts.is_empty())
		if not current.get("products",{}).is_empty():
			_button(column,"INDICA IL BANCO COSTRUZIONE",player,"route_products","",0,enabled)
		_button(column,"RINUNCIA ALL’INCARICO · MATERIALI CONSERVATI",player,"cancel_delivery","",0,enabled)
	return buttons

static func deliveries(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("LOTTO DUNE / SPEDIZIONI")
	player._panel_box.add_theme_constant_override("separation",8)
	player._panel_box.set_meta("text_width",760)
	delivery_content(_scroll(player._panel_box,260),player)
	_close(player)

static func _material_name(id: String) -> String:
	return {"metal":"Metallo","plastic":"Plastica","electronics":"Elettronica","copper":"Rame","aluminum":"Alluminio","glass":"Vetro","rubber":"Gomma"}.get(id,id)
