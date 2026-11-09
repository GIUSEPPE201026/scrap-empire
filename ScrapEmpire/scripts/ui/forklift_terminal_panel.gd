extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")
const CRAFT=preload("res://scripts/ui/crafting_panel.gd")
const SERVICE=preload("res://scripts/gameplay/forklift_terminal.gd")

static func open(player: Node, machine: Node) -> void:
	if not is_instance_valid(machine.carried):
		player._notify(Localization.text("Aggancia un pallet con G prima di aprire il terminale"))
		return
	player._close_pause_menu()
	player._open_panel("MULETTO / PALLET")
	var location=ART.label("",16,UI.ORANGE)
	location.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	player._panel_box.add_child(location)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	player._panel_box.add_child(row)
	var values=metric(row,"bale_pallet","PALLET")
	var warehouse=metric(row,"warehouse","DEPOSITO")
	var revenue=metric(row,"coin","RICAVO")
	var status=ART.label("",15,UI.MUTED)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size=Vector2(560,44)
	var actions=HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	player._panel_box.add_child(actions)
	var state: Dictionary={"values":values,"warehouse":warehouse,"revenue":revenue,"location":location,"status":status,"buttons":{},"count":0,"ticket":0}
	for item in [["load","CARICA BALLE","press"],["return","RESTITUISCI","warehouse"],["ship","SPEDISCI","truck"]]:
		var control=CRAFT.button(actions,item[1],perform.bind(player,machine,item[0],state),true,item[0]=="load")
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.y=56
		control.icon=ART.SYMBOLS.icon(item[2])
		state.buttons[item[0]]=control
	player._panel_box.add_child(status)
	player._add_panel_button("TORNA ALLA GUIDA",player._close_pause_menu)
	refresh(player,machine,state)
	player._pause_menu.popup_centered(Vector2i(650,410))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(650,410))

static func metric(parent: Node, icon: String, title: String) -> Label:
	var panel=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",UI.style(UI.SURFACE))
	parent.add_child(panel)
	var column=VBoxContainer.new()
	column.custom_minimum_size=Vector2(140,115)
	column.alignment=BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var symbol=TextureRect.new()
	symbol.texture=ART.SYMBOLS.icon(icon)
	symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.custom_minimum_size=Vector2(32,32)
	symbol.modulate=UI.ORANGE
	column.add_child(symbol)
	var caption=ART.label(title,12,UI.MUTED)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var value=ART.label("",25,UI.PAPER)
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	return value

static func refresh(player: Node, machine: Node, controls: Dictionary) -> void:
	var count: int=int(GameState.crafting.data().objects.get(machine.carried.craft_id,{}).get("bales",0))
	var place: String=SERVICE.station(machine,player)
	controls.count=count
	controls.ticket=int(GameState.operations.serial)
	controls.values.text="%d / %d" % [count,GameState.logistics_def.crafting.bale_pallet.capacity_bales]
	controls.warehouse.text=str(GameState.press_bales)
	controls.revenue.text=str(count*GameState.get_bale_value())
	controls.location.text={"warehouse":"DEPOSITO COLLEGATO","dispatch":"BANCHINA COLLEGATA","":"AVVICINA IL PALLET AL DEPOSITO O ALLA BANCHINA"}[place]
	controls.buttons.load.disabled=place!="warehouse" or GameState.press_bales<=0 or count>=int(GameState.logistics_def.crafting.bale_pallet.capacity_bales)
	controls.buttons["return"].disabled=place!="warehouse" or count<=0
	controls.buttons.ship.disabled=place!="dispatch" or count<=0
	controls.buttons.load.visible=place=="warehouse"
	controls.buttons["return"].visible=place=="warehouse"
	controls.buttons.ship.visible=place=="dispatch"
	controls.buttons.ship.text=Localization.text("SPEDISCI  +%d BULLONI") % (count*GameState.get_bale_value())
	for action in controls.buttons:
		ART.button_style(controls.buttons[action],not controls.buttons[action].disabled and action==("ship" if place=="dispatch" else "load"))
	controls.status.text={"warehouse":"Carica dalla pressa e porta il pallet alla banchina.","dispatch":"Vendi le balle. Il pallet resta sulle forche.","":"Avvicinati al deposito per caricare o alla banchina per vendere."}[place]

static func perform(player: Node, machine: Node, action: String, controls: Dictionary) -> void:
	var success: bool=SERVICE.execute(machine,player,action,int(controls.count),int(controls.ticket))
	refresh(player,machine,controls)
	controls.status.text=({"load":"Balle caricate. Pallet pronto al trasporto.","return":"Balle restituite al deposito.","ship":"Spedizione salvata. Incasso ricevuto; pallet riutilizzabile."}[action] if success else "Operazione annullata: controlla spazio sopra il pallet, posizione e salvataggio.")
