extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func close_button(monitor: Node, parent: Node) -> void:
	var button=Button.new()
	button.disabled=not monitor.active
	if monitor.active: button.pressed.connect(monitor.owner_player._close_pause_menu)
	UI.action(button,"Chiudi · Esc")
	parent.add_child(button)

static func stock_row(parent: Node, key: String, title: String, have: int, need: int) -> void:
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	parent.add_child(row)
	UI.picture(row,key,Vector2(46,42))
	var label=ART.label(title,16,UI.PAPER)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(ART.label("%d / %d" % [have,need],19,UI.PAPER if have>=need else UI.ORANGE))

static func tools(monitor: Node, column: VBoxContainer) -> void:
	var row=HBoxContainer.new()
	row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	for category in ["bag","tool","movement"]:
		var current: int=int(GameState.team_upgrade_levels[category])
		var cost: int=EconomyService.get_next_upgrade_cost(category)
		var next: Dictionary=GameState._find_upgrade(GameState._get_upgrade_defs(category),current+1)
		var card=UI.column(row,310)
		var image=UI.picture(card,"bag" if category=="bag" else ("screwdriver" if current==0 else "hammer"),Vector2(275,140))
		if category=="movement": image.texture=ART.equipment(2)
		var name_text: String={"bag":"Sacca","tool":"Cacciavite" if current==0 else ("Martello" if current==1 else "Attrezzi"),"movement":"Scarponi"}[category]
		card.add_child(ART.label(name_text.to_upper(),23,UI.PAPER))
		card.add_child(ART.label("L%d / %d" % [current,GameState._get_upgrade_defs(category).size()],13,UI.MUTED))
		var effect: String="Completo"
		if not next.is_empty():
			if category=="bag": effect="%d → %d kg" % [GameState.get_inventory_capacity(1),next.capacity_kg]
			elif category=="tool": effect="Elettronica / rame" if current==0 else "Vetro / telai"
			else: effect=Localization.text("Velocità +%.0f%%") % ((next.speed_multiplier-1)*100)
		card.add_child(ART.label(effect,20,UI.ORANGE))
		var purchase=Button.new()
		purchase.icon=ART.SYMBOLS.icon("coin")
		purchase.disabled=not monitor.active or cost<0 or GameState.team_credits<cost
		if monitor.active: purchase.pressed.connect(monitor.owner_player._buy_development.bind(category))
		UI.action(purchase,"Completo" if cost<0 else Localization.text("Acquista · %d") % cost,not purchase.disabled)
		card.add_child(purchase)
		monitor.buy_buttons[category]=purchase
		if category in ["bag","tool"]:
			var build=Button.new()
			build.disabled=not monitor.active
			if monitor.active: build.pressed.connect(monitor.owner_player._route_career_map.bind("craft"))
			UI.action(build,"Costruisci al banco" if category=="bag" else "Altri attrezzi")
			card.add_child(build)
	close_button(monitor,column)

static func orders(monitor: Node, column: VBoxContainer) -> void:
	var order: Dictionary=GameState.current_order()
	if order.is_empty():
		var scroll=ScrollContainer.new()
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size.y=350
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		column.add_child(scroll)
		var list=VBoxContainer.new()
		list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		monitor.buy_buttons.merge(preload("res://scripts/ui/yard_panels.gd").delivery_content(list,monitor.owner_player,monitor.active))
		close_button(monitor,column)
		return
	column.add_child(ART.label(Localization.format_text("AVVIAMENTO · %d / %d", [GameState.completed_orders.size()+1,GameState.order_defs.size()]),14,UI.MUTED))
	var body=HBoxContainer.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	column.add_child(body)
	var summary=UI.column(body,380)
	UI.picture(summary,"press_machine" if int(order.bales)>0 else "field_depot",Vector2(350,124))
	var title=ART.label(order.name.to_upper(),24,UI.PAPER)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(title)
	summary.add_child(ART.label(Localization.text("+%d Bulloni") % order.reward,25,UI.ORANGE))
	var requirement=ART.label(GameState.order_requirement(),16,UI.MUTED)
	requirement.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(requirement)
	summary.tooltip_text=order.description
	var stock=UI.column(body,500)
	stock.add_child(ART.label("DEPOSITO / RICHIESTI",13,UI.MUTED))
	for id in order.materials:
		stock_row(stock,id,preload("res://scripts/ui/yard_panels.gd")._material_name(id),int(GameState.team_deposit_counts.get(id,0)),int(order.materials[id]))
	if int(order.bales)>0: stock_row(stock,"bale","Balle",GameState.press_bales,int(order.bales))
	var complete=Button.new()
	complete.disabled=not monitor.active or not GameState.can_complete_order()
	if monitor.active: complete.pressed.connect(monitor.owner_player._complete_work_order.bind(order.id))
	UI.action(complete,"Consegna e incassa" if GameState.can_complete_order() else "Completa i requisiti",not complete.disabled)
	stock.add_child(complete)
	monitor.buy_buttons["order"]=complete
	stock.add_child(ART.label("La consegna usa il deposito. La sacca resta tua.",13,UI.MUTED))
	close_button(monitor,column)

static func career(monitor: Node, column: VBoxContainer) -> void:
	var chapter: Dictionary=GameState.story.chapter()
	var step: Dictionary=GameState.story.next_step()
	var body=HBoxContainer.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	column.add_child(body)
	var intro=UI.column(body,350)
	UI.picture(intro,"field_depot",Vector2(310,190))
	var chapter_title=ART.label(chapter.title.to_upper(),24,UI.PAPER)
	chapter_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(chapter_title)
	intro.add_child(ART.label("RIVA SECCA",13,UI.ORANGE))
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(580,340)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var task=VBoxContainer.new()
	task.custom_minimum_size.x=560
	task.add_theme_constant_override("separation",16)
	scroll.add_child(task)
	task.add_child(ART.label("PROSSIMO PASSO",13,UI.MUTED))
	var title=ART.label(step.title,27,UI.ORANGE)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	task.add_child(title)
	var note=ART.label(step.detail,18,UI.PAPER)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	task.add_child(note)
	ART.details(task,chapter.letter,Localization.text("Lettera · ")+chapter.sender)
	var open=Button.new()
	open.disabled=not monitor.active
	if monitor.active: open.pressed.connect(monitor.owner_player._open_career)
	UI.action(open,"Apri diario",true)
	column.add_child(open)
	close_button(monitor,column)
