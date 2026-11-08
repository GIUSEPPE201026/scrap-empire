extends RefCounted

# Inactive fragments stay batched; each has a stable identity and can be dragged.
static func build(body: Node3D, zone: int, random: RandomNumberGenerator, art: RefCounted, height_at: Callable, spread: float = 6.5) -> void:
	var theme: int = zone % 6
	var plate = _bent_sheet()
	var rock = _stone_mesh()
	var tyre = TorusMesh.new()
	tyre.inner_radius = 0.22
	tyre.outer_radius = 0.42
	tyre.rings = 32
	tyre.ring_segments = 12
	var can = CylinderMesh.new()
	can.top_radius = 0.23
	can.bottom_radius = 0.28
	can.height = 0.7
	can.radial_segments = 24
	can.rings = 1
	var brick = BoxMesh.new()
	brick.size = Vector3(0.75, 0.32, 0.45)
	var beam = _beam_mesh()
	var tube = _tube_mesh()
	var palettes = [
		[Color("#98613f"), Color("#707d7e"), Color("#c7ae87")],
		[Color("#5b9c99"), Color("#ba8656"), Color("#c7b966")],
		[Color("#815e49"), Color("#87999c"), Color("#566875")],
		[Color("#a3947e"), Color("#c9bda5"), Color("#82796d")],
		[Color("#78614d"), Color("#869697"), Color("#4b5c60")],
		[Color("#475659"), Color("#74918b"), Color("#b88d52")]
	]
	var palette: Array = palettes[theme]
	var lod = preload("res://scripts/gameplay/heap_lod.gd").new()
	lod.name="HeapDetailLOD"
	body.add_child(lod)
	var types = [
		{"mesh":rock, "count":85 if theme == 3 else 48, "color":palette[2], "size":Vector3(1.2, 0.6, 1.0)},
		{"mesh":plate, "count":80 if theme in [0, 2, 4] else 40, "color":palette[0], "size":Vector3(1.1, 0.7, 1.1)},
		{"mesh":plate, "count":65, "color":palette[1], "size":Vector3(0.8, 0.6, 0.9)},
		{"mesh":brick, "count":65 if theme == 3 else 25, "color":palette[2], "size":Vector3.ONE},
		{"mesh":can, "count":55 if theme == 1 else 12, "color":palette[0], "size":Vector3.ONE},
		{"mesh":tube, "count":38 if theme == 4 else 16, "color":Color("#7b8585"), "size":Vector3.ONE},
		{"mesh":tyre, "count":24 if theme == 2 else 8, "color":Color("#303a3b"), "size":Vector3.ONE},
		{"mesh":beam, "count":22 if theme in [0, 4] else 8, "color":Color("#695344"), "size":Vector3(0.8, 0.8, 1.5)}
	]
	for spec in types:
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = spec.mesh
		var count: int = int(spec.count*maxf(1.6,pow(spread/6.5,2.0)))
		multimesh.instance_count = count
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		var family: String = "rubble" if spec.mesh == rock or spec.mesh == brick else ("rubber" if spec.mesh == tyre else ("plastic" if spec.mesh == can else "steel"))
		var material = art.surface_material(spec.color,family).duplicate()
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		batch.material_override = material
		body.add_child(batch)
		lod.register(batch)
		for index in count:
			var angle: float = random.randf_range(0, TAU)
			var radius: float = sqrt(random.randf()) * spread
			var location = Vector3(cos(angle) * radius, height_at.call(radius,angle), sin(angle) * radius)
			location.y += random.randf_range(0.05, 0.2)
			var scale_value: Vector3 = spec.size * random.randf_range(0.65, 1.4)
			# Tangent support follows the pile slope instead of floating horizontal debris.
			var h: float = float(height_at.call(radius,angle))
			var hx: float = float(height_at.call(Vector2(location.x+0.15,location.z).length(),atan2(location.z,location.x+0.15)))
			var hz: float = float(height_at.call(Vector2(location.x,location.z+0.15).length(),atan2(location.z+0.15,location.x)))
			var normal: Vector3 = Vector3((h-hx)/0.15,1,(h-hz)/0.15).normalized()
			var tangent: Vector3 = Vector3(cos(angle),0,sin(angle)).slide(normal).normalized()
			var orientation = Basis.looking_at(tangent,normal)*Basis.from_euler(Vector3(random.randf_range(-0.18,0.18),random.randf_range(-PI,PI),random.randf_range(-0.18,0.18)))
			location.y -= 0.08
			multimesh.set_instance_transform(index, Transform3D(orientation.scaled(scale_value), location))
			multimesh.set_instance_color(index, Color.WHITE.darkened(random.randf_range(0, 0.23)))
		# Highest surface fragments are removed first as layers are recovered.
		var sorted: Array[Transform3D] = []
		for index in count:
			sorted.append(multimesh.get_instance_transform(index))
		sorted.sort_custom(func(a: Transform3D,b: Transform3D):return a.origin.y<b.origin.y)
		for index in count:
			multimesh.set_instance_transform(index,sorted[index])
	var extra_begin: int=body.get_child_count()
	# Elementi leggibili che danno una silhouette diversa alle sei famiglie.
	if theme == 1:
		for index in 4:
			var point = Vector3(-1.8+index,0,-0.8)
			point.y = height_at.call(Vector2(point.x,point.z).length(),atan2(point.z,point.x))+0.25
			var drum = art.cylinder(body, 0.42, 0.95, point, palette[index % 3], 24)
			drum.rotation = Vector3(0.4, index * 0.7, 0.8)
	elif theme == 5:
		for index in 4:
			var location = Vector3(-1.5 + index * 0.9, 0, -0.9)
			location.y = height_at.call(Vector2(location.x,location.z).length(),atan2(location.z,location.x))+0.15
			art.box(body, Vector3(0.7, 0.6, 0.4), location, palette[0]).rotation.z = -0.3
			art.box(body, Vector3(0.55, 0.4, 0.03), location + Vector3(0, 0, 0.22), Color("#19272a")).rotation.z = -0.3
	elif theme == 3:
		for index in 3:
			var location = Vector3(index-1,0,-0.6)
			location.y = height_at.call(Vector2(location.x,location.z).length(),atan2(location.z,location.x))+0.1
			art.box(body, Vector3(2.5, 0.3, 0.6), location, palette[index]).rotation = Vector3(0.1, index * 0.8, 0.4)
	if theme in [2, 4]:
		art.car(body, Vector3(0.3, height_at.call(0.67,atan2(-0.6,0.3))-0.65, -0.6), palette[0], 0.25)

	var extras: Array=[]
	for index in range(extra_begin,body.get_child_count()):
		if body.get_child(index) is Node3D: extras.append(body.get_child(index))
	var fragments=preload("res://scripts/gameplay/heap_fragments.gd").new()
	fragments.owner_pile=body
	body.add_child(fragments)
	var serial: int=0
	for batch in lod.batches:
		fragments.register_batch(batch,serial)
		serial+=1
	for index in extras.size(): fragments.register_extra(extras[index],index)

