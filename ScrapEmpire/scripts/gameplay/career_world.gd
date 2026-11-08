extends Node3D
var signature: String = ""
var decorations: Node3D

func _ready() -> void:
	GameState.story.data()
	var station = StaticBody3D.new()
	station.position = preload("res://scripts/gameplay/yard_navigation.gd").CAREER
	station.set_meta("operation","career")
	station.add_to_group("operations_service")
	add_child(station)
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(2.6,2,0.18)
	shape.position.y = 1.1
	station.add_child(shape)
	if DisplayServer.get_name()!="headless":
		var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
		art.beveled_box(station,Vector3(2.6,1.7,0.18),Vector3(0,1.3,0),art.GRAPHITE)
		for side in [-1,1]:
			art.box(station,Vector3(0.09,1.2,0.09),Vector3(side*1.05,0.6,0),art.STEEL)
		var label = art.sign_text(station,"RIVA SECCA\nLE TRE PROMESSE\n[J] DIARIO · MAPPA",Vector3(0,1.55,-0.12),28)
		label.rotation.y = PI
		label.pixel_size = 0.0025
	decorations = Node3D.new()
	add_child(decorations)
	GameState.operations_changed.connect(refresh)
	GameState.credits_changed.connect(_credits)
	refresh()

func _credits(_amount: int) -> void:
	refresh()

func refresh() -> void:
	var next: String = str(GameState.completed_orders.size())+JSON.stringify(GameState.story.data().claimed)
	if signature==next:
		return
	signature = next
	for child in decorations.get_children():
		decorations.remove_child(child)
		child.queue_free()
	if DisplayServer.get_name()=="headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var achieved: Array = GameState.story.data().claimed
	for index in 3:
		var color: Color = art.MINT if GameState.story.definition().projects[index].id in achieved else art.STEEL.darkened(0.5)
		art.box(decorations,Vector3(0.4,0.1,0.03),Vector3(-15.6+index*0.6,0.85,4.88),color)
	if "community" in achieved:
		for x in [10,18]:
			art.cylinder(decorations,0.06,3.3,Vector3(x,1.65,17),art.STEEL,16)
			art.box(decorations,Vector3(0.65,0.15,0.4),Vector3(x,3.3,17),art.YELLOW)
			var light = OmniLight3D.new()
			light.position = Vector3(x,3,17)
			light.omni_range = 12
			light.light_energy = 1.2
			decorations.add_child(light)
		art.sign_text(decorations,"RIPARATO A RIVA SECCA",Vector3(14,3.3,19.5),24,true)
	if "production" in achieved:
		art.sign_text(decorations,"LINEA CERTIFICATA\nTEMPI −10%",Vector3(-10,3.5,14),28,true)
	if "archive" in achieved:
		for index in 3:
			art.box(decorations,Vector3(0.8,0.75,0.6),Vector3(-25+index,0.4,16),art.GRAPHITE)
			var model = Node3D.new()
			model.position = Vector3(-25+index,0.8,16)
			model.scale = Vector3.ONE*0.6
			decorations.add_child(model)
			preload("res://scripts/gameplay/scrap_catalog.gd").build(model,[0,2,5][index],[4,4,3][index],art)
		art.sign_text(decorations,"ARCHIVIO DEI RECUPERI",Vector3(-24,2,16),24,true)
	if GameState.story.complete():
		art.sign_text(decorations,"SCRAP EMPIRE\nIL CENTRO DI RIVA SECCA",Vector3(0,5,73),46,true)
