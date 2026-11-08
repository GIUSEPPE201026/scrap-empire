extends RefCounted
const ART = preload("res://scripts/ui/menu_art.gd")
const PANELS = preload("res://scripts/ui/yard_panels.gd")
const UI=preload("res://scripts/ui/salvage_ui.gd")

static func category(kind: String, recipes: Dictionary) -> String:
	if kind in ["desk_lamp","toolbox"] or recipes[kind].has("customer"):
		return "products"
	if recipes[kind].has("install"):
		return "upgrades"
	return "tools" if kind in ["crowbar","bolt_cutters"] else "equipment"

static func button(parent: Node, label: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var control = Button.new()
	control.text = label
	control.disabled = not enabled
	control.pressed.connect(callback)
	ART.button_style(control,enabled and primary)
	parent.add_child(control)
	return control

static func open(player: Node, bench: bool, selection: String = "handcart") -> void:
	if bench:
		load("res://scripts/ui/workshop_catalog.gd").open(player,selection)
		return
	player._close_pause_menu()
	player._open_panel("GARAGE / BANCO COSTRUZIONE" if bench else "ATTREZZATURA / COSTRUZIONI")
	player._panel_box.add_theme_constant_override("separation",10)
	player._panel_box.set_meta("text_width",760)
	var data: Dictionary = GameState.crafting.data()
	ART.details(player._panel_box,"Scegli un oggetto pronto: apparirà un'anteprima nel mondo. Spostala guardando il terreno; rotella o R ruota, E o clic conferma, destro o Esc annulla. E sull'oggetto per usarlo o riporlo. Il carrello trasporta materiali ordinari.")
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size.y=300
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	player._panel_box.add_child(scroll)
	var grid=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	for kind in GameState.crafting.DEPLOYABLES:
		var tile=UI.tile(grid,kind,GameState.crafting.definitions()[kind].name,player._craft_action.bind("deploy",kind,0),false,int(data.stock.get(kind,0))>0,"×%d" % int(data.stock.get(kind,0)))
		tile.set_meta("action_label","POSIZIONA "+GameState.crafting.definitions()[kind].name.to_upper())
	var located=MenuButton.new()
	UI.action(located,"Trova attrezzatura · %d" % data.objects.size())
	player._panel_box.add_child(located)
	var ids: Array=data.objects.keys()
	for id in data.objects:
		located.get_popup().add_item(GameState.crafting.definitions()[data.objects[id].kind].name,ids.find(id))
	located.get_popup().id_pressed.connect(func(index):player._craft_action("locate",ids[index],0))
	player._add_panel_button("TORNA AL LAVORO",player._close_pause_menu)
	player._pause_menu.popup_centered(Vector2i(900,650))

static func object_menu(player: Node, object: Node3D) -> void:
	player._close_pause_menu()
	player._open_panel(GameState.crafting.definitions()[object.kind].name.to_upper())
	player._panel_box.add_theme_constant_override("separation",8)
	player._panel_box.set_meta("text_width",760)
	if object.kind=="handcart":
		var id: String = object.craft_id
		player._panel_metrics([["CARRELLO","%.0f / 60 kg" % GameState.crafting.cart_mass(id)],["SACCA","%.0f kg" % GameState.get_inventory_mass(1)]])
		ART.details(player._panel_box,"Carica materiali ordinari, traina a piedi e scarica vicino a bilancia o magazzino. Pezzi riservati alle richieste restano nella sacca.")
		var manifest = PANELS._scroll(player._panel_box,80)
		for material in GameState.crafting.data().objects[id].cargo:
			PANELS._text(manifest,"%s ×%d" % [PANELS._material_name(material),GameState.crafting.data().objects[id].cargo[material]],16)
		button(player._panel_box,"CARICA MATERIALI DALLA SACCA",player._craft_action.bind("load",id,0),GameState.get_inventory_mass(1)>GameState.specifics.mass("bag"))
		button(player._panel_box,"SCARICA NEL DEPOSITO",player._craft_action.bind("unload",id,0),player._at_parts_storage() and GameState.crafting.cart_mass(id)>0)
		button(player._panel_box,"TRAINA A PIEDI · E PER LASCIARE",player._craft_action.bind("tow",id,0),not is_instance_valid(player._mounted_vehicle) and GameState.operations.held.is_empty())
	if object.kind=="field_depot":
		player._panel_metrics([["SACCA","%.0f kg" % GameState.get_inventory_mass(1)],["DESTINAZIONE","Base"]])
		button(player._panel_box,"Deposita sacca",player._deposit_field,GameState.get_inventory_mass(1)>0,true)
	button(player._panel_box,"RIPONI NELL'ATTREZZATURA",player._craft_action.bind("pack",object.craft_id,0),object.kind!="handcart" or GameState.crafting.cart_mass(object.craft_id)==0)
	player._add_panel_button("TORNA AL LAVORO",player._close_pause_menu)
	player._pause_menu.popup_centered(Vector2i(860,650))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(860,650))

static func queue(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("GARAGE / ASSEMBLAGGIO")
	player._panel_box.set_meta("text_width",760)
	ART.details(player._panel_box,"Materiali riservati. Annulla per riaverli. La lavorazione continua mentre esplori; si ferma in pausa.","Come funziona")
	player._panel_metrics([["LAVORI","%d / %d" % [GameState.fabrication.jobs().size(),GameState.fabrication.capacity()]],["RAPIDITÀ","%d%%" % roundi(100.0/GameState.module_effect("assembly"))],["PRONTI",str(GameState.crafting.data().stock.values().reduce(func(a,b): return int(a)+int(b),0))]])
	var rows = PANELS._scroll(player._panel_box,270)
	if GameState.fabrication.jobs().is_empty():
		PANELS._text(rows,"Banco libero. Scegli un prodotto complesso dal catalogo.",22)
	for index in GameState.fabrication.jobs().size():
		var job: Dictionary = GameState.fabrication.jobs()[index]
		var header=HBoxContainer.new()
		rows.add_child(header)
		UI.picture(header,job.kind,Vector2(58,58))
		var title=ART.label("%s · %.0f s\n%s" % ["AL BANCO" if index==0 else "IN CODA",job.remaining,GameState.crafting.definitions()[job.kind].name],17,UI.PAPER)
		header.add_child(title)
		var progress = ProgressBar.new()
		progress.value=(1.0-float(job.remaining)/float(job.duration))*100.0
		progress.custom_minimum_size.y=16
		rows.add_child(progress)
		var cancel=button(rows,"ANNULLA · RESTITUISCI MATERIALI E COMPONENTI",player._cancel_fabrication.bind(job.id))
		cancel.set_meta("action_label",cancel.text)
		UI.action(cancel,"Annulla")
		cancel.tooltip_text="Restituisce materiali e componenti riservati."
	UI.action(button(player._panel_box,"SCEGLI PRODOTTI",player._open_crafting.bind("restored_radio")),"Catalogo")
	player._add_panel_button("TORNA AL LAVORO",player._close_pause_menu)
	player._pause_menu.popup_centered(Vector2i(900,640))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(900,640))
