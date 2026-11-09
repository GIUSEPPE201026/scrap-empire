extends Node3D
## Procedural articulated local driver; pose 0 standing, 1 seated.
var seated: float=1.0:
	set(value):
		seated=clampf(value,0,1)
		if is_instance_valid(torso): _pose()
var torso: Node3D
var segments: Array[Node3D]=[]
var boots: Array[Node3D]=[]
var scooter_pose: bool=false
var skate_pose: bool=false
var bike_pose: bool=false
var skate_push: float=0.0:
	set(value):
		skate_push=value
		if is_instance_valid(torso): _pose()
var gait_phase: float=0.0
var gait_amount: float=0.0

func animate_walk(delta: float, speed: float) -> void:
	if not is_instance_valid(torso): return
	gait_phase+=speed*delta*2.5
	gait_amount=move_toward(gait_amount,minf(speed/4.5,1.0),delta*6)
	_pose()
var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	torso=Node3D.new()
	add_child(torso)
	art.beveled_box(torso,Vector3(0.47,0.53,0.3),Vector3.ZERO,Color("#b88340"))
	for side in [-1,1]:
		art.beveled_box(torso,Vector3(0.17,0.3,0.035),Vector3(side*0.13,0.05,-0.17),Color("#c3a16a"))
		art.box(torso,Vector3(0.08,0.42,0.018),Vector3(side*0.18,0,-0.195),Color("#e2d4a1"))
		art.beveled_box(torso,Vector3(0.1,0.17,0.15),Vector3(side*0.27,-0.2,0.02),art.GRAPHITE)
	art.box(torso,Vector3(0.48,0.065,0.32),Vector3(0,-0.23,0),art.GRAPHITE)
	var head=Node3D.new()
	torso.add_child(head)
	sphere(head,Vector3(0,0.54,0),Vector3(0.32,0.39,0.30),Color("#c69a73"))
	sphere(head,Vector3(0,0.69,0.015),Vector3(0.40,0.24,0.38),Color("#d3ab55"))
	art.beveled_box(head,Vector3(0.44,0.035,0.40),Vector3(0,0.64,-0.015),Color("#d3ab55"))
	art.beveled_box(head,Vector3(0.31,0.09,0.055),Vector3(0,0.56,-0.155),art.GRAPHITE)
	for side in [-1,1]:
		art.beveled_box(head,Vector3(0.11,0.055,0.018),Vector3(side*0.075,0.565,-0.19),Color("#87a8a1"))
	art.beveled_box(head,Vector3(0.20,0.10,0.08),Vector3(0,0.43,-0.16),Color("#40514c"))
	for mesh in head.find_children("*","MeshInstance3D",true,false): mesh.layers=1<<19
	for side in [-1,1]:
		for index in 4:
			var limb=sphere(self,Vector3.ZERO,Vector3.ONE,Color("#3e5058") if index<2 else Color("#b88340"))
			segments.append(limb)
		boots.append(art.beveled_box(self,Vector3(0.20,0.14,0.33),Vector3.ZERO,art.GRAPHITE))
	_pose()

func sphere(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new()
	var mesh=SphereMesh.new()
	mesh.radius=0.5
	mesh.height=1
	mesh.radial_segments=24
	mesh.rings=12
	node.mesh=mesh
	node.position=at
	node.scale=dimensions
	node.material_override=art.material(color)
	parent.add_child(node)
	return node

func bone(node: Node3D, start: Vector3, end: Vector3, width: float) -> void:
	var direction=(end-start).normalized()
	node.transform=Transform3D(Basis(Quaternion(Vector3.UP,direction)).scaled(Vector3(width,start.distance_to(end)+width*0.25,width)),(start+end)*0.5)

func _pose() -> void:
	torso.position=Vector3(0,lerpf(1.16,1.35,seated),0.08)
	for side_index in 2:
		var side: float=-1 if side_index==0 else 1
		var hip=Vector3(side*0.15,lerpf(0.9,1.05,seated),0.08)
		var knee=Vector3(side*0.17,lerpf(0.48,0.95,seated),lerpf(-0.02,-0.42,seated))
		var foot=Vector3(side*0.17,lerpf(0.08,0.62,seated),lerpf(-0.05,-0.65,seated))
		var shoulder=torso.position+Vector3(side*0.24,0.15,0)
		var elbow=Vector3(side*0.29,lerpf(1.02,1.42,seated),lerpf(0.02,-0.02,seated))
		var hand=Vector3(side*0.20,lerpf(0.85,1.40,seated),lerpf(-0.08,-0.24,seated))
		if seated<0.1 and not scooter_pose:
			var stride: float=sin(gait_phase+side_index*PI)*gait_amount
			foot.z+=stride*0.26
			foot.y+=maxf(0,stride)*0.12
			knee.z+=stride*0.13
			hand.z-=stride*0.15
		if scooter_pose:
			foot=Vector3(side*0.085,0.08,side*0.21)
			knee=Vector3(side*0.12,0.46,side*0.12)
			elbow=Vector3(side*0.30,1.20,-0.25)
			hand=Vector3(side*0.385,1.256,-0.833)
		if skate_pose:
			torso.rotation.y=0.65
			torso.position.y=1.08
			hip.x=side*0.12
			knee=Vector3(side*0.09,0.45,side*0.23)
			foot=Vector3(0,0.07,side*0.28)
			hand=Vector3(side*0.36,0.96,side*0.12)
			if side_index==1:
				foot.y-=skate_push*0.07
				foot.x+=skate_push*0.25
				foot.z+=skate_push*0.40
		if bike_pose:
			hand=Vector3(side*0.38,1.39,-0.63)
			elbow=Vector3(side*0.35,1.35,-0.22)
			knee=Vector3(side*0.26,0.82,-0.18)
			foot=Vector3(side*0.30,0.5,0.08)
		bone(segments[side_index*4],hip,knee,0.18)
		bone(segments[side_index*4+1],knee,foot,0.145)
		bone(segments[side_index*4+2],shoulder,elbow,0.14)
		bone(segments[side_index*4+3],elbow,hand,0.12)
		boots[side_index].position=foot
