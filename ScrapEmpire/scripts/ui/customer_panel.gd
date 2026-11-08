extends RefCounted
const ART = preload("res://scripts/ui/menu_art.gd")

static func open(player: Node, id: String) -> void:
	var craft = GameState.crafting
	var spec: Dictionary = craft.customer(id)
	if spec.is_empty():
		return
	player._close_pause_menu()
	player._open_panel("CLIENTI / PRODOTTI DAL RECUPERO")
	player._panel_box.set_meta("text_width",760)
	var ui = preload("res://scripts/ui/yard_panels.gd")
	ui._text(player._panel_box,spec.name,24,Color("#bba9ed"))
	ui._text(player._panel_box,craft.definitions()[spec.product].name,30)
	player._panel_metrics([["PRONTI",str(int(craft.data().stock.get(spec.product,0)))],["OGGI",str(craft.demand(id))],["PER PEZZO","%d Bulloni" % spec.price]])
	if GameState.completed_orders.size()<int(spec.orders):
		ui._text(player._panel_box,"Sblocco: %d commesse" % spec.orders,17,Color("#efc374"))
	elif craft.demand(id)==0:
		ui._text(player._panel_box,"Torna domani",18,Color("#bba9ed"))
	var recipe: Dictionary = craft.definitions()[spec.product]
	if float(recipe.get("seconds",0))>0:
		ui._text(player._panel_box,"In assemblaggio: %d" % GameState.fabrication.count(spec.product),17,Color("#83c4ac"))
	var ingredients: PackedStringArray = []
	for material in recipe.materials:
		ingredients.append("%s ×%d" % [ui._material_name(material),recipe.materials[material]])
	for part in recipe.parts:
		ingredients.append("%s funzionanti ×%d" % [GameState.part_defs[part].name,recipe.parts[part]])
	ART.details(player._panel_box,", ".join(ingredients),"Ingredienti")
	var delivery: Dictionary = GameState.ops.delivery_definition()
	if int(delivery.get("products",{}).get(spec.product,0))>0:
		ui._text(player._panel_box,"Riservati alla fornitura: %d" % int(delivery.products[spec.product]),16,Color("#edbc60"))
	preload("res://scripts/ui/crafting_panel.gd").button(player._panel_box,"CONSEGNA 1 · +%d BULLONI" % spec.price,player._sell_crafted_product.bind(id,int(GameState.operations.serial)),craft.demand(id)>0 and int(craft.data().stock.get(spec.product,0))>0,true)
	ART.details(player._panel_box,"Costruisci al banco del garage. Domanda rinnovata ogni giorno, prezzo fisso. Massimo %d pezzi al giorno." % craft.customer_limit(id),"Acquisti")
	player._add_panel_button("TORNA AL LAVORO",player._close_pause_menu)
	player._pause_menu.popup_centered(Vector2i(900,590))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(900,590))
