extends RefCounted
## Reusable yard modules, with separate solids so shelters remain walkable.
const KINDS=["yard_wall","yard_canopy","yard_platform"]

static func footprint(kind: String) -> Vector3:
	return {"yard_wall":Vector3(3,2.2,0.22),"yard_canopy":Vector3(3.2,2.8,3.2),"yard_platform":Vector3(3,0.4,3)}.get(kind,Vector3.ONE)

static func build(parent: Node3D, kind: String) -> void:
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var solids: Array=[]
	if kind=="yard_wall":
		solids=[[Vector3(3,2.2,0.22),Vector3(0,1.1,0),art.MINT]]
	elif kind=="yard_platform":
		solids=[[Vector3(3,0.4,3),Vector3(0,0.2,0),art.STEEL]]
	else:
		solids.append([Vector3(3.2,0.16,3.2),Vector3(0,2.72,0),art.RUST])
		for x in [-1.45,1.45]:
			for z in [-1.45,1.45]: solids.append([Vector3(0.12,2.65,0.12),Vector3(x,1.325,z),art.STEEL])
	for solid in solids:
		var collision=CollisionShape3D.new()
		collision.shape=BoxShape3D.new()
		collision.shape.size=solid[0]
		collision.position=solid[1]
		parent.add_child(collision)
		if DisplayServer.get_name()!="headless": art.beveled_box(parent,solid[0],solid[1],solid[2],true)
	if DisplayServer.get_name()=="headless": return
	if kind=="yard_wall":
		for index in 15: art.box(parent,Vector3(0.055,2.1,0.045),Vector3(-1.4+index*0.2,1.1,-0.135),art.STEEL)
	elif kind=="yard_platform":
		for side in [-1,1]: art.box(parent,Vector3(2.9,0.025,0.09),Vector3(0,0.412,side*1.4),art.YELLOW)
	else:
		for z in [-1.4,0,1.4]: art.beam(parent,Vector3(-1.45,2.56,z),Vector3(1.45,2.56,z),0.09,art.GRAPHITE)
		var light=OmniLight3D.new()
		light.position=Vector3(0,2.4,0)
		light.light_energy=1.8
		light.omni_range=7
		light.light_color=Color("#ffe0ac")
		parent.add_child(light)
