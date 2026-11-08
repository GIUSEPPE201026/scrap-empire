extends Node3D
const SQUARE = Vector3(-48,0,34)
const PROJECTS = ["town_square","workshop_relaunch","neighborhood_gardens"]
var _signature: String = ""
var _art_root: Node3D

func _ready() -> void:
	add_to_group("town_projects")
	GameState.operations_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var history: Dictionary = GameState.operations.get("delivery_history",{})
	var completed: Array = PROJECTS.filter(func(id):return int(history.get(id,0))>0)
	var signature: String = str(completed)
	if signature==_signature:
		return
	_signature=signature
	set_meta("completed_projects",completed)
	if _art_root!=null:
		remove_child(_art_root)
		_art_root.queue_free()
	_art_root=Node3D.new()
	add_child(_art_root)
	if DisplayServer.get_name()=="headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	if "town_square" in completed or "neighborhood_gardens" in completed:
		art.box(_art_root,Vector3(10,0.035,8),SQUARE+Vector3(0,0.025,0),Color("#a89c82"))
		for side in [-1,1]:
			art.box(_art_root,Vector3(10,0.08,0.12),SQUARE+Vector3(0,0.06,side*4),art.STEEL)
		var sign = art.sign_text(_art_root,"PIAZZA DEL RIUSO\nRECUPERI DEL QUARTIERE",SQUARE+Vector3(0,2.2,3.65),36)
		sign.rotation.y=PI
		sign.pixel_size=0.0045
		art.box(_art_root,Vector3(3.8,0.9,0.12),SQUARE+Vector3(0,2.2,3.73),art.GRAPHITE)
		for side in [-1,1]:
			art.box(_art_root,Vector3(0.08,2.6,0.08),SQUARE+Vector3(side*1.6,1.3,3.7),art.STEEL)
	if "town_square" in completed:
		for offset in [Vector3(-4,0,-3),Vector3(4,0,-3),Vector3(0,0,3)]:
			var point: Vector3 = SQUARE+offset
			art.cylinder(_art_root,0.07,2.8,point+Vector3.UP*1.4,art.STEEL,20)
			art.beveled_box(_art_root,Vector3(0.5,0.13,0.4),point+Vector3.UP*2.8,art.YELLOW)
			var light = OmniLight3D.new()
			light.position=point+Vector3.UP*2.6
			light.omni_range=7
			light.light_energy=0.8
			light.light_color=Color("#ffe0a4")
			_art_root.add_child(light)
		var table = Node3D.new()
		table.position=SQUARE+Vector3(-2,0,-2)
		_art_root.add_child(table)
		art.box(table,Vector3(1.1,0.08,0.7),Vector3(0,0.9,0),art.STEEL)
		for side in [-1,1]:
			for depth in [-1,1]:
				art.box(table,Vector3(0.07,0.9,0.07),Vector3(side*0.46,0.45,depth*0.26),art.GRAPHITE)
		var radio = Node3D.new()
		radio.position.y=0.95
		table.add_child(radio)
		preload("res://scripts/gameplay/product_models.gd").build(radio,"restored_radio")
	if "neighborhood_gardens" in completed:
		for spec in [Vector3(-3,0,0),Vector3(3,0,0),Vector3(0,0,2.4)]:
			var bench = Node3D.new()
			bench.position=SQUARE+spec
			_art_root.add_child(bench)
			preload("res://scripts/gameplay/product_models.gd").build(bench,"garden_bench")
			_obstacle(bench,Vector3(1.4,1.05,0.65),Vector3(0,0.55,0))
		for side in [-1,1]:
			for depth in [-2,2]:
				var point: Vector3 = SQUARE+Vector3(side*4,0,depth)
				art.beveled_box(_art_root,Vector3(0.7,0.55,0.7),point+Vector3.UP*0.28,Color("#a06443"))
				for leaf in 4:
					var canopy = MeshInstance3D.new()
					var mesh = SphereMesh.new()
					mesh.radius=0.26
					mesh.height=0.5
					mesh.radial_segments=16
					mesh.rings=8
					canopy.mesh=mesh
					canopy.position=point+Vector3(sin(leaf*2.3)*0.18,0.6+leaf*0.1,cos(leaf*2.3)*0.18)
					canopy.material_override=art.material(Color("#738d58").lightened(leaf*0.03))
					_art_root.add_child(canopy)
	if "workshop_relaunch" in completed:
		var compressor = Node3D.new()
		compressor.position=Vector3(-0.8,0.12,24.3)
		_art_root.add_child(compressor)
		preload("res://scripts/gameplay/product_models.gd").build(compressor,"bench_compressor")
		_obstacle(compressor,Vector3(0.9,0.8,0.7),Vector3(0,0.4,0))
		var label = art.sign_text(compressor,"RICOSTRUITO A RIVA SECCA",Vector3(0,1.1,0),18,true)
		label.pixel_size=0.002

func _obstacle(parent: Node3D, size: Vector3, point: Vector3) -> void:
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=size
	shape.position=point
	body.add_child(shape)
	parent.add_child(body)
