extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func action(parent: Node, text: String, player: Node, operation: String, count: int=0, enabled: bool=true) -> Button:
	var button=Button.new()
	button.disabled=not enabled
	button.pressed.connect(player._ops_action.bind(operation,"",count))
	UI.action(button,text,enabled and operation=="queue")
	parent.add_child(button)
	return button

static func purchase(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("PRESSA P-01 / PRODUZIONE")
	var body=HBoxContainer.new()
	body.add_theme_constant_override("separation",20)
	player._panel_box.add_child(body)
	UI.hero(body,"press_machine",Vector2(270,300))
	var detail=VBoxContainer.new()
	detail.custom_minimum_size.x=330
	detail.add_theme_constant_override("separation",14)
	body.add_child(detail)
	detail.add_child(ART.label("PRESSA P-01",26,UI.PAPER))
	detail.add_child(ART.label("%d metalli → 1 balla" % GameState.press_def.input_units,22,UI.ORANGE))
	var flow=HBoxContainer.new()
	detail.add_child(flow)
	UI.picture(flow,"metal",Vector2(76,76))
	flow.add_child(ART.label("→",24,UI.MUTED))
	UI.picture(flow,"bale",Vector2(92,76))
	detail.add_child(ART.label("%.0f s / lotto · %d Bulloni / balla" % [GameState.press_cycle_seconds(),GameState.get_bale_value()],15,UI.MUTED))
	player._station_status=Label.new()
	detail.add_child(player._station_status)
	player._station_status.hide()
	player._station_buy=Button.new()
	player._station_buy.set_meta("keep_label",true)
	player._station_buy.pressed.connect(player._purchase_press)
	UI.action(player._station_buy,"Acquista",true)
	detail.add_child(player._station_buy)
	player._press_start_button=Button.new()
	player._press_start_button.set_meta("keep_label",true)
	player._press_start_button.pressed.connect(player._begin_press)
	UI.action(player._press_start_button,"Avvia 1 lotto")
	detail.add_child(player._press_start_button)
	var manage=Button.new()
	manage.pressed.connect(player._open_production_queue)
	UI.action(manage,"Produzione")
	detail.add_child(manage)
	player._pause_menu.set_meta("press_manage",manage)
	player._refresh_press()
	player._pause_menu.popup_centered(Vector2i(720,470))

static func refresh(player: Node) -> void:
	if is_instance_valid(player._pause_menu) and player._pause_menu.has_meta("press_manage"):
		player._pause_menu.get_meta("press_manage").disabled=not GameState.press_owned

static func production(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("PRESSA / CODA DI PRODUZIONE")
	player._panel_box.add_theme_constant_override("separation",12)
	var top=HBoxContainer.new()
	top.add_theme_constant_override("separation",18)
	player._panel_box.add_child(top)
	UI.hero(top,"press_machine",Vector2(200,174))
	var recipe=VBoxContainer.new()
	recipe.custom_minimum_size.x=360
	recipe.add_theme_constant_override("separation",8)
	top.add_child(recipe)
	var flow=HBoxContainer.new()
	recipe.add_child(flow)
	UI.picture(flow,"metal",Vector2(65,65))
	flow.add_child(ART.label("×%d  →" % GameState.press_def.input_units,22,UI.PAPER))
	UI.picture(flow,"bale",Vector2(84,65))
	recipe.add_child(ART.label("1 balla · %d Bulloni" % GameState.get_bale_value(),22,UI.ORANGE))
	recipe.add_child(ART.label("%.0f s / lotto · metalli disponibili %d" % [GameState.press_cycle_seconds(),GameState.team_deposit_counts.metal],14,UI.MUTED))
	var state=ART.label("PRONTA" if GameState.press_remaining<=0 else "LOTTO ATTIVO · %.1f s" % GameState.press_remaining,15,UI.PAPER)
	recipe.add_child(state)
	var progress=ProgressBar.new()
	progress.value=100.0*(1.0-GameState.press_remaining/GameState.press_cycle_seconds()) if GameState.press_remaining>0 else 0
	progress.show_percentage=false
	progress.custom_minimum_size.y=8
	recipe.add_child(progress)
	player._panel_box.add_child(ART.label("IN CODA: %d     /     BALLE PRONTE: %d" % [GameState.operations.press_queue,GameState.press_bales],18,UI.PAPER))
	var queue=HBoxContainer.new()
	player._panel_box.add_child(queue)
	for index in mini(8,int(GameState.operations.press_queue)): UI.picture(queue,"bale",Vector2(45,34))
	if int(GameState.operations.press_queue)>8: queue.add_child(ART.label("+%d" % (int(GameState.operations.press_queue)-8),16,UI.MUTED))
	var available: int=mini(int(GameState.team_deposit_counts.metal)/int(GameState.press_def.input_units),int(GameState.logistics_def.max_press_queue)-int(GameState.operations.press_queue)-(1 if GameState.press_remaining>0 else 0))
	var actions=HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	player._panel_box.add_child(actions)
	for count in [1,5]:
		action(actions,"ACCODA %d %s" % [count,"LOTTO" if count==1 else "LOTTI"],player,"queue",count,GameState.press_owned and available>=count)
	action(actions,"MASSIMO · %d LOTTI" % maxi(0,available),player,"queue",maxi(0,available),GameState.press_owned and available>0)
	action(actions,"Annulla coda",player,"cancel_queue",0,int(GameState.operations.press_queue)>0).tooltip_text="ANNULLA I LOTTI IN ATTESA · RESTITUISCI I MATERIALI"
	var feed=CheckButton.new()
	feed.text="Spegni tramoggia" if GameState.operations.autofeed else "Attiva tramoggia"
	feed.set_pressed_no_signal(GameState.operations.autofeed)
	feed.disabled=not GameState.press_owned or GameState.yard_level<2 or int(GameState.workshop_modules.get("press_drive",0))<2
	feed.tooltip_text="ALIMENTAZIONE AUTOMATICA · Lotto dune + Idraulica L2 · usa i metalli del deposito"
	feed.pressed.connect(player._ops_action.bind("autofeed","",0))
	player._panel_box.add_child(feed)
	player._panel_box.add_child(ART.label("La lavorazione riprende chiudendo il menu.",13,UI.MUTED))
	player._pause_menu.popup_centered(Vector2i(720,520))
