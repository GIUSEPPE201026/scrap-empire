extends RefCounted
## Thirty-five original salvage silhouettes. Family still determines mass and yield.
const NAMES = [
	["Disco freno", "Radiatore", "Motore elettrico" , "Piastra forata", "Valvola idraulica"],
	["Tanica", "Cassetta in plastica", "Flacone industriale" , "Secchio", "Tubo PVC"],
	["Scheda di controllo", "Monitor danneggiato", "Alimentatore" , "Radio portatile", "Disco dati industriale"],
	["Bobina di rame", "Tubi flangiati", "Cablaggio" , "Trasformatore", "Scambiatore"],
	["Lattina", "Profilo estruso", "Condotto di alluminio" , "Pentola", "Dissipatore"],
	["Bottiglia", "Vetro di fanale", "Isolatore in vetro" , "Lente ottica", "Vaso tecnico"],
	["Pneumatico", "Tubo flessibile", "Nastro di gomma" , "Guarnizione", "Cinghia dentata"]
]

static func variant_for(id: String) -> int:
	return 4 if id.get_slice("_",1).to_int()%12==11 else absi(id.hash())%4

static func item_name(type: int, variant: int) -> String:
	return Localization.text(NAMES[type][variant] if type < NAMES.size() else "Rottame")

static func build(root: Node3D, type: int, variant: int, art) -> void:
	var steel = art.STEEL
	var dark = art.GRAPHITE
	var copper = Color("#bd794f")
	var plastic: Color = [Color("#5c9baf"), Color("#d4a64b"), Color("#77ab9b")][variant%3]
	if variant >= 3:
		_special(root,type,variant,art)
		return
	match type:
		0:
			if variant == 0:
				art.cylinder(root,0.36,0.07,Vector3(0,0.05,0),steel,32)
				art.cylinder(root,0.16,0.15,Vector3(0,0.13,0),art.RUST,24)
				for index in 8:
					var a: float = index * TAU / 8
					art.cylinder(root,0.026,0.012,Vector3(cos(a)*0.27,0.092,sin(a)*0.27),dark,16)
			elif variant == 1:
				_piece(root,Vector3(0.82,0.08,0.55),Vector3(0,0.06,0),steel,art)
				for index in 11:
					art.box(root,Vector3(0.025,0.19,0.5),Vector3(-0.35+index*0.07,0.15,0),steel.darkened(0.15))
				for side in [-1,1]:
					art.cylinder(root,0.05,0.58,Vector3(side*0.4,0.13,0),art.RUST,24).rotation.x = PI/2
			else:
				art.cylinder(root,0.24,0.52,Vector3(0,0.25,0),dark,32).rotation.x = PI/2
				for index in 6:
					art.cylinder(root,0.26,0.025,Vector3(0,0.25,-0.22+index*0.08),steel,24).rotation.x = PI/2
				_piece(root,Vector3(0.6,0.07,0.55),Vector3(0,0.04,0),art.RUST,art)
		1:
			if variant == 0:
				_piece(root,Vector3(0.5,0.53,0.32),Vector3(0,0.28,0),plastic,art,"plastic")
				for side in [-1,1]:
					_piece(root,Vector3(0.06,0.15,0.1),Vector3(side*0.12,0.6,0),plastic,art,"plastic")
				_piece(root,Vector3(0.3,0.055,0.1),Vector3(0,0.66,0),plastic,art,"plastic")
				art.cylinder(root,0.07,0.055,Vector3(0.16,0.58,0),dark,24)
				_label(root,Vector3(0,0.29,-0.169),Vector3(0.24,0.19,0.008),art)
			elif variant == 1:
				_piece(root,Vector3(0.74,0.055,0.52),Vector3(0,0.04,0),plastic,art,"plastic")
				for side in [-1,1]:
					for index in 5:
						art.box(root,Vector3(0.055,0.3,0.045),Vector3(-0.32+index*0.16,0.2,side*0.24),plastic)
					_piece(root,Vector3(0.75,0.07,0.055),Vector3(0,0.36,side*0.24),plastic,art,"plastic")
					for index in 3:
						art.box(root,Vector3(0.055,0.3,0.05),Vector3(side*0.35,0.2,-0.16+index*0.16),plastic)
			else:
				art.cylinder(root,0.2,0.48,Vector3(0,0.27,0),plastic,32)
				art.cylinder(root,0.13,0.12,Vector3(0,0.55,0),plastic,32)
				art.cylinder(root,0.1,0.08,Vector3(0,0.65,0),dark,24)
				_label(root,Vector3(0,0.26,-0.202),Vector3(0.25,0.22,0.006),art)
		2:
			if variant == 0:
				_piece(root,Vector3(0.78,0.045,0.53),Vector3(0,0.04,0),Color("#356e5b"),art,"plastic")
				for index in 3:
					_piece(root,Vector3(0.16,0.07,0.23),Vector3(-0.24+index*0.23,0.1,0),dark,art)
					art.cylinder(root,0.04,0.14,Vector3(-0.24+index*0.23,0.12,0.18),steel,24)
				for index in 12:
					art.box(root,Vector3(0.025,0.01,0.07),Vector3(-0.3+index*0.052,0.066,-0.21),art.YELLOW)
			elif variant == 1:
				_piece(root,Vector3(0.72,0.5,0.16),Vector3(0,0.37,0),dark,art,"plastic")
				_piece(root,Vector3(0.63,0.39,0.012),Vector3(0,0.39,-0.087),Color("#455e63"),art,"plastic")
				art.beam(root,Vector3(-0.27,0.52,-0.096),Vector3(0.1,0.27,-0.096),0.008,steel)
				_piece(root,Vector3(0.14,0.14,0.12),Vector3(0,0.1,0),dark,art)
				_piece(root,Vector3(0.4,0.03,0.28),Vector3(0,0.025,0),dark,art)
			else:
				_piece(root,Vector3(0.57,0.34,0.46),Vector3(0,0.19,0),steel,art)
				for index in 7:
					art.box(root,Vector3(0.015,0.2,0.008),Vector3(-0.22+index*0.07,0.2,-0.237),dark)
				art.cylinder(root,0.12,0.02,Vector3(0,0.19,0.245),dark,32).rotation.x = PI/2
				_label(root,Vector3(0,0.368,0),Vector3(0.25,0.005,0.2),art)
		3:
			if variant == 0:
				for index in 4:
					_ring(root,0.13+index*0.04,0.16+index*0.04,Vector3(0,0.05+index*0.045,0),copper,art)
			elif variant == 1:
				for side in [-1,1]:
					art.cylinder(root,0.065,0.7,Vector3(side*0.12,0.09,0),copper,24).rotation.x = PI/2
					for z in [-0.34,0.34]:
						art.cylinder(root,0.115,0.035,Vector3(side*0.12,0.09,z),copper,24).rotation.x = PI/2
			else:
				for index in 5:
					art.cylinder(root,0.025,0.64,Vector3(-0.15+index*0.07,0.045,0),copper,20).rotation.x = PI/2
				for z in [-0.2,0.2]:
					art.box(root,Vector3(0.4,0.045,0.04),Vector3(0,0.06,z),dark)
		4:
			if variant == 0:
				art.cylinder(root,0.14,0.4,Vector3(0,0.21,0),steel.lightened(0.25),32)
				for h in [0.015,0.41]:
					art.cylinder(root,0.145,0.025,Vector3(0,h,0),steel,32)
				_ring(root,0.025,0.045,Vector3(0,0.43,0),dark,art)
			elif variant == 1:
				for side in [-1,1]:
					art.box(root,Vector3(0.08,0.25,0.7),Vector3(side*0.21,0.15,0),steel.lightened(0.25))
				art.box(root,Vector3(0.47,0.05,0.7),Vector3(0,0.045,0),steel)
			else:
				art.cylinder(root,0.22,0.55,Vector3(0,0.23,0),steel,32).rotation.x = PI/2
				for z in [-0.26,0.26]:
					art.cylinder(root,0.24,0.035,Vector3(0,0.23,z),steel.lightened(0.2),32).rotation.x = PI/2
		5:
			var glass = Color("#76a997")
			if variant == 0:
				art.cylinder(root,0.15,0.4,Vector3(0,0.22,0),glass,32)
				art.cylinder(root,0.08,0.2,Vector3(0,0.51,0),glass,32)
				art.cylinder(root,0.09,0.025,Vector3(0,0.62,0),steel,24)
			elif variant == 1:
				_piece(root,Vector3(0.66,0.16,0.4),Vector3(0,0.1,0),steel,art)
				_piece(root,Vector3(0.56,0.025,0.3),Vector3(0,0.2,0),glass.lightened(0.1),art,"plastic")
				for index in 6:
					art.box(root,Vector3(0.018,0.008,0.29),Vector3(-0.22+index*0.09,0.22,0),glass)
			else:
				for layer in 4:
					art.cylinder(root,0.19-layer*0.025,0.07,Vector3(0,0.08+layer*0.1,0),glass,32)
				art.cylinder(root,0.055,0.42,Vector3(0,0.23,0),steel,24)
		6:
			if variant == 0:
				_ring(root,0.23,0.43,Vector3(0,0.16,0),dark,art)
				for index in 24:
					var a: float = index * TAU / 24
					art.box(root,Vector3(0.075,0.035,0.11),Vector3(cos(a)*0.38,0.26,sin(a)*0.38),dark.lightened(0.08)).rotation.y = -a
			elif variant == 1:
				for layer in 3:
					_ring(root,0.23,0.27,Vector3(0,0.04+layer*0.06,0),dark,art)
			else:
				for index in 4:
					_piece(root,Vector3(0.6,0.045,0.3),Vector3(index*0.02,0.04+index*0.055,0),dark,art,"rubber")

