extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func open(player: Node, workbench: bool, selection: String="") -> void:
	if not selection.is_empty(): player._component_selection=selection
	player._close_pause_menu()
	player._open_panel("BANCO / RECUPERO" if workbench else "MAGAZZINO / COMPONENTI")
	var groups: Dictionary={}
	for item in GameState.operations.stored_parts:
		var key: String=item.kind+str(item.quality)
		if not groups.has(key): groups[key]=[]
		groups[key].append(item)
	var chosen: String=player._component_selection
	if not groups.has(chosen): chosen=str(groups.keys()[0]) if not groups.is_empty() else ""
	player._component_selection=chosen
	var body=HBoxContainer.new()
	body.add_theme_constant_override("separation",18)
	player._panel_box.add_child(body)
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(290,330)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	for key in groups:
		var item: Dictionary=groups[key][0]
		var button=UI.tile(grid,item.kind,GameState.part_defs[item.kind].name,open.bind(player,workbench,key),key==chosen,true,"%d · %s" % [groups[key].size(),"✓" if item.quality==1 else "!"])
		button.tooltip_text=GameState.part_defs[item.kind].name+(" · funzionante" if item.quality==1 else " · da riparare")
	var detail_scroll=ScrollContainer.new()
	detail_scroll.custom_minimum_size=Vector2(350,330)
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)
	var side=UI.column(detail_scroll,330)
	if chosen.is_empty():
		UI.picture(side,"box",Vector2(290,160))
		side.add_child(ART.label("NESSUN COMPONENTE",21,UI.MUTED))
		var hint=ART.label("Smonta con R → recupero intero.\nPoi porta il pezzo al magazzino.",16,UI.PAPER)
		hint.custom_minimum_size.x=290
		hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		side.add_child(hint)
	else:
		var item: Dictionary=groups[chosen][0]
		var spec: Dictionary=GameState.part_defs[item.kind]
		UI.picture(side,item.kind,Vector2(290,105))
		side.add_child(ART.label(spec.name.to_upper(),21,UI.PAPER))
		side.add_child(ART.label("%d kg · %d Bulloni" % [spec.mass_kg,GameState.ops.part_value(item)],16,UI.ORANGE))
		side.add_child(ART.label("FUNZIONANTE" if item.quality==1 else "DA RIPARARE",14,UI.MUTED))
		if workbench:
			var ready: bool=GameState.yard_level>=1 and int(GameState.workshop_modules.get("workbench",0))>=1
			for id in spec.recycle:
				var line=HBoxContainer.new()
				side.add_child(line)
				UI.picture(line,id,Vector2(28,25))
				line.add_child(ART.label("×%d" % spec.recycle[id],14,UI.MUTED))
			_add(side,player,"Ripara","repair",item.id,ready and item.quality==0 and GameState.team_deposit_counts.metal>=2 and GameState.team_deposit_counts.electronics>=1).tooltip_text="Ripara · 2 Metallo + 1 Elettronica · Banco L1"
			_add(side,player,"Ricicla","recycle",item.id,ready)
		else:
			_add(side,player,"Vendi","sell",item.id,player._near_depot()).tooltip_text="Vendi · solo alla bilancia"
		_add(side,player,"Preleva","take",item.id,GameState.operations.held.is_empty())
	if player._buggy_at_storage():
		_add(player._panel_box,player,"Scarica cassone","unload","",GameState.ops.cargo_mass()>0).set_meta("action_label","SCARICA IL CASSONE QUI")
	if player._near_ops_service()=="warehouse":
		_add(player._panel_box,player,"Deposita sacca","store_bag","",GameState.get_inventory_mass(1)>0)
	player._pause_menu.popup_centered(Vector2i(760,560))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(760,560))

static func _add(parent: Node, player: Node, label: String, action: String, id: String, enabled: bool) -> Button:
	var button=Button.new()
	button.disabled=not enabled
	button.pressed.connect(player._ops_action.bind(action,id,0))
	UI.action(button,label,action in ["repair","sell"] and enabled)
	parent.add_child(button)
	return button
