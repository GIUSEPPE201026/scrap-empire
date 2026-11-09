extends RefCounted
const ART = preload("res://scripts/ui/menu_art.gd")
const UI = preload("res://scripts/ui/yard_panels.gd")

static func open(player: Node, page: String = "story") -> void:
	player._close_pause_menu()
	player._open_panel("DIARIO / RIVA SECCA")
	player._panel_box.set_meta("text_width",880)
	player._panel_box.add_theme_constant_override("separation",10)
	var tabs = HBoxContainer.new()
	player._panel_box.add_child(tabs)
	for tab in [["story","Obiettivo"],["projects","Progetti"],["map","Mappa"]]:
		preload("res://scripts/ui/crafting_panel.gd").button(tabs,tab[1],player._open_career.bind(tab[0]),true,page==tab[0])
	if page=="map":
		map_content(player)
	elif page=="projects":
		projects(player)
	else:
		story(player)
	player._add_panel_button("TORNA AL LAVORO",player._close_pause_menu)
	var dimensions = Vector2i(mini(1040,player.get_window().size.x-32),mini(730,player.get_window().size.y-32))
	player._pause_menu.popup_centered(dimensions)
	player.call_deferred("_center_popup_if_open",player._pause_menu,dimensions)

static func story(player: Node) -> void:
	var service = GameState.story
	var rows = UI._scroll(player._panel_box,minf(380,player.get_window().size.y-350))
	rows.set_meta("text_width",880)
	var chapter: Dictionary = service.chapter()
	var step: Dictionary = service.next_step()
	UI._text(rows,step.title,28,Color("#edbc60"))
	UI._text(rows,step.detail,18)
	var order: Dictionary = GameState.current_order()
	if not order.is_empty():
		for material in order.materials:
			ART.ingredient(rows,UI._material_name(material),GameState.team_deposit_counts.get(material,0),order.materials[material])
		if int(order.bales)>0:
			UI._text(rows,Localization.format_text("Balle pronte: %d / %d", [GameState.press_bales,order.bales]),17)
	UI._text(rows,chapter.title,20,Color("#83c4ac"))
	ART.details(rows,chapter.letter+"\n\n"+chapter.unlock,Localization.text("Lettera · ")+chapter.sender)
	ART.details(rows,service.definition().epilogue if service.complete() else service.definition().intro,"Riva Secca")
	ART.details(rows,"COME SI RIPARTE\n1. Tieni premuto il comando di raccolta sul pezzo con l'attrezzo adatto.\n2. Alla bilancia deposita: conserva le scorte per le ricette e le commesse. Vendi gli avanzi per finanziare gli acquisti.\n3. Al monitor dell'ufficio consegna le commesse; garage per costruire e acquistare i mezzi.")
	var actions = HBoxContainer.new()
	player._panel_box.add_child(actions)
	preload("res://scripts/ui/crafting_panel.gd").button(actions,"SEGUI IL PROSSIMO PASSO",player._track_career,true,true)
	preload("res://scripts/ui/crafting_panel.gd").button(actions,"ALBUM DELLE CURIOSITÀ",player._open_journal)

static func projects(player: Node) -> void:
	preload("res://scripts/ui/projects_panel.gd").build(player)

static func map_content(player: Node) -> void:
	var layout = HBoxContainer.new()
	layout.add_theme_constant_override("separation",20)
	player._panel_box.add_child(layout)
	var atlas = Control.new()
	atlas.name="YardAtlas"
	atlas.set_script(preload("res://scripts/ui/yard_atlas.gd"))
	if not player._career_map_wide:
		atlas.bounds = Rect2(Vector2(-50,-15),Vector2(95,65))
	atlas.custom_minimum_size = Vector2(500,minf(480,player.get_window().size.y-330))
	atlas.player = player
	atlas.locations = preload("res://scripts/gameplay/yard_navigation.gd").points(player)
	atlas.chosen = player._route_career_map
	layout.add_child(atlas)
	var side = VBoxContainer.new()
	side.custom_minimum_size.x = 330
	layout.add_child(side)
	preload("res://scripts/ui/crafting_panel.gd").button(side,"MOSTRA IL CENTRO" if player._career_map_wide else "MOSTRA IL MONDO",player._toggle_career_map)
	var clear=Button.new()
	clear.disabled=player._navigation_label.is_empty()
	clear.pressed.connect(player._clear_navigation)
	preload("res://scripts/ui/salvage_ui.gd").action(clear,"Rimuovi meta")
	side.add_child(clear)
	player._pause_menu.set_meta("clear_waypoint",clear)
	var scroll = UI._scroll(side,minf(400,player.get_window().size.y-430))
	scroll.get_parent().custom_minimum_size.x = 330
	scroll.set_meta("text_width",300)
	for id in ["depot","tools","craft","warehouse","press","vehicles","land","customer_marta","customer_enzo","recovery","dispatch","career","lot1","lot2","oasis","dune_park","crash","cave","anomaly","north_cache","east_cache","west_cache"]:
		if not atlas.locations.has(id):
			continue
		if id in ["customer","salvage"]:
			continue
		var place: Dictionary = atlas.locations[id]
		var text: String = place.name+(" · CHIUSO" if place.get("locked",false) else "")
		preload("res://scripts/ui/crafting_panel.gd").button(scroll,text,player._route_career_map.bind(id))
	ART.details(side,"Scegli un servizio o un punto sulla mappa per seguirlo.","Navigazione")
