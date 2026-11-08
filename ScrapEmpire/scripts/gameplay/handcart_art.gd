extends RefCounted
static func build(root: Node3D, art) -> Array[Node3D]:
	var wheels: Array[Node3D]=[]
	art.box(root,Vector3(1,0.1,1.3),Vector3(0,0.4,0),art.STEEL)
	for side in [-1,1]:
		art.box(root,Vector3(0.06,0.4,1.3),Vector3(side*0.48,0.65,0),art.MINT)
		art.box(root,Vector3(0.06,0.06,1.2),Vector3(side*0.35,0.85,-1),art.YELLOW).rotation.x=0.25
		var wheel=art.cylinder(root,0.28,0.12,Vector3(side*0.58,0.28,0.2),art.GRAPHITE,24)
		wheel.rotation.z=PI/2
		wheels.append(wheel)
	art.box(root,Vector3(1,0.4,0.06),Vector3(0,0.65,0.62),art.MINT)
	art.box(root,Vector3(1,0.4,0.06),Vector3(0,0.65,-0.62),art.MINT)
	art.box(root,Vector3(0.75,0.08,0.08),Vector3(0,1,-1.55),art.GRAPHITE)
	return wheels
