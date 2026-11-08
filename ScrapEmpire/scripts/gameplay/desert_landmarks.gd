extends Node3D
## Fixed landmarks and seeded ecological clusters. Salvage uses existing receipts.
const TERRAIN=preload("res://scripts/gameplay/desert_world.gd")
const SITES={
	"crash":{"name":"Volo 76 / relitto cargo","point":Vector3(-350,0,205)},
	"cave":{"name":"Grotta del Vento","point":Vector3(375,0,-230)},
	"anomaly":{"name":"Segnale 09 / cerchio anomalo","point":Vector3(-385,0,-360)}
}
var elapsed: float=0
var player: Node3D
var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
var stone_mesh: ArrayMesh=preload("res://scripts/gameplay/heap_details.gd")._stone_mesh()

static func point(id: String) -> Vector3:
	var at: Vector3=SITES[id].point
	at.y=TERRAIN.height_at(at)
	return at

func _ready() -> void:
	name="DesertDiscoveryArt"
	add_to_group("desert_landmarks")
	for id in SITES:
		var site=Node3D.new()
		site.name=id
		site.position=point(id)
		add_child(site)
		if id=="crash": _plane(site)
		elif id=="cave": preload("res://scripts/gameplay/subterranean_cave.gd").build(get_parent())
		else: _anomaly(site)
		for index in (2 if id=="crash" else 1):
			var crate=StaticBody3D.new()
			crate.set_script(preload("res://scripts/gameplay/salvage_assembly.gd"))
			crate.definition_id=("aircraft_turbine" if index==1 else "sealed_crate") if id=="crash" else ("survey_rig" if id=="cave" else "signal_receiver")
			crate.entity_id="desert_%s_%d" % [id,index]
			crate.position=site.position+(Vector3(-6-index*5,0,9+index*4) if id=="crash" else Vector3(-8 if id=="anomaly" else -4,0,-4))
			crate.position.y=TERRAIN.height_at(crate.position)+0.06
			if id=="cave": crate.position=Vector3(371,preload("res://scripts/gameplay/subterranean_cave.gd").floor_height(Vector3(371,0,-281))+0.06,-281)
			get_parent().add_child(crate)
	if DisplayServer.get_name()!="headless": _scatter()

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed<0.5: return
	elapsed=0
	if not is_instance_valid(player): player=get_tree().get_first_node_in_group("players")
	if not is_instance_valid(player): return
	for id in SITES:
		if player.global_position.distance_to(point(id))<27 and GameState.ops.visit_site(id):
			GameState.machine_message.emit("Luogo scoperto: "+SITES[id].name+" · segnato sulla mappa")

func solid(parent: Node3D, dimensions: Vector3, at: Vector3, color: Color, yaw: float=0, draw: bool=true) -> Node3D:
	var body=StaticBody3D.new()
	body.position=at
	body.rotation.y=yaw
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=dimensions
	body.add_child(shape)
	parent.add_child(body)
	if draw and DisplayServer.get_name()!="headless": art.beveled_box(body,dimensions,Vector3.ZERO,color,true)
	return body

func _plane(site: Node3D) -> void:
	# Split, hollow fuselage: open end, physical deck and two side walls.
	solid(site,Vector3(4.5,0.3,19),Vector3(0,1.0,-3),Color("#c0b5a0"))
	solid(site,Vector3(0.3,3.4,19),Vector3(-2.2,2.8,-3),art.STEEL,0,false)
	solid(site,Vector3(0.3,3.4,19),Vector3(2.2,2.8,-3),art.STEEL,0,false)
	solid(site,Vector3(4.5,0.2,14),Vector3(0,4.5,-5),art.STEEL,0,false)
	solid(site,Vector3(27,0.3,4),Vector3(0,1.35,-4),Color("#d3c4aa"),-0.12)
	solid(site,Vector3(4.5,0.18,6.2),Vector3(0,0.55,9.4),art.STEEL).rotation.x=0.19
	if DisplayServer.get_name()=="headless": return
	var shell=SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 32:
		var a: float=float(index)/32*TAU
		var b: float=float(index+1)/32*TAU
		var p=Vector3(cos(a)*2.35,2.8+sin(a)*2.2,-12.5)
		var q=Vector3(cos(b)*2.35,2.8+sin(b)*2.2,-12.5)
		for vertex in [p,q,p+Vector3(0,0,19),q,q+Vector3(0,0,19),p+Vector3(0,0,19)]: shell.add_vertex(vertex)
	shell.generate_normals()
	var fuselage=MeshInstance3D.new()
	fuselage.mesh=shell.commit()
	var skin=art.surface_material(Color("#b6c4c0"),"steel").duplicate()
	skin.cull_mode=BaseMaterial3D.CULL_DISABLED
	fuselage.material_override=skin
	site.add_child(fuselage)
	for side in [-1,1]:
		for window in 9:
			art.beveled_box(site,Vector3(0.035,0.48,0.65),Vector3(side*2.37,3.35,-11+window*1.7),Color("#253d41"))
		art.box(site,Vector3(0.04,0.32,18.9),Vector3(side*2.38,2.75,-3),art.RUST)
		for z in [-10,-6,-2,2]:
			for segment in 8:
				var a: float=float(segment)/8*PI
				var b: float=float(segment+1)/8*PI
				art.beam(site,Vector3(cos(a)*2.2,2.8+sin(a)*1.9,z),Vector3(cos(b)*2.2,2.8+sin(b)*1.9,z),0.11,art.GRAPHITE)
		var engine=art.cylinder(site,1.05,3.6,Vector3(side*6,0.5,-3.2),art.RUST,32)
		engine.rotation.x=PI/2
		art.cylinder(engine,0.72,0.08,Vector3(0,-1.81,0),art.GRAPHITE,32)
	art.beveled_box(site,Vector3(0.24,7,5),Vector3(0,4,-16),art.RUST,true).rotation.x=0.2
	art.beveled_box(site,Vector3(10,0.18,3),Vector3(0,3,-15),art.STEEL,true)
	art.sign_text(site,"RIVA CARGO / 76",Vector3(2.4,3.9,-5),30).rotation.y=PI/2
	for index in 13:
		var piece=art.beveled_box(site,Vector3(0.6+index%3,0.15,0.8),Vector3(-15+index*2.4,-0.1,8+sin(index)*5),art.STEEL,true)
		piece.rotation.y=index*0.7

