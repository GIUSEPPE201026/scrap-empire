extends RefCounted
const ART = preload("res://scripts/ui/menu_art.gd")
const UI = preload("res://scripts/ui/salvage_ui.gd")

static func build(column: VBoxContainer, player: Node, active: bool) -> void:
	column.add_child(ART.label("Scegli i pezzi · deposita · consegna",14,UI.MUTED))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 320
	column.add_child(scroll)
	var rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",12)
	scroll.add_child(rows)
	var service = GameState.specifics
	var request: Dictionary = service.payload()
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	for job in GameState.logistics_def.specific_orders:
		var panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel",UI.style())
		rows.add_child(panel)
		var box = VBoxContainer.new()
		panel.add_child(box)
		var heading=HBoxContainer.new()
		box.add_child(heading)
		var title=ART.label(job.name,21,UI.PAPER)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		heading.add_child(title)
		heading.add_child(ART.label("+%d Bulloni" % job.reward,21,UI.ORANGE))
		var selected: bool = request.get("id","")==job.id
		var items=HBoxContainer.new()
		items.add_theme_constant_override("separation",16)
		box.add_child(items)
		for key in job.items:
			var item=HBoxContainer.new()
			item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			items.add_child(item)
			UI.picture(item,"variant_"+key,Vector2(72,62))
			var details=VBoxContainer.new()
			item.add_child(details)
			var text: String = catalog.item_name(key.get_slice("_",0).to_int(),key.get_slice("_",1).to_int())+" ×%d" % job.items[key]
			details.add_child(ART.label(text,16,UI.PAPER))
			if selected:
				details.add_child(ART.label("Sacca %d · Cassone %d · Deposito %d" % [request.bag.get(key,0),request.cargo.get(key,0),request.stock.get(key,0)],12,UI.MUTED))
		var button = Button.new()
		box.add_child(button)
		if job.id in GameState.operations.get("specific_completed",[]):
			button.text = "CONSEGNATA"
			button.disabled = true
		elif selected:
			button.text = "CONSEGNA · %d Bulloni" % job.reward
			button.disabled = not active or not service.ready()
			if is_instance_valid(player):
				button.pressed.connect(player._specific_action.bind("deliver",str(request.ticket)))
			var cancel = Button.new()
			cancel.text = "Annulla richiesta"
			cancel.tooltip_text = "I pezzi diventano materiali nelle rispettive scorte."
			cancel.disabled = not active
			if is_instance_valid(player):
				cancel.pressed.connect(player._specific_action.bind("cancel",""))
			UI.action(cancel,cancel.text)
			box.add_child(cancel)
		else:
			var unlocked: bool = GameState.completed_orders.size()>=int(job.orders) and GameState.yard_level>=int(job.land)
			button.text = "Accetta" if unlocked else "%d commesse" % job.orders + (" · Lotto %d" % job.land if int(job.land)>0 else "")
			button.disabled = not active or not unlocked or not request.is_empty()
			if is_instance_valid(player):
				button.pressed.connect(player._specific_action.bind("accept",job.id))
		UI.action(button,button.text,not button.disabled)
	var exit_button = Button.new()
	exit_button.text = "TORNA AL LAVORO"
	if is_instance_valid(player):
		exit_button.pressed.connect(player._close_pause_menu)
	else:
		exit_button.disabled = true
	UI.action(exit_button,"Chiudi · Esc")
	column.add_child(exit_button)
