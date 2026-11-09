extends RefCounted

static func build(root: Node3D, kind: String) -> void:
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	match kind:
		"battery_pack":
			art.beveled_box(root,Vector3(0.55,0.42,0.32),Vector3(0,0.23,0),art.MINT,true)
			art.box(root,Vector3(0.57,0.07,0.34),Vector3(0,0.47,0),art.GRAPHITE)
			for side in [-1,1]:
				art.cylinder(root,0.035,0.07,Vector3(side*0.17,0.54,0),art.YELLOW,12)
				art.beam(root,Vector3(side*0.12,0.51,0.1),Vector3(side*0.12,0.65,0.1),0.025,art.GRAPHITE)
			art.beam(root,Vector3(-0.12,0.65,0.1),Vector3(0.12,0.65,0.1),0.025,art.GRAPHITE)
			art.box(root,Vector3(0.22,0.14,0.015),Vector3(0,0.26,-0.17),art.GRAPHITE)
			art.box(root,Vector3(0.12,0.045,0.018),Vector3(0,0.26,-0.18),art.YELLOW)
		"restored_radio":
			art.beveled_box(root,Vector3(0.65,0.38,0.24),Vector3(0,0.2,0),Color("#b37d4c"))
			art.box(root,Vector3(0.32,0.24,0.015),Vector3(-0.11,0.22,-0.13),art.GRAPHITE)
			for index in 5:
				art.box(root,Vector3(0.025,0.19,0.02),Vector3(-0.24+index*0.065,0.22,-0.145),art.STEEL)
			art.box(root,Vector3(0.17,0.06,0.025),Vector3(0.2,0.28,-0.14),art.MINT)
			for side in [-1,1]:
				var dial = art.cylinder(root,0.035,0.035,Vector3(0.2+side*0.05,0.14,-0.15),art.GRAPHITE,20)
				dial.rotation.x=PI/2
			art.beam(root,Vector3(0.24,0.38,0),Vector3(0.32,0.86,0),0.013,art.STEEL)
		"bench_compressor":
			var tank = art.cylinder(root,0.23,0.72,Vector3(0,0.28,0),art.MINT,28)
			tank.rotation.z=PI/2
			art.beveled_box(root,Vector3(0.36,0.25,0.28),Vector3(0,0.58,0),art.GRAPHITE)
			for side in [-1,1]:
				art.beam(root,Vector3(side*0.25,0.2,0),Vector3(side*0.25,0.05,0),0.09,art.STEEL)
			art.beam(root,Vector3(0.32,0.42,0),Vector3(0.5,0.72,0),0.04,art.YELLOW)
			art.beam(root,Vector3(0.5,0.72,0),Vector3(0.5,0.72,-0.25),0.04,art.GRAPHITE)
			var dial = art.cylinder(root,0.065,0.03,Vector3(-0.18,0.64,-0.16),Color("#e8e3cb"),24)
			dial.rotation.x=PI/2
		"garden_bench":
			for index in 4:
				art.beveled_box(root,Vector3(1.35,0.07,0.11),Vector3(0,0.48,-0.2+index*0.13),Color("#618f78"))
			for side in [-1,1]:
				art.beam(root,Vector3(side*0.5,0.04,0.12),Vector3(side*0.5,0.9,0.2),0.07,art.GRAPHITE)
				art.beam(root,Vector3(side*0.5,0.04,-0.2),Vector3(side*0.5,0.48,-0.2),0.07,art.GRAPHITE)
			for index in 3:
				art.beveled_box(root,Vector3(1.35,0.1,0.06),Vector3(0,0.65+index*0.13,0.2),Color("#618f78"))
		"desk_lamp":
			art.cylinder(root,0.18,0.05,Vector3.ZERO,art.GRAPHITE,24)
			art.beam(root,Vector3.ZERO,Vector3(0.12,0.4,0),0.04,art.STEEL)
			art.cylinder(root,0.16,0.13,Vector3(0.12,0.4,0),art.YELLOW,24)
		_:
			art.beveled_box(root,Vector3(0.5,0.25,0.3),Vector3(0,0.13,0),art.MINT)
			art.box(root,Vector3(0.22,0.04,0.05),Vector3(0,0.3,0),art.GRAPHITE)
