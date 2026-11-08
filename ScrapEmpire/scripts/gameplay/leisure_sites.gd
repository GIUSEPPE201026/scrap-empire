extends Node3D
## Optional physical destinations. Only completed best laps persist; no monetary reward.
const PARK=Vector3(-230,4,-175)
const OASIS=Vector3(260,0,320)
const GATES=[Vector3(0,0,42),Vector3(-38,0,20),Vector3(-38,0,-25),Vector3(0,0,-43),Vector3(38,0,-20),Vector3(38,0,25)]
var checkpoint: int=-1
var elapsed: float=0.0
var best: Dictionary={}
var current_vehicle: Node3D
var timer_label: Label3D
var markers: Array[MeshInstance3D]=[]
var _player: Node3D
var _last_position: Vector3
var start_armed: bool=true

func _ready() -> void:
	name="LeisureSites"
	add_to_group("leisure_sites")
	for key in GameState.operations.get("park_records",{}): best[int(key)]=float(GameState.operations.park_records[key])
	_build_park()
	_build_oasis()

func _solid(size_value: Vector3, at: Vector3, color: Color, pitch: float=0.0) -> StaticBody3D:
	var body=StaticBody3D.new()
	body.position=at
	body.rotation.x=pitch
	var collision=CollisionShape3D.new()
	collision.shape=BoxShape3D.new()
	collision.shape.size=size_value
	body.add_child(collision)
	add_child(body)
	if DisplayServer.get_name()!="headless":
		preload("res://scripts/gameplay/scrapyard_art.gd").new().box(body,size_value,Vector3.ZERO,color,true)
	return body

func _build_park() -> void:
	# Two opposing shallow launch ramps, a tabletop, and a separate scooter rail.
	for side in [-1,1]:
		_solid(Vector3(9,0.35,15.2),PARK+Vector3(-38,1.12,side*9),Color("#b36340"),side*0.18).add_to_group("park_ramps")
	_solid(Vector3(9,0.4,3),PARK+Vector3(-38,2.3,0),Color("#dfb45f"))
	_solid(Vector3(1,0.6,14),PARK+Vector3(8,0.3,5),Color("#68a796"))
	_solid(Vector3(6,0.25,9),PARK+Vector3(24,0.5,5),Color("#668d99"),-0.16).add_to_group("park_ramps")
	if DisplayServer.get_name()=="headless":
		return
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	for index in GATES.size():
		var point: Vector3=PARK+GATES[index]
		for side in [-1,1]:
			art.cylinder(self,0.3,3,point+Vector3(side*6,1.5,0),art.MINT if index else art.YELLOW)
		var mesh=art.cylinder(self,6.5,0.03,point+Vector3.UP*0.04,art.MINT if index else art.YELLOW,32)
		var paint=StandardMaterial3D.new()
		paint.albedo_color=Color("#e4ad49") if index==0 else Color("#62ad9a")
		paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override=paint
		markers.append(mesh)
		art.sign_text(self,str(index+1),point+Vector3(0,3.8,0),48,true)
	for i in 8:
		var cone=MeshInstance3D.new()
		var shape=CylinderMesh.new()
		shape.top_radius=0.08
		shape.bottom_radius=0.45
		shape.height=0.9
		cone.mesh=shape
		cone.material_override=art.material(art.RUST)
		cone.position=PARK+Vector3(30+(i%2)*5,0.45,-12+i*4)
		add_child(cone)
	timer_label=art.sign_text(self,"DUNE PARK\nMONO %s · BUGGY %s\nCROSS %s · SKATE %s\n1 → 6 → 1" % [_record_text(1),_record_text(2),_record_text(3),_record_text(4)],PARK+Vector3(0,5,48),34,true)
	art.sign_text(self,"SPAZIO + STERZO\nFRENO A MANO",PARK+Vector3(18,3.5,35),30,true)

