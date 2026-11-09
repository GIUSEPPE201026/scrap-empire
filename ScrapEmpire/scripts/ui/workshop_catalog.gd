extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")
const PANELS=preload("res://scripts/ui/yard_panels.gd")
const CRAFT=preload("res://scripts/ui/crafting_panel.gd")

static func open(player: Node, selection: String) -> void:
	player._close_pause_menu()
	player._open_panel("GARAGE / BANCO COSTRUZIONE")
	player._panel_box.add_theme_constant_override("separation",12)
	var recipes: Dictionary=GameState.crafting.definitions()
	var recipe: Dictionary=recipes[selection]
	var section: String=CRAFT.category(selection,recipes)
	var layout=HBoxContainer.new()
	layout.add_theme_constant_override("separation",16)
	player._panel_box.add_child(layout)
	var categories=VBoxContainer.new()
	categories.custom_minimum_size.x=144
	categories.add_theme_constant_override("separation",8)
	layout.add_child(categories)
	categories.add_child(ART.label("BANCO / 01",12,UI.MUTED))
	for tab in [["equipment","Costruzioni","handcart","box"],["tools","Attrezzi","crowbar","craft"],["upgrades","Upgrade","bag_frame","suspension"],["products","Prodotti","desk_lamp","radio"]]:
		var button=Button.new()
		button.icon=ART.SYMBOLS.icon(tab[3])
		button.pressed.connect(player._open_crafting.bind(tab[2]))
		UI.action(button,tab[1],section==tab[0])
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		categories.add_child(button)
	var queue=Button.new()
	queue.icon=ART.SYMBOLS.icon("clock")
	queue.pressed.connect(player._open_fabrication_queue)
	UI.action(queue,Localization.text("Coda · %d") % GameState.fabrication.jobs().size())
	categories.add_child(queue)
	var gear=Button.new()
	gear.icon=ART.SYMBOLS.icon("bag")
	gear.pressed.connect(player._open_crafted_gear)
	UI.action(gear,"Pronti")
	categories.add_child(gear)
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(282,390)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var grid=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	for kind in recipes:
		if CRAFT.category(kind,recipes)!=section: continue
		var tile=UI.tile(grid,kind,recipes[kind].name,player._open_crafting.bind(kind),kind==selection,true,"×%d" % GameState.crafting.data().stock.get(kind,0))
		tile.custom_minimum_size=Vector2(132,138)
	var detail_scroll=ScrollContainer.new()
	detail_scroll.custom_minimum_size=Vector2(352,390)
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(detail_scroll)
	var detail=VBoxContainer.new()
	detail.custom_minimum_size.x=332
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",8)
	detail_scroll.add_child(detail)
	var hero=UI.hero(detail,selection,Vector2(314,122))
	hero.tooltip_text=recipe.description
	var title=ART.label(recipe.name.to_upper(),21,UI.PAPER)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(title)
	for customer in GameState.logistics_def.customers:
		if customer.product!=selection: continue
		var buyer=HBoxContainer.new()
		buyer.add_theme_constant_override("separation",8)
		detail.add_child(buyer)
		var price=ART.label(customer.name.get_slice(" · ",0)+Localization.text(" · %d Bulloni") % customer.price,14,UI.ORANGE)
		price.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		buyer.add_child(price)
		var route=Button.new()
		route.icon=ART.SYMBOLS.icon("route")
		route.pressed.connect(player._route_career_map.bind("customer_"+customer.id))
		UI.action(route,"Cliente")
		route.tooltip_text="Indica "+customer.name.get_slice(" · ",0)+" sulla mappa"
		buyer.add_child(route)
	for material in recipe.materials:
		ART.ingredient(detail,PANELS._material_name(material),GameState.team_deposit_counts[material],recipe.materials[material])
	for part in recipe.parts:
		ART.ingredient(detail,GameState.part_defs[part].name,GameState.ops.usable_parts(part),recipe.parts[part],true)
	if float(recipe.get("seconds",0))>0:
		detail.add_child(ART.label(Localization.text("%.0f s · assemblaggio") % GameState.fabrication.duration(selection),14,UI.MUTED))
	var requirement: Dictionary=GameState.crafting.next_requirement(selection)
	if not GameState.crafting.can_craft(selection):
		var note=ART.label(requirement.get("title","Requisiti mancanti"),14,UI.ORANGE)
		note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(note)
	if selection=="repair_kit":
		for item in GameState.operations.stored_parts:
			if int(item.quality)!=0: continue
			CRAFT.button(detail,"RIPARA "+GameState.part_defs[item.kind].name,player._craft_action.bind("repair",item.id,0),int(GameState.crafting.data().stock.get("repair_kit",0))>0)
	var actions=HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	player._panel_box.add_child(actions)
	var build=CRAFT.button(actions,"METTI IN ASSEMBLAGGIO" if float(recipe.get("seconds",0))>0 else "COSTRUISCI · USA LE SCORTE",player._craft_action.bind("craft",selection,int(GameState.operations.serial)),GameState.crafting.can_craft(selection),true)
	UI.action(build,"Assembla" if float(recipe.get("seconds",0))>0 else "Costruisci",true)
	build.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var locate=CRAFT.button(actions,"TROVA REQUISITI",player._locate_recipe_requirement.bind(selection))
	UI.action(locate,"Trova risorse")
	locate.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if recipe.has("install"):
		var install=CRAFT.button(actions,"Installa",player._craft_action.bind("install",selection,int(GameState.operations.serial)),GameState.crafting.install_requirement(selection).is_empty())
		UI.action(install,"Installa")
		install.tooltip_text=GameState.crafting.install_requirement(selection)
	player._pause_menu.popup_centered(Vector2i(900,570))
