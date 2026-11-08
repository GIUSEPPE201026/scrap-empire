extends RefCounted

static func build(lot: Node3D, index: int) -> void:
	var station = Node3D.new()
	station.position = Vector3(-25,0,-30)
	station.set_meta("operation","recovery" if index == 0 else "dispatch")
	station.add_to_group("operations_service")
	lot.add_child(station)
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(2.5,0.9,1.0)
	shape.position.y = 0.45
	body.add_child(shape)
	station.add_child(body)
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.beveled_box(station,Vector3(2.5,0.9,1),Vector3(0,0.45,0),art.MINT if index == 0 else art.YELLOW)
	art.box(station,Vector3(2.6,0.08,1.1),Vector3(0,0.94,0),art.GRAPHITE)
	var title = art.sign_text(station,"BANCO RECUPERO\nRIPARA / RICICLA" if index == 0 else "BANCHINA SPEDIZIONI\nFORNITURE / TRAMOGGIA",Vector3(0,2.0,0.2),36)
	title.pixel_size = 0.0035
	for side in [-1,1]:
		art.box(station,Vector3(0.06,1.3,0.06),Vector3(side*1.0,1.55,0.3),art.STEEL)
	if index == 0:
		var engine = Node3D.new()
		engine.position = Vector3(0,1.0,0)
		engine.scale = Vector3.ONE*0.65
		station.add_child(engine)
		preload("res://scripts/gameplay/haul_part.gd").build_model(engine,"engine",0)
	else:
		var hopper = Node3D.new()
		hopper.position = Vector3(-20,0,-35)
		lot.add_child(hopper)
		for side in [-1,1]:
			for z in [-1,1]:
				art.box(hopper,Vector3(0.12,2.9,0.12),Vector3(side*1.1,1.45,z*1.1),art.STEEL)
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in 4:
			var a: float = PI/4+side*PI/2
			var b: float = a+PI/2
			var top_a = Vector3(cos(a)*1.9,2.9,sin(a)*1.9)
			var top_b = Vector3(cos(b)*1.9,2.9,sin(b)*1.9)
			var bottom_a = Vector3(cos(a)*0.6,1.5,sin(a)*0.6)
			var bottom_b = Vector3(cos(b)*0.6,1.5,sin(b)*0.6)
			for point in [top_a,top_b,bottom_a,top_b,bottom_b,bottom_a]:
				surface.add_vertex(point)
		surface.generate_normals()
		var funnel = MeshInstance3D.new()
		funnel.mesh = surface.commit()
		funnel.material_override = art.surface_material(art.YELLOW,"steel").duplicate()
		funnel.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		hopper.add_child(funnel)
		art.beveled_box(hopper,Vector3(0.85,0.9,0.85),Vector3(0,1.05,0),art.GRAPHITE)
		var light = MeshInstance3D.new()
		light.set_script(preload("res://scripts/gameplay/hopper_indicator.gd"))
		light.position = Vector3(1.25,2.9,-1.25)
		hopper.add_child(light)
		for row in 3:
			for column in 3:
				art.beveled_box(lot,Vector3(1.1,0.8,1.0),Vector3(-17+column*1.3,0.45+row*0.85,-34),art.MINT if row%2==0 else art.STEEL)
		for step in 8:
			art.box(lot,Vector3(0.1,0.015,1),Vector3(-20,0.045,-28+step*1.6),art.YELLOW)
