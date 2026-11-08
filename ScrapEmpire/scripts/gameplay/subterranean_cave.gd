extends RefCounted
## A real hole in the terrain leads down a ramp beneath the intact desert surface.
const MOUTH_Z: float=-235.0
const FLOOR_Y: float=-14.0
const BOUNDS=Rect2(365,-300,20,65)

static func cuts_cell(at: Vector3) -> bool:
	return at.x>=365 and at.x<385 and at.z>=-255 and at.z< -235

static func contains(at: Vector3) -> bool:
	return Rect2(363,-302,24,70).has_point(Vector2(at.x,at.z))

static func floor_height(at: Vector3) -> float:
	var surface: float=load("res://scripts/gameplay/desert_world.gd").height_at(Vector3(at.x,0,MOUTH_Z))
	var depth: float=clampf((MOUTH_Z-at.z)/35.0,0,1)
	return lerpf(surface,FLOOR_Y,depth)+sin(at.x*0.8+at.z*0.4)*0.12*depth

static func build(sector: Node3D) -> void:
	var root=Node3D.new()
	root.name="UndergroundCave"
	root.add_to_group("underground_cave")
	sector.add_child(root)
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var floor_faces=PackedVector3Array()
	var wall_faces=PackedVector3Array()
	for row in 12:
		var z: float=MOUTH_Z-row*5
		for column in 8:
			var x: float=365+column*2.5
			var a=Vector3(x,0,z)
			var b=Vector3(x+2.5,0,z)
			var c=Vector3(x,0,z-5)
			var e=Vector3(x+2.5,0,z-5)
			for point in [a,b,c,b,e,c]:
				point.y=floor_height(point)
				floor_faces.append(point)
			if z<=-255:
				for point in [a,c,b,b,c,e]:
					point.y=floor_height(point)+6.0+sqrt(maxf(0,1-pow((point.x-375)/10,2)))*2
					wall_faces.append(point)
		for x in [365.0,385.0]:
			var a=Vector3(x,floor_height(Vector3(x,0,z)),z)
			var b=Vector3(x,floor_height(Vector3(x,0,z-5)),z-5)
			var high_a: float=load("res://scripts/gameplay/desert_world.gd").height_at(a)+1.0 if z> -255 else a.y+6
			var high_b: float=load("res://scripts/gameplay/desert_world.gd").height_at(b)+1.0 if z> -255 else b.y+6
			for point in [a,b,Vector3(x,high_a,z),b,Vector3(x,high_b,z-5),Vector3(x,high_a,z)]: wall_faces.append(point)
	# Extend below the irregular floor to avoid a daylight seam at the end wall.
	var end_left=Vector3(365,FLOOR_Y-1,-295)
	var end_right=Vector3(385,FLOOR_Y-1,-295)
	for point in [end_left,end_right,end_left+Vector3.UP*10,end_right,end_right+Vector3.UP*10,end_left+Vector3.UP*10]: wall_faces.append(point)
	_surface(root,"CaveFloor",floor_faces,art.surface_material(Color("#a78965"),"rubble"))
	_surface(root,"CaveRock",wall_faces,art.surface_material(Color("#74664f"),"rubble"))
	if DisplayServer.get_name()=="headless": return
	for index in 6:
		var light=OmniLight3D.new()
		light.position=Vector3(369+(index%2)*12,floor_height(Vector3(375,0,-250-index*7))+2.7,-250-index*7)
		light.light_color=Color("#d9b985") if index<3 else Color("#76aca0")
		light.light_energy=1.2
		light.omni_range=13
		root.add_child(light)
		art.beam(root,light.position-Vector3.UP*1.7,light.position,0.08,art.GRAPHITE)
		art.beveled_box(root,Vector3(0.2,0.2,0.2),light.position,art.MINT)
	for index in 18:
		var x: float=366.0 if index%2==0 else 384.0
		var z: float=-250-index*2.4
		var base=Vector3(x,floor_height(Vector3(x,0,z)),z)
		var mesh=MeshInstance3D.new()
		mesh.mesh=preload("res://scripts/gameplay/heap_details.gd")._stone_mesh()
		mesh.position=base+Vector3.UP*2.4
		mesh.scale=Vector3(2.8,5.5,4.4)
		mesh.material_override=art.surface_material(Color("#897151"),"rubble")
		root.add_child(mesh)
	# Broken bedding and stalactites soften the tunnel's construction grid.
	for index in 24:
		var x: float=366.7+(index%7)*2.7
		var z: float=-259-(index/7)*9.0
		var y: float=floor_height(Vector3(x,0,z))+6.0+sqrt(maxf(0,1-pow((x-375)/10,2)))*2
		var length: float=0.8+float(index%4)*0.35
		var tip=art.cylinder(root,0.15+float(index%3)*0.12,length,Vector3(x,y+0.4-length*0.5,z),Color("#82715b"),16)
		tip.mesh.top_radius=0.025
		tip.material_override=art.surface_material(Color("#82715b"),"rubble")
		tip.rotation.z=PI+sin(index)*0.2
	art.sign_text(root,"GROTTA DEL VENTO\n↓ DISCESA / RECUPERO",Vector3(375,load("res://scripts/gameplay/desert_world.gd").height_at(Vector3(375,0,-230))+2.5,-229),32,true)

static func _surface(root: Node3D, title: String, faces: PackedVector3Array, material: Material) -> void:
	var body=StaticBody3D.new()
	body.name=title
	var shape=CollisionShape3D.new()
	var hull=ConcavePolygonShape3D.new()
	hull.backface_collision=true
	hull.set_faces(faces)
	shape.shape=hull
	body.add_child(shape)
	root.add_child(body)
	if DisplayServer.get_name()=="headless": return
	var tool=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in faces: tool.add_vertex(point)
	tool.generate_normals()
	var mesh=MeshInstance3D.new()
	mesh.mesh=tool.commit()
	var double_sided: Material=material.duplicate()
	if double_sided is StandardMaterial3D: double_sided.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=double_sided
	body.add_child(mesh)
