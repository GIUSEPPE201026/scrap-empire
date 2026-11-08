extends RefCounted

const SPAWN = Vector3(-8,0.08,2)
const TARGET = Vector3(-8,1.5,22)

static func build(root: Node3D) -> void:
	var marker = Marker3D.new()
	marker.name = "ArrivalArea"
	marker.position = SPAWN
	marker.add_to_group("arrival_area")
	root.add_child(marker)
	# The starter sorting bench is collidable and uses three of the existing 120 items.
	root._yard_box("StarterBench",Vector3(3.8,0.12,1.1),Vector3(-8,0.68,7),Color("#686b61"))
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var zone = Node3D.new()
	zone.name = "ArrivalArt"
	root.add_child(zone)
	for row in 4:
		for col in 5:
			var tile = art.beveled_box(zone,Vector3(1.12,0.035,0.85),Vector3(-10.3+col*1.16,0.025,0.7+row*0.9),Color("#b1a794"))
			tile.material_override = art.surface_material(Color("#b1a794"),"rubble")
	for side in [-1,1]:
		art.cylinder(zone,0.11,0.8,Vector3(-8+side*2.8,0.4,3.3),art.YELLOW,24)
		art.cylinder(zone,0.115,0.22,Vector3(-8+side*2.8,0.45,3.3),art.GRAPHITE,24)
		art.box(zone,Vector3(0.12,0.65,0.7),Vector3(-8+side*1.6,0.32,7),art.GRAPHITE)
	for index in 3:
		art.box(zone,Vector3(1.0,0.018,0.75),Vector3(-9.2+index*1.2,0.75,7),[art.STEEL,art.MINT,art.YELLOW][index])
	# A small physical orientation board, read from the arrival pad.
	var board = Node3D.new()
	board.position = Vector3(-11.5,0,8.3)
	board.rotation.y = PI
	zone.add_child(board)
	for side in [-1,1]:
		art.box(board,Vector3(0.06,2.6,0.06),Vector3(side*1.0,1.3,0),art.STEEL)
	art.beveled_box(board,Vector3(2.35,1.55,0.12),Vector3(0,2.05,0),art.GRAPHITE)
	for entry in [["IL TUO DEPOSITO",2.6,44],["01  RECUPERA E SEPARA",2.22,38],["02  SCARICA E VENDI",1.88,38],["03  COMMESSE IN UFFICIO",1.54,38]]:
		var label = art.sign_text(board,entry[0],Vector3(0,entry[1],0.075),entry[2])
		label.pixel_size = 0.004
		label.outline_size = 0
	for step in 5:
		art.box(zone,Vector3(0.12,0.012,0.6),Vector3(-8+step*0.6,0.043,10+step*1.6),art.YELLOW)
	var lamp = OmniLight3D.new()
	lamp.position = Vector3(-8,2.9,7)
	lamp.omni_range = 7
	lamp.light_energy = 0.45
	lamp.light_color = Color("#ffe7bc")
	zone.add_child(lamp)
