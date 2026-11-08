extends RefCounted
## One layout supplies both geometry and collision. All four gates are real.
static func build(root: Node3D) -> void:
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var fence=Node3D.new()
	fence.name="YardFence"
	root.add_child(fence)
	for orientation in 2:
		for side in [-1,1]:
			for half in [-1,1]:
				var body=StaticBody3D.new()
				var center=Vector3(half*44,1.3,side*80) if orientation==0 else Vector3(side*80,1.3,half*44)
				body.position=center
				var shape=CollisionShape3D.new()
				shape.shape=BoxShape3D.new()
				shape.shape.size=Vector3(72,2.6,0.12) if orientation==0 else Vector3(0.12,2.6,72)
				body.add_child(shape)
				body.add_to_group("yard_fence")
				fence.add_child(body)
				if DisplayServer.get_name()=="headless":
					continue
				for index in 25:
					var distance: float=-36+index*3
					var point=Vector3(distance,0,0) if orientation==0 else Vector3(0,0,distance)
					art.box(body,Vector3(0.12,2.6,0.12),point,art.GRAPHITE)
					if index<24:
						var tint: Color=[art.STEEL.darkened(0.2),art.RUST,Color("#647569")][(index+half+3)%3]
						art.box(body,Vector3(2.95,1.8,0.09) if orientation==0 else Vector3(0.09,1.8,2.95),point+(Vector3(1.5,-0.25,0) if orientation==0 else Vector3(0,-0.25,1.5)),tint,true)
						if index%4==0:
							var direction=Vector3(2.7,1.6,0) if orientation==0 else Vector3(0,1.6,2.7)
							art.beam(body,point+Vector3(0,-1,0),point+Vector3(0,-1,0)+direction,0.06,art.GRAPHITE)
				for height in [0.3,0.8,1.2]:
					art.box(body,Vector3(72,0.035,0.035) if orientation==0 else Vector3(0.035,0.035,72),Vector3(0,height,0),art.STEEL)
	_entrance(fence,art)

static func _entrance(root: Node3D, art) -> void:
	for side in [-1,1]:
		var column=StaticBody3D.new()
		column.position=Vector3(side*9.5,3.3,80)
		var shape=CollisionShape3D.new()
		shape.shape=BoxShape3D.new()
		shape.shape.size=Vector3(1.2,6.6,1.2)
		column.add_child(shape)
		root.add_child(column)
		if DisplayServer.get_name()=="headless": continue
		art.beveled_box(column,Vector3(1.2,6.6,1.2),Vector3.ZERO,art.GRAPHITE,true)
		art.box(column,Vector3(1.3,0.7,1.3),Vector3(0,-2.9,0),art.STEEL)
		for stripe in 5:
			art.box(column,Vector3(1.23,0.22,0.035),Vector3(0,-1.8+stripe*0.45,0.62),art.YELLOW)
		art.beam(root,Vector3(side*9.5,5.6,80),Vector3(side*6.5,6.7,80),0.18,art.RUST)
		for index in 4:
			art.cylinder(root,0.45,0.22,Vector3(side*(12+index*0.3),0.12+index*0.2,78),art.GRAPHITE,24).rotation.z=index*0.07
	if DisplayServer.get_name()=="headless": return
	art.beveled_box(root,Vector3(20,0.7,1),Vector3(0,6.6,80),art.RUST,true)
	art.sign_text(root,"RECUPERO  /  OFFICINA  /  RIVA SECCA",Vector3(0,6.65,80.57),28)
	for index in 16:
		var at=Vector3(0,0,60+index*3)
		at.y=preload("res://scripts/gameplay/desert_world.gd").height_at(at)+0.04
		art.box(root,Vector3(0.12,0.02,1.5),at,art.YELLOW)
		for side in [-1,1]:
			art.box(root,Vector3(0.12,0.04,2.3),at+Vector3(side*6.5,0,0),Color("#e8d6a7"))