static func _piece(root: Node3D, size: Vector3, position: Vector3, color: Color, art, family: String = "steel") -> void:
	art.beveled_box(root,size,position,color).material_override = art.surface_material(color,family)

static func _ring(root: Node3D, inner: float, outer: float, position: Vector3, color: Color, art) -> void:
	var visual = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 32
	torus.ring_segments = 12
	visual.mesh = torus
	visual.position = position
	visual.material_override = art.surface_material(color,"rubber" if color.v < 0.3 else "steel")
	root.add_child(visual)

static func _label(root: Node3D, position: Vector3, size: Vector3, art) -> void:
	art.box(root,size,position,Color("#ddd8bf"))
static func _special(root: Node3D, type: int, variant: int, art) -> void:
	var colors: Array = [art.STEEL,art.MINT,art.GRAPHITE,Color("#bd794f"),art.STEEL,Color("#8bb6ba"),art.GRAPHITE]
	var color: Color = colors[type]
	if type == 2 and variant == 3:
		art.beveled_box(root,Vector3(0.62,0.34,0.22),Vector3(0,0.2,0),color)
		art.cylinder(root,0.12,0.025,Vector3(-0.14,0.2,-0.13),art.STEEL,24).rotation.x=PI/2
		art.box(root,Vector3(0.18,0.09,0.025),Vector3(0.15,0.26,-0.13),art.MINT)
		art.beam(root,Vector3(0.2,0.35,0),Vector3(0.35,0.85,0),0.014,art.STEEL)
	elif type == 2:
		art.beveled_box(root,Vector3(0.48,0.07,0.68),Vector3(0,0.06,0),art.GRAPHITE)
		art.cylinder(root,0.19,0.025,Vector3(0,0.12,-0.07),art.STEEL,32)
		art.beam(root,Vector3(0.17,0.14,0.24),Vector3(-0.08,0.14,-0.05),0.035,art.YELLOW)
	elif type == 0 and variant == 3:
		art.beveled_box(root,Vector3(0.7,0.05,0.5),Vector3(0,0.06,0),color)
		for x in [-0.23,0,0.23]:
			for z in [-0.14,0.14]:
				art.cylinder(root,0.065,0.007,Vector3(x,0.09,z),art.GRAPHITE,20)
	elif type == 0:
		art.cylinder(root,0.15,0.6,Vector3(0,0.2,0),color,24).rotation.z=PI/2
		art.cylinder(root,0.06,0.3,Vector3(0,0.35,0),color,20)
		_ring(root,0.16,0.21,Vector3(0,0.52,0),art.RUST,art)
		art.beam(root,Vector3(-0.18,0.52,0),Vector3(0.18,0.52,0),0.025,art.RUST)
	elif type == 1 and variant == 3:
		art.cylinder(root,0.25,0.38,Vector3(0,0.21,0),color,28)
		art.cylinder(root,0.23,0.008,Vector3(0,0.405,0),art.GRAPHITE,28)
		_ring(root,0.23,0.27,Vector3(0,0.42,0),color,art)
		for side in [-1,1]:
			art.beam(root,Vector3(side*0.25,0.32,0),Vector3(side*0.17,0.65,0),0.018,art.STEEL)
		art.beam(root,Vector3(-0.17,0.65,0),Vector3(0.17,0.65,0),0.018,art.STEEL)
	elif type == 1:
		for x in [-0.18,0,0.18]:
			art.cylinder(root,0.075,0.65,Vector3(x,0.1,0),Color("#d3d1b6"),24).rotation.x=PI/2
			art.cylinder(root,0.054,0.008,Vector3(x,0.1,-0.33),art.GRAPHITE,24).rotation.x=PI/2
	elif type == 3 and variant == 3:
		art.beveled_box(root,Vector3(0.6,0.35,0.42),Vector3(0,0.2,0),art.GRAPHITE)
		for x in [-0.18,0.18]:
			for i in 7:
				_ring(root,0.08,0.12,Vector3(x,0.1+i*0.04,0),color,art)
		art.box(root,Vector3(0.65,0.05,0.47),Vector3(0,0.4,0),art.STEEL)
	elif type == 3:
		for z in [-0.24,0.24]:
			art.cylinder(root,0.06,0.6,Vector3(0,0.14,z),color,24).rotation.z=PI/2
		for x in [-0.24,-0.12,0,0.12,0.24]:
			art.cylinder(root,0.035,0.5,Vector3(x,0.14,0),color,20).rotation.x=PI/2
	elif type == 4 and variant == 3:
		art.cylinder(root,0.27,0.23,Vector3(0,0.14,0),color,32)
		art.cylinder(root,0.24,0.008,Vector3(0,0.26,0),art.GRAPHITE,32)
		for x in [-1,1]:
			art.beam(root,Vector3(x*0.25,0.2,0),Vector3(x*0.42,0.2,0),0.045,art.GRAPHITE)
	elif type == 4:
		art.beveled_box(root,Vector3(0.58,0.08,0.42),Vector3(0,0.07,0),color)
		for i in 8:
			art.box(root,Vector3(0.018,0.22,0.4),Vector3(-0.24+i*0.067,0.2,0),color)
	elif type == 5 and variant == 3:
		_ring(root,0.22,0.27,Vector3(0,0.1,0),art.STEEL,art)
		art.cylinder(root,0.225,0.018,Vector3(0,0.1,0),Color("#93c7cb"),32)
	elif type == 5:
		art.cylinder(root,0.19,0.45,Vector3(0,0.25,0),Color("#96b6a3"),32)
		art.cylinder(root,0.21,0.05,Vector3(0,0.5,0),art.STEEL,28)
		art.box(root,Vector3(0.17,0.18,0.008),Vector3(0,0.26,-0.19),art.YELLOW)
	elif type == 6 and variant == 3:
		_ring(root,0.23,0.29,Vector3(0,0.04,0),art.GRAPHITE,art)
	else:
		var belt = Node3D.new()
		root.add_child(belt)
		belt.scale = Vector3(1,0.4,1.7)
		_ring(belt,0.23,0.29,Vector3(0,0.08,0),art.GRAPHITE,art)
		for i in 20:
			var a: float = i*TAU/20
			art.box(belt,Vector3(0.04,0.12,0.04),Vector3(cos(a)*0.23,0.08,sin(a)*0.23),art.GRAPHITE)