func _build_oasis() -> void:
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var depot=StaticBody3D.new()
	depot.name="OasisDepot"
	depot.position=OASIS+Vector3(-22,3,-8)
	depot.add_to_group("field_depot")
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(2,1.4,1.5)
	shape.position.y=0.7
	depot.add_child(shape)
	add_child(depot)
	for index in 9:
		var angle: float=index*TAU/9
		var point: Vector3=OASIS+Vector3(cos(angle)*21,3,sin(angle)*21)
		var palm=_solid(Vector3(0.5,7,0.5),point+Vector3.UP*3.5,Color("#986a43"))
		if DisplayServer.get_name()!="headless":
			for leaf in 7:
				var direction=Vector3(cos(leaf*TAU/7),-0.3,sin(leaf*TAU/7))
				art.beam(palm,Vector3(0,3.2,0),Vector3(0,3.2,0)+direction*3.8,0.65,Color("#4e8461"))
	if DisplayServer.get_name()=="headless":
		return
	art.box(depot,shape.shape.size,Vector3(0,0.7,0),art.MINT,true)
	art.sign_text(depot,"SCARICO",Vector3(0,2,0),30,true)
	var water=art.cylinder(self,13,0.06,OASIS+Vector3.UP*1.85,Color("#389faf"),64)
	var material=StandardMaterial3D.new()
	material.albedo_color=Color("#3a9faaa8")
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness=0.16
	water.material_override=material
	for i in 3:
		_solid(Vector3(3,0.45,0.8),OASIS+Vector3(-17+i*4,3.6,-18),Color("#b58c58"))
		for x in [-1.1,1.1]:
			for z in [-0.25,0.25]:
				art.box(self,Vector3(0.12,0.6,0.12),OASIS+Vector3(-17+i*4+x,3.3,-18+z),art.GRAPHITE)
	for i in 16:
		var angle: float=i*TAU/16
		var point: Vector3=OASIS+Vector3(cos(angle)*16,2.4,sin(angle)*16)
		point.y=preload("res://scripts/gameplay/desert_world.gd").height_at(point)+0.25
		var rock=MeshInstance3D.new()
		var mesh=SphereMesh.new()
		mesh.radial_segments=12
		mesh.rings=6
		mesh.radius=0.75+float(i%3)*0.25
		mesh.height=mesh.radius*1.4
		rock.mesh=mesh
		rock.material_override=art.material(Color("#bfa47f"))
		rock.position=point
		rock.scale=Vector3(1.4,0.7,1.0)
		add_child(rock)
		if i%2==0:
			for stem in 4:
				art.beam(self,point+Vector3(stem*0.2,-0.25,0),point+Vector3(stem*0.2+0.3,1.2+stem*0.15,0),0.08,Color("#718857"))
	art.sign_text(self,"OASI DEL RITORNO\nRIPOSA · SCARICA · ESPLORA",OASIS+Vector3(-20,6,-16),35,true)

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player=get_tree().get_first_node_in_group("players")
		if not is_instance_valid(_player): return
		_last_position=_player.global_position
	if checkpoint<0 and _player.global_position.distance_to(PARK)>130:
		_last_position=_player.global_position
		return
	var mounted: Node3D=_player._mounted_vehicle
	advance(_player.global_position,mounted,delta)

func advance(at: Vector3, vehicle: Node3D, delta: float) -> void:
	var teleported: bool=at.distance_to(_last_position)>35
	_last_position=at
	if checkpoint>=0 and (not is_instance_valid(vehicle) or vehicle!=current_vehicle or teleported or at.distance_to(PARK)>115):
		checkpoint=-1
		_update_label("GIRO INTERROTTO\nTORNA AL VARCO 1")
		_highlight()
	if not is_instance_valid(vehicle) or teleported: return
	if checkpoint<0:
		if at.distance_to(PARK+GATES[0])>12: start_armed=true
		if start_armed and at.distance_to(PARK+GATES[0])<7:
			start_armed=false
			current_vehicle=vehicle
			checkpoint=1
			elapsed=0
			_feedback("Dune Park · VIA! Segui i varchi numerati.")
	else:
		elapsed+=delta
		var target: Vector3=PARK+GATES[checkpoint%GATES.size()]
		if at.distance_to(target)<7:
			checkpoint+=1
			if checkpoint>GATES.size():
				var key: int=4 if vehicle.vehicle_kind=="skateboard" else vehicle.level
				if GameState.ops.record_lap(key,elapsed): best[key]=elapsed
				# A failed checkpoint must not advertise a record that was not saved.
				var shown_best: String=_record_text(key)
				_feedback("Giro: %.1f s · migliore %s: %s" % [elapsed,{1:"mono",2:"buggy",3:"cross",4:"skate"}[key],shown_best])
				checkpoint=-1
				_update_label("%.1f s  ·  BEST %s\nTORNA AL VARCO 1" % [elapsed,shown_best])
				_highlight()
				return
			_feedback("%d / 6  ·  %.1f s  →  %d" % [checkpoint-1,elapsed,(checkpoint%6)+1])
		_update_label("%.1f s   ·   %d / 6\n→ VARCO %d" % [elapsed,mini(checkpoint,6),(checkpoint%6)+1])
	_highlight()

func _highlight() -> void:
	for index in markers.size():
		var target: bool=index==maxi(checkpoint,0)%6
		markers[index].scale=Vector3.ONE*(1.0 if target else 0.7)
		markers[index].material_override.albedo_color=Color("#ffd166") if target else Color("#62ad9a")

func _feedback(message: String) -> void:
	if is_instance_valid(_player): _player._notify(message)

func _update_label(value: String) -> void:
	if is_instance_valid(timer_label): timer_label.text=value

func _record_text(vehicle: int) -> String:
	return "%.1f s" % float(best[vehicle]) if best.has(vehicle) else "—"
