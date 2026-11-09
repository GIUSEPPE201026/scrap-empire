extends Node3D
var stock: Node3D
var caption: Label3D
var _visual_signature: String = ""

func _ready() -> void:
	name = "StockWarehouse"
	position = Vector3(-34,0,23)
	var service = Marker3D.new()
	service.position = Vector3(0,0,-3.4)
	service.set_meta("operation","warehouse")
	service.add_to_group("operations_service")
	add_child(service)
	GameState.deposit_changed.connect(_deposit_changed)
	GameState.operations_changed.connect(refresh)
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.box(self,Vector3(7,0.04,6.5),Vector3(0,0.025,0),Color("#948d75"))
	for side in [-1,1]:
		for z in [-2.8,2.8]:
			art.box(self,Vector3(0.12,3.4,0.12),Vector3(side*3.2,1.7,z),art.STEEL)
	art.beveled_box(self,Vector3(7.2,0.16,6.5),Vector3(0,3.5,0),art.MINT.darkened(0.2))
	art.box(self,Vector3(6.5,2.5,0.1),Vector3(0,1.3,2.9),art.GRAPHITE)
	var sign = art.sign_text(self,"MAGAZZINO RECUPERO",Vector3(0,3.0,-3.3),48)
	sign.rotation.y = PI
	sign.pixel_size = 0.004
	caption = art.sign_text(self,"",Vector3(0,2.6,-3.31),30)
	caption.rotation.y = PI
	caption.pixel_size = 0.0035
	stock = Node3D.new()
	add_child(stock)
	refresh()

func _deposit_changed(_credits: int, _counts: Dictionary) -> void:
	refresh()

func refresh() -> void:
	if stock == null:
		return
	var next_signature: String = JSON.stringify([GameState.team_deposit_counts,GameState.press_bales,GameState.operations.stored_parts,GameState.specifics.payload().get("stock",{})])
	if next_signature==_visual_signature:
		return
	_visual_signature = next_signature
	for child in stock.get_children():
		stock.remove_child(child)
		child.queue_free()
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var counts: Dictionary = GameState.team_deposit_counts
	var totals: Array = [int(counts.metal)+int(counts.copper)+int(counts.aluminum),int(counts.plastic)+int(counts.rubber),int(counts.electronics)+int(counts.glass)]
	for column in 3:
		art.beveled_box(stock,Vector3(1.8,0.14,1.4),Vector3(-2.1+column*2.1,0.12,0.6),Color("#8a7153"))
		for layer in mini(5,ceili(float(totals[column])/5.0)):
			art.beveled_box(stock,Vector3(1.5,0.24,1.1),Vector3(-2.1+column*2.1,0.34+layer*0.27,0.6),[art.STEEL,art.MINT,art.YELLOW][column])
	for index in mini(6,GameState.press_bales):
		art.beveled_box(stock,Vector3(0.65,0.45,0.55),Vector3(-2.3+(index%3)*0.75,0.3+(index/3)*0.5,-1.5),art.MINT)
	for index in mini(4,GameState.operations.stored_parts.size()):
		var item: Dictionary = GameState.operations.stored_parts[index]
		var model = Node3D.new()
		model.position = Vector3(0.3+(index%2)*1.3,0.1,-1.7+(index/2)*1.0)
		model.scale = Vector3.ONE*0.65
		stock.add_child(model)
		preload("res://scripts/gameplay/haul_part.gd").build_model(model,item.kind,int(item.quality))
	caption.text = "METALLI %d · POLIMERI %d · COMPONENTI %d · BALLE %d" % [totals[0],totals[1],GameState.operations.stored_parts.size(),GameState.press_bales]
	if GameState.specifics.units("stock")>0:
		art.beveled_box(stock,Vector3(1.6,0.55,1.0),Vector3(-2.1,0.35,2.1),art.YELLOW)
		for i in 4:
			art.box(stock,Vector3(0.025,0.56,1.02),Vector3(-2.7+i*0.4,0.35,2.1),art.GRAPHITE)
		var label = art.sign_text(stock,Localization.text("PEZZI SU RICHIESTA · %d") % GameState.specifics.units("stock"),Vector3(-2.1,0.8,2.1),26,true)
		label.pixel_size = 0.003
		var shown: int = 0
		for key in GameState.specifics.payload().stock:
			for unit in int(GameState.specifics.payload().stock[key]):
				if shown>=4:
					break
				var model = Node3D.new()
				stock.add_child(model)
				model.position = Vector3(-2.5+(shown%2)*0.65,0.65,1.85+(shown/2)*0.4)
				model.scale = Vector3.ONE*0.45
				preload("res://scripts/gameplay/scrap_catalog.gd").build(model,key.get_slice("_",0).to_int(),key.get_slice("_",1).to_int(),art)
				shown += 1
	# Completed work becomes a physical equipment rack in the warehouse.
	if GameState.completed_orders.size() >= 3:
		art.beveled_box(stock,Vector3(1.4,1.1,0.55),Vector3(2.3,0.6,2.1),art.YELLOW)
		for drawer in 4:
			art.box(stock,Vector3(1.25,0.03,0.03),Vector3(2.3,0.25+drawer*0.24,1.8),art.GRAPHITE)