func stone(parent: Node3D, at: Vector3, dimensions: Vector3, variation: int, collision: bool=false) -> void:
	var body=StaticBody3D.new() if collision else Node3D.new()
	body.position=at
	body.rotation.y=variation*0.73
	parent.add_child(body)
	if collision:
		var shape=CollisionShape3D.new()
		var convex=ConvexPolygonShape3D.new()
		var points: PackedVector3Array=stone_mesh.get_faces()
		for index in points.size(): points[index]*=dimensions
		convex.points=points
		shape.shape=convex
		body.add_child(shape)
	if DisplayServer.get_name()=="headless": return
	var visual=MeshInstance3D.new()
	visual.mesh=stone_mesh
	visual.scale=dimensions
	visual.material_override=art.surface_material(Color("#ae8159").lightened((variation%3)*0.025),"rubble")
	body.add_child(visual)

func _anomaly(site: Node3D) -> void:
	var hull=StaticBody3D.new()
	var shape=CollisionShape3D.new()
	shape.shape=CylinderShape3D.new()
	shape.shape.radius=6.5
	shape.shape.height=0.65
	shape.position.y=0.6
	hull.add_child(shape)
	site.add_child(hull)
	for index in 9:
		var angle: float=float(index)/9*TAU
		solid(site,Vector3(1.5,3.4,1.5),Vector3(sin(angle)*12,1,cos(angle)*12),art.GRAPHITE,angle)
	if DisplayServer.get_name()=="headless": return
	var saucer=art.cylinder(site,6.5,0.65,Vector3(0,0.6,0),art.STEEL,48)
	saucer.rotation.z=0.13
	art.cylinder(site,3.8,1.3,Vector3(0,1.35,0),art.GRAPHITE,40)
	for index in 16:
		var angle: float=float(index)/16*TAU
		art.cylinder(site,0.15,0.06,Vector3(sin(angle)*6,1,cos(angle)*6),art.MINT,16)
	# Inert visitor sculpture: a desert mystery, no enemy or AI system.
	var visitor=Node3D.new()
	visitor.position=Vector3(5,0,-4)
	site.add_child(visitor)
	art.cylinder(visitor,0.2,1.0,Vector3(0,0.8,0),Color("#80a28f"),24)
	var head=MeshInstance3D.new()
	var mesh=SphereMesh.new()
	mesh.radius=0.36
	mesh.height=0.88
	mesh.radial_segments=28
	mesh.rings=16
	head.mesh=mesh
	head.position.y=1.65
	head.material_override=art.material(Color("#91b49a"))
	visitor.add_child(head)
	for side in [-1,1]:
		art.beveled_box(visitor,Vector3(0.2,0.14,0.08),Vector3(side*0.16,1.67,0.3),Color("#142827")).rotation.z=side*0.2
		art.beam(visitor,Vector3(side*0.12,0.5,0),Vector3(side*0.2,0.05,0.1),0.11,Color("#80a28f"))
		art.beam(visitor,Vector3(side*0.22,1.15,0),Vector3(side*0.34,0.6,0.1),0.1,Color("#80a28f"))

func _scatter() -> void:
	var random=RandomNumberGenerator.new()
	random.seed=90776
	for index in 165:
		var at=Vector3(random.randf_range(-510,510),0,random.randf_range(-510,510))
		if maxf(absf(at.x),absf(at.z))<115 or (at.x>70 and at.x<285 and at.z> -90 and at.z<35): continue
		if Vector2(at.x+230,at.z+175).length()<85 or Vector2(at.x-260,at.z-320).length()<60: continue
		at.y=TERRAIN.height_at(at)
		if index%3==0:
			stone(self,at,Vector3(random.randf_range(2.5,7),random.randf_range(2,6),random.randf_range(2.5,7)),index)
		else:
			var height: float=random.randf_range(1.6,4.3)
			art.cylinder(self,0.23,height,at+Vector3.UP*height*0.5,Color("#517258"),16)
			for side in [-1,1]:
				var arm=at+Vector3(side*0.6,height*0.5,0)
				art.beam(self,at+Vector3(0,height*0.5,0),arm,0.22,Color("#517258"))
				art.cylinder(self,0.15,height*0.3,arm+Vector3.UP*height*0.15,Color("#638268"),16)
