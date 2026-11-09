extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func open(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("ATTREZZATURA PERSONALE")
	player._panel_box.add_theme_constant_override("separation",12)
	var layout=HBoxContainer.new()
	layout.add_theme_constant_override("separation",20)
	player._panel_box.add_child(layout)
	var left=VBoxContainer.new()
	layout.add_child(left)
	var grid=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	left.add_child(grid)
	var side=VBoxContainer.new()
	side.custom_minimum_size.x=285
	side.add_theme_constant_override("separation",10)
	layout.add_child(side)
	var selected: int=player._active_tool()
	var riding: bool=is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.level==1
	var photo=UI.hero(side,player._mounted_vehicle.vehicle_kind if riding else ["hands","screwdriver","hammer","crowbar","bolt_cutters"][selected],Vector2(270,190))
	photo.name="EquipmentPreview"
	var title=ART.label(player._mounted_vehicle.motion_definition().name.to_upper() if riding else GameState.tool_defs[selected].name.to_upper(),23,UI.PAPER)
	side.add_child(title)
	var role=ART.label("Equipaggia e parti. Spazio per saltare." if riding else GameState.tool_defs[selected].role,15,UI.MUTED)
	role.custom_minimum_size.x=270
	role.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	side.add_child(role)
	var status=ART.label("IN USO",13,UI.ORANGE)
	side.add_child(status)
	for index in 5:
		var definition: Dictionary=GameState.tool_defs[index]
		var owned: bool=GameState.owns_tool(index)
		var current: bool=index==selected and (not is_instance_valid(player._mounted_vehicle) or player._mounted_vehicle.level!=1)
		var key: String=["hands","screwdriver","hammer","crowbar","bolt_cutters"][index]
		var requirement: String="PRONTO" if owned else ("BANCO DEL GARAGE" if index>=3 else "MONITOR UFFICIO")
		var preview=func():
			photo.texture=UI.image(key)
			title.text=definition.name.to_upper()
			role.text=definition.role
			status.text="IN USO" if current else requirement
		var activate=func():
			preview.call()
			if owned and not current: player._equip_tool(index)
		var tile=UI.tile(grid,key,definition.name+" · "+definition.role,activate,current,owned,str(definition.key) if player._shortcut_free(KEY_1+int(definition.key)-1) else "—")
		tile.set_meta("tool_slot",index)
		tile.set_meta("action_label","EQUIPAGGIA" if owned and not current else "ISPEZIONA")
		tile.disabled=false # Locked objects remain inspectable; activate never grants equipment.
		tile.mouse_entered.connect(preview)
		tile.focus_entered.connect(preview)
	var scooter=UI.tile(grid,"scooter","Monopattino",player._choose_portable.bind("scooter"),riding and player._mounted_vehicle.vehicle_kind=="scooter",GameState.vehicle_level>0,"4" if player._shortcut_free(KEY_4) else "—")
	scooter.set_meta("action_label","Monopattino · bloccato" if GameState.vehicle_level==0 else "Monopattino [4]")
	scooter.mouse_entered.connect(func():
		photo.texture=UI.image("scooter")
		title.text="MONOPATTINO"
		role.text="Equipaggia e parti. Spazio per saltare."
		status.text="PRONTO" if GameState.vehicle_level>0 else "GARAGE · DA ACQUISTARE"
	)
	scooter.disabled=GameState.vehicle_level==0 or (is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.level!=1)
	if preload("res://scripts/economy/extra_mobility.gd").owned("skateboard"):
		var board=Button.new()
		board.icon=ART.SYMBOLS.icon("skateboard")
		board.pressed.connect(player._choose_portable.bind("skateboard"))
		board.disabled=is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.level!=1
		UI.action(board,"Skateboard · equipaggia",riding and player._mounted_vehicle.vehicle_kind=="skateboard")
		left.add_child(board)
	var bag=HBoxContainer.new()
	bag.add_theme_constant_override("separation",12)
	left.add_child(bag)
	UI.picture(bag,"bag",Vector2(46,46))
	var weight=VBoxContainer.new()
	weight.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bag.add_child(weight)
	weight.add_child(ART.label("%.1f / %d kg" % [player.get_inventory_mass(),GameState.get_inventory_capacity(1)],19,UI.PAPER))
	var meter=ProgressBar.new()
	meter.value=100.0*player.get_inventory_mass()/GameState.get_inventory_capacity(1)
	meter.custom_minimum_size.y=6
	meter.show_percentage=false
	weight.add_child(meter)
	var utilities=HBoxContainer.new()
	var vacuum=Button.new()
	vacuum.icon=ART.SYMBOLS.icon("vacuum")
	UI.action(vacuum,"Aspiratore",player._vacuum_active)
	vacuum.disabled=int(GameState.workshop_modules.get("vacuum",0))<1 or is_instance_valid(player._mounted_vehicle)
	vacuum.tooltip_text="Acquista al monitor officina. Scarti leggeri nella sacca."
	vacuum.pressed.connect(player._toggle_vacuum)
	utilities.add_child(vacuum)
	utilities.add_theme_constant_override("separation",8)
	player._panel_box.add_child(utilities)
	var entries: Array=[["Scanner [F]" if player._shortcut_free(KEY_F) else "Scanner","scan",player._scan_scrap,int(GameState.workshop_modules.get("scanner",0))>0],["Luce [L]" if player._shortcut_free(KEY_L) else "Luce","light",player._toggle_work_light,int(GameState.workshop_modules.get("headlamp",0))>0 or (is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.level==2)],["Collezione [B]" if player._shortcut_free(KEY_B) else "Collezione","book",player._open_scrap_book,true],["Costruzioni","craft",player._open_crafted_gear,true]]
	if is_instance_valid(player._mounted_vehicle) and player._mounted_vehicle.level==2:
		entries.append_array([["Parcheggio","wheel",player._toggle_parking_brake,true],["Visuale","eye",player._toggle_vehicle_view,true]])
	for entry in entries:
		var button=Button.new()
		button.text=entry[0]
		button.icon=ART.SYMBOLS.icon(entry[1])
		button.disabled=not entry[3]
		button.pressed.connect(entry[2])
		UI.action(button,entry[0])
		utilities.add_child(button)
	player._pause_menu.popup_centered(Vector2i(820,550))