static func _bent_sheet() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 10:
		for row in 3:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var x: float = (column+corner.x)/10.0-0.5
				var z: float = (row+corner.y)/3.0-0.5
				var bend: float = sin(x*PI)*0.08 + cos(x*TAU*5)*0.025 + z*z*0.12
				surface.add_vertex(Vector3(x,bend,z))
	surface.index()
	surface.generate_normals()
	return surface.commit()

static func _stone_mesh() -> ArrayMesh:
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.8
	sphere.radial_segments = 12
	sphere.rings = 6
	var arrays = sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size():
		var point: Vector3 = vertices[index]
		var uneven: float = 1 + sin(point.x*15+point.y*8)*0.12 + cos(point.z*13-point.y*4)*0.08
		point *= uneven
		point.y = maxf(-0.28,point.y)
		vertices[index] = point
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

static func _beam_mesh() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spec in [[Vector3(0.22, 0.04, 1.5), Vector3(0, 0.14, 0)], [Vector3(0.22, 0.04, 1.5), Vector3(0, -0.14, 0)], [Vector3(0.04, 0.28, 1.5), Vector3.ZERO]]:
		var mesh = BoxMesh.new()
		mesh.size = spec[0]
		surface.append_from(mesh, 0, Transform3D(Basis.IDENTITY, spec[1]))
	return surface.commit()

static func _tube_mesh() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 24:
		var a: float = index * TAU / 24
		var b: float = (index + 1) * TAU / 24
		for radius in [0.16, 0.105]:
			var p = Vector3(cos(a) * radius, -0.6, sin(a) * radius)
			var q = Vector3(cos(b) * radius, -0.6, sin(b) * radius)
			for vertex in [p, q, p + Vector3.UP * 1.2, q, q + Vector3.UP * 1.2, p + Vector3.UP * 1.2]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
