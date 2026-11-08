extends RefCounted

static func build(root: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var details = Node3D.new()
	details.name = "HubArchitecture"
	root.add_child(details)
	# Office: framed windows, external skirting, roof fascia and entrance lights.
	for side in [-1,1]:
		var x: float = -18+side*4.12
		art.beveled_box(details,Vector3(0.08,1.25,2.15),Vector3(x,2,25),art.GRAPHITE)
		art.beveled_box(details,Vector3(0.09,1.05,1.9),Vector3(x+side*0.025,2,25),Color("#527883"))
		art.box(details,Vector3(0.12,0.055,2.05),Vector3(x+side*0.05,2,25),art.STEEL)
		art.box(details,Vector3(0.12,1.1,0.05),Vector3(x+side*0.05,2,25),art.STEEL)
		art.beveled_box(details,Vector3(0.28,0.08,2.4),Vector3(x,1.32,25),art.STEEL)
	for x in [-21.5,-14.5]:
		art.box(details,Vector3(0.1,0.6,0.12),Vector3(x,2.35,21.83),art.GRAPHITE)
		art.box(details,Vector3(0.12,0.28,0.08),Vector3(x,2.35,21.74),Color("#f5dfaa"))
	art.beveled_box(details,Vector3(8.6,0.3,0.22),Vector3(-18,3.45,21.7),art.MINT.darkened(0.25))
	art.beveled_box(details,Vector3(2.8,0.06,1.5),Vector3(-18,0.05,21.1),Color("#88806b"))
	for side in [-1,1]:
		art.box(details,Vector3(0.08,0.015,1.1),Vector3(-18+side*1.0,0.09,21),art.YELLOW)
	# Garage: roller shutter guides, ventilated facade and separate service signs.
	for x in [1.35,6.65]:
		art.beveled_box(details,Vector3(0.18,3.8,0.24),Vector3(x,1.9,21.72),art.STEEL)
	art.beveled_box(details,Vector3(5.8,0.6,0.45),Vector3(4,4.0,21.65),art.GRAPHITE)
	for slat in 6:
		art.box(details,Vector3(5.2,0.035,0.06),Vector3(4,3.82+slat*0.075,21.38),art.STEEL)
	for side in [-1,1]:
		for rib in 18:
			art.box(details,Vector3(0.04,3.6,0.065),Vector3(4+side*6.6,2.1,22.2+rib*0.32),art.MINT.darkened(0.35))
	for x in [-0.5,8.5]:
		art.beveled_box(details,Vector3(1.65,0.75,0.1),Vector3(x,2.5,21.8),art.GRAPHITE)
		for vent in 5:
			art.box(details,Vector3(1.4,0.045,0.08),Vector3(x,2.23+vent*0.13,21.73),art.STEEL)
	var sign = art.sign_text(details,"MEZZI  /  CASSONE  /  MANUTENZIONE",Vector3(4,3.45,21.66),30)
	sign.rotation.y = PI
	sign.pixel_size = 0.0035
	# Pipework and drain details connect the production apron to its warehouse.
	for z in [11,12,13,14,15,16,17]:
		art.box(details,Vector3(0.5,0.016,0.06),Vector3(-14,0.05,z),art.STEEL)

static func recovery_sites(root: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var desert = preload("res://scripts/gameplay/desert_world.gd")
	for position in [Vector3(-115,0,148),Vector3(160,0,138)]:
		var camp = Node3D.new()
		camp.name = "DesertRecoverySite"
		camp.position = Vector3(position.x,desert.height_at(position),position.z)
		camp.add_to_group("recovery_sites")
		root.add_child(camp)
		for side in [-1,1]:
			for z in [-2,2]:
				var local = Vector3(side*3.3,0,z)
				var world: Vector3 = position+local
				var ground: float = desert.height_at(world)-camp.position.y
				art.box(camp,Vector3(0.12,3.2-ground,0.12),Vector3(local.x,(3.2+ground)*0.5,local.z),art.STEEL)
		art.beveled_box(camp,Vector3(7.1,0.15,5),Vector3(0,3.25,0),art.RUST)
		art.beveled_box(camp,Vector3(5.8,1.8,0.1),Vector3(0,1.0,2.05),art.MINT.darkened(0.25))
		for rib in 17:
			art.box(camp,Vector3(0.045,1.75,0.08),Vector3(-2.7+rib*0.34,1,1.98),art.STEEL.darkened(0.4))
		for side in [-1,1]:
			art.barrel(camp,Vector3(side*2.7,0,0.4),art.YELLOW if side>0 else art.MINT)
		var sign = art.sign_text(camp,"RECUPERO ESTERNO\nCOMPONENTI INGOMBRANTI",Vector3(0,2.65,-2.1),36)
		sign.rotation.y = PI
		sign.pixel_size = 0.004
