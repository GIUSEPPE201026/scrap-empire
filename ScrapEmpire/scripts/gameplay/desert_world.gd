extends RefCounted
const HALF_EXTENT: float=640.0

static func height_at(location: Vector3) -> float:
	var distance: float = maxf(absf(location.x), absf(location.z))
	var blend: float = smoothstep(83.0, 110.0, distance)
	var lot_distance: float = maxf(maxf(80 - location.x, location.x - 260), maxf(-72 - location.z, location.z - 20))
	blend *= smoothstep(0.0, 18.0, lot_distance)
	var rolling: float = 5.5 + sin(location.x * 0.045 + location.z * 0.025) * 3.0 + sin(location.z * 0.07) * 2.0
	var height: float=blend*rolling
	var park: float=Vector2(location.x+230,location.z+175).length()
	height=lerpf(4.0,height,smoothstep(64.0,90.0,park))
	var oasis: float=Vector2(location.x-260,location.z-320).length()
	var shore: float=1.0+2.0*smoothstep(10.0,23.0,oasis)
	var ridge: float=(12.0*smoothstep(500.0,590.0,distance)+55.0*smoothstep(600.0,640.0,distance))*(0.9+0.13*sin(location.x*0.031)+0.08*sin(location.z*0.047))
	return lerpf(shore,height,smoothstep(32.0,60.0,oasis))+ridge

static func build(root: Node3D) -> void:
	var surface = SurfaceTool.new()
	var collision_faces = PackedVector3Array()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 256:
		for column in 256:
			var origin = Vector3(-HALF_EXTENT + column * 5, 0, -HALF_EXTENT + row * 5)
			if preload("res://scripts/gameplay/subterranean_cave.gd").cuts_cell(origin): continue
			for offset in [Vector3.ZERO, Vector3(0, 0, 5), Vector3(5, 0, 0), Vector3(5, 0, 0), Vector3(0, 0, 5), Vector3(5, 0, 5)]:
				var point: Vector3 = origin + offset
				point.y = height_at(point) - 0.03
				collision_faces.append(point)
				surface.add_vertex(point)
	surface.index()
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var body = StaticBody3D.new()
	body.name = "DesertTerrain"
	body.add_to_group("desert_terrain")
	var shape = CollisionShape3D.new()
	var terrain_shape = ConcavePolygonShape3D.new()
	terrain_shape.set_faces(collision_faces)
	terrain_shape.backface_collision = true
	shape.shape = terrain_shape
	body.add_child(shape)
	root.add_child(body)
	if DisplayServer.get_name() != "headless":
		var visual = MeshInstance3D.new()
		visual.mesh = mesh
		var material = ShaderMaterial.new()
		material.shader = preload("res://assets/materials/yard_ground.gdshader")
		material.set_shader_parameter("sand_detail", load("res://assets/textures/surfaces/sand_albedo.png"))
		visual.material_override = material
		body.add_child(visual)
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	if DisplayServer.get_name() != "headless":
		art.sign_text(root, "DUNE ESTERNE\nESPLORA · RITORNA ALLA BASE", Vector3(0, 3, 86), 65, true)
		for side in [-1, 1]:
			art.box(root, Vector3(0.1, 4, 0.1), Vector3(side * 7, 2, 80), art.GRAPHITE)
			var flag = MeshInstance3D.new()
			var cloth = QuadMesh.new()
			cloth.size = Vector2(1.5, 0.7)
			flag.mesh = cloth
			flag.position = Vector3(side * 7 + 0.75, 3.6, 80)
			var fabric = ShaderMaterial.new()
			fabric.shader = preload("res://assets/materials/wind_flag.gdshader")
			flag.material_override = fabric
			root.add_child(flag)
