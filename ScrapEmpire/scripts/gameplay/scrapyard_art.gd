extends RefCounted

const PAINT = preload("res://assets/materials/scrap_paint.gdshader")
const SAND = Color("#c79869")
const GRAPHITE = Color("#29343b")
const STEEL = Color("#8b9b9d")
const YELLOW = Color("#edb83c")
const MINT = Color("#68b5a4")
const RUST = Color("#864a32")
var materials: Dictionary = {}

func material(color: Color, worn: bool = false) -> Material:
	var key: String = color.to_html() + str(worn)
	if materials.has(key):
		return materials[key]
	var result: Material
	if worn:
		var painted = ShaderMaterial.new()
		painted.shader = PAINT
		painted.set_shader_parameter("paint_color", color)
		# Resolve after the editor has imported textures on a fresh clone.
		painted.set_shader_parameter("detail_map", load("res://assets/textures/surfaces/steel_albedo.png"))
		painted.set_shader_parameter("wear", 0.1)
		result = painted
	else:
		result = surface_material(color, "rubber" if color.v < 0.28 else ("steel" if color.s < 0.16 else "plastic"))
	materials[key] = result
	return result

func box(parent: Node3D, dimensions: Vector3, location: Vector3, color: Color, worn: bool = false) -> MeshInstance3D:
	var visual = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = dimensions
	visual.mesh = shape
	visual.material_override = material(color, worn)
	visual.position = location
	parent.add_child(visual)
	return visual

func cylinder(parent: Node3D, radius: float, height: float, location: Vector3, color: Color, sides: int = 10) -> MeshInstance3D:
	var visual = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius
	shape.height = height
	shape.radial_segments = maxi(sides, 16)
	shape.rings = 1
	visual.mesh = shape
	visual.material_override = material(color)
	visual.position = location
	parent.add_child(visual)
	return visual

func beam(parent: Node3D, start: Vector3, finish: Vector3, width: float, color: Color) -> void:
	var visual = box(parent, Vector3(width, width, start.distance_to(finish)), (start + finish) * 0.5, color)
	visual.basis = Basis.looking_at((finish - start).normalized(), Vector3.UP if absf((finish - start).normalized().y) < 0.98 else Vector3.RIGHT)

func sign_text(parent: Node3D, caption: String, location: Vector3, font_size: int = 60, billboard: bool = false) -> Label3D:
	Localization.register_sign(caption)
	var label = Label3D.new()
	label.text = caption
	label.position = location
	label.font_size = font_size
	label.pixel_size = 0.008
	label.outline_size = 6
	label.modulate = Color("#f8e5bc")
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func build(root: Node3D) -> void:
	var yard = Node3D.new()
	yard.name = "ScrapyardArt"
	root.add_child(yard)
	box(yard, Vector3(200, 0.2, 200), Vector3(0, -0.16, 0), SAND)
	var random = RandomNumberGenerator.new()
	random.seed = 72814
	var colors: Array[Color] = [MINT, Color("#c66c53"), Color("#648db0"), Color("#c4b899"), YELLOW.darkened(0.2)]
	for index in 8:
		car(yard, Vector3(-17 + index * 4.8, 0, -83), colors[index % colors.size()], 0.08 * sin(index * 3.0))
	for index in 5:
		car(yard, Vector3(-83, 0, -12 + index * 5.5), colors[(index + 2) % colors.size()], PI * 0.5)
	car(yard, Vector3(-83, 1.1, -6), RUST, 1.4)
	for index in 13:
		barrel(yard, Vector3(83 + random.randf_range(0, 3), 0, -17 + index * 2.6), colors[index % colors.size()])
	for index in 18:
		var rock = cylinder(yard, random.randf_range(0.8, 2.6), random.randf_range(1, 3), Vector3(random.randf_range(-30, 30), 0.5, -87 - random.randf_range(0, 5)), Color("#b47e5d"), 5)
		rock.rotation_degrees = Vector3(12, random.randf_range(0, 360), 15)
	warehouse(yard)
	crane(yard, Vector3(26, 0, -12))
	depot(yard)
	for side in [-1, 1]:
		box(yard, Vector3(0.18, 6, 0.18), Vector3(side * 16, 3, 16), GRAPHITE)
		box(yard, Vector3(1.5, 0.4, 0.5), Vector3(side * 16, 5.9, 15.8), YELLOW)
	sign_text(yard, "SCRAP EMPIRE\nRECUPERO · SELEZIONE · RICICLO", Vector3(-60, 4.4, -79), 110)

func barrel(parent: Node3D, location: Vector3, color: Color) -> void:
	var prop = Node3D.new()
	prop.name="LooseBarrel%03d" % parent.get_child_count()
	prop.set_meta("loose_scenery",true)
	prop.position = location
	parent.add_child(prop)
	cylinder(prop, 0.44, 1.15, Vector3(0, 0.575, 0), color)
	for height in [0.12, 0.95]:
		cylinder(prop, 0.46, 0.1, Vector3(0, height, 0), STEEL.darkened(0.25))
	cylinder(prop, 0.34, 0.035, Vector3(0, 1.17, 0), RUST)

func car(parent: Node3D, location: Vector3, color: Color, yaw: float) -> void:
	var prop = Node3D.new()
	prop.name="LooseCar%03d" % parent.get_child_count()
	prop.set_meta("loose_scenery",true)
	prop.position = location
	prop.rotation.y = yaw
	parent.add_child(prop)
	beveled_box(prop, Vector3(2.0, 0.55, 3.8), Vector3(0, 0.6, 0), color, true)
	beveled_box(prop, Vector3(1.85, 0.18, 1.15), Vector3(0, 0.94, -1.2), RUST, true).rotation.x = -0.1
	box(prop, Vector3(1.8, 0.12, 1.65), Vector3(0, 1.65, 0.1), color, true).rotation.z = 0.06
	box(prop, Vector3(1.65, 0.7, 1.5), Vector3(0, 1.15, 0.1), GRAPHITE)
	box(prop, Vector3(1.6, 0.5, 0.055), Vector3(0, 1.33, -0.72), Color("#537176")).rotation.x = 0.25
	for side in [-1, 1]:
		for axle in [-1.2, 1.2]:
			cylinder(prop, 0.42, 0.22, Vector3(side * 1.0, 0.43, axle), GRAPHITE, 28).rotation.z = PI * 0.5
			cylinder(prop, 0.19, 0.24, Vector3(side * 1.03, 0.43, axle), STEEL, 8).rotation.z = PI * 0.5
		for pillar in [-0.72, 0.85]:
			beam(prop, Vector3(side * 0.87, 0.9, pillar), Vector3(side * 0.78, 1.65, pillar * 0.8), 0.1, color)
		cylinder(prop, 0.16, 0.08, Vector3(side * 0.72, 0.7, -1.93), Color("#e3d6aa")).rotation.x = PI * 0.5
	box(prop, Vector3(2.04, 0.16, 0.15), Vector3(0, 0.45, -1.97), STEEL)
	box(prop, Vector3(1.1, 0.15, 0.09), Vector3(0, 0.71, -1.97), GRAPHITE)

func warehouse(parent: Node3D) -> void:
	for side in [-1, 1]:
		box(parent, Vector3(0.15, 4.5, 6), Vector3(4 + side * 6.5, 2.25, 25), MINT.darkened(0.2), true)
		box(parent, Vector3(4, 4.5, 0.15), Vector3(4 + side * 4.5, 2.25, 22), MINT.darkened(0.2), true)
	box(parent, Vector3(13, 4.5, 0.15), Vector3(4, 2.25, 28), MINT.darkened(0.2), true)
	box(parent, Vector3(14, 0.22, 7), Vector3(4, 4.65, 25), RUST).rotation.x = -0.08
	box(parent, Vector3(5, 0.65, 0.2), Vector3(4, 4, 22), STEEL)
	for side in [-1, 1]:
		box(parent, Vector3(0.2, 4.2, 0.25), Vector3(4 + side * 2.5, 2.1, 21.9), YELLOW)

func crane(parent: Node3D, location: Vector3) -> void:
	var prop = Node3D.new()
	prop.position = location
	parent.add_child(prop)
	for side in [-1, 1]:
		box(prop, Vector3(1.0, 0.8, 4.6), Vector3(side * 1.45, 0.4, 0), GRAPHITE)
		for index in 9:
			box(prop, Vector3(1.04, 0.08, 0.22), Vector3(side * 1.45, 0.85, -2 + index * 0.5), STEEL.darkened(0.4))
	box(prop, Vector3(2.7, 1.5, 3.1), Vector3(0, 1.5, 0.4), YELLOW, true)
	box(prop, Vector3(1.6, 2.3, 1.8), Vector3(0.65, 3.0, 0.7), YELLOW)
	box(prop, Vector3(1.45, 1.5, 0.05), Vector3(0.65, 3.1, -0.24), Color("#476577"))
	for side in [-1, 1]:
		beam(prop, Vector3(side * 0.55, 2.3, -0.5), Vector3(side * 0.55, 8.5, -4.5), 0.18, STEEL.darkened(0.4))
		for index in 6:
			var start = Vector3(side * 0.55, 2.3, -0.5).lerp(Vector3(side * 0.55, 8.5, -4.5), index / 6.0)
			var finish = Vector3(-side * 0.55, 2.3, -0.5).lerp(Vector3(-side * 0.55, 8.5, -4.5), (index + 1) / 6.0)
			beam(prop, start, finish, 0.09, RUST)
	beam(prop, Vector3(0, 8.5, -4.5), Vector3(0, 2.7, -4.5), 0.035, GRAPHITE)
	cylinder(prop, 1.25, 0.45, Vector3(0, 2.45, -4.5), STEEL, 12)
	car(prop, Vector3(0, 0, -4.5), MINT, 0.4)

func depot(parent: Node3D) -> void:
	box(parent, Vector3(5.2, 0.14, 3.2), Vector3(0, 0.07, 14), GRAPHITE)
	for index in 9:
		box(parent, Vector3(0.3, 0.015, 3.1), Vector3(-2.4 + index * 0.6, 0.15, 14), YELLOW)
	box(parent, Vector3(4.4, 0.035, 2.5), Vector3(0, 0.17, 14), STEEL)
	for side in [-1, 1]:
		box(parent, Vector3(0.18, 3.5, 0.18), Vector3(side * 2.6, 1.75, 16), GRAPHITE)
	box(parent, Vector3(5.5, 0.12, 3.5), Vector3(0, 3.6, 15), MINT, true)
	box(parent, Vector3(1.4, 0.85, 0.22), Vector3(2.5, 1.5, 13.1), YELLOW)
	box(parent, Vector3(1.1, 0.55, 0.05), Vector3(2.5, 1.53, 12.96), GRAPHITE)
	sign_text(parent, "BILANCIA", Vector3(2.5, 1.55, 12.92), 24).rotation.y = PI
	barrel(parent, Vector3(4, 0, 16), MINT)
	barrel(parent, Vector3(5.1, 0, 16.4), RUST)
func beveled_box(parent: Node3D, dimensions: Vector3, location: Vector3, color: Color, worn: bool = false) -> MeshInstance3D:
	var half: Vector3 = dimensions * 0.5
	var bevel: float = minf(0.08, minf(half.x, minf(half.y, half.z)) * 0.3)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for side in [-1, 1]:
			var ring: Array[Vector3] = []
			for pair in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var point = Vector3.ZERO
				point[axis] = half[axis] * side
				point[u] = pair.x * (half[u] - bevel)
				point[v] = pair.y * (half[v] - bevel)
				ring.append(point)
			_polygon(surface, ring)
		for su in [-1, 1]:
			for sv in [-1, 1]:
				var edge: Array[Vector3] = []
				for endpoint in [-1,1]:
					for face in [u,v]:
						var point = Vector3.ZERO
						point[axis] = endpoint * (half[axis] - bevel)
						point[u] = su * (half[u] - (0 if face == u else bevel))
						point[v] = sv * (half[v] - (0 if face == v else bevel))
						edge.append(point)
				_polygon(surface, [edge[0],edge[1],edge[3],edge[2]])
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				var triangle: Array[Vector3] = []
				for axis in 3:
					var point = Vector3(x * (half.x - bevel), y * (half.y - bevel), z * (half.z - bevel))
					point[axis] += signf(point[axis]) * bevel
					triangle.append(point)
				_polygon(surface, triangle)
	surface.generate_normals()
	var visual = MeshInstance3D.new()
	visual.mesh = surface.commit()
	visual.material_override = material(color, worn)
	visual.position = location
	parent.add_child(visual)
	return visual

func _polygon(surface: SurfaceTool, points: Array[Vector3]) -> void:
	var center = Vector3.ZERO
	for point in points:
		center += point
	center /= points.size()
	var outward: bool = (points[1] - points[0]).cross(points[2] - points[0]).dot(center) < 0
	for index in range(1, points.size() - 1):
		surface.add_vertex(points[0])
		surface.add_vertex(points[index] if outward else points[index + 1])
		surface.add_vertex(points[index + 1] if outward else points[index])
func surface_material(color: Color, family: String = "steel") -> StandardMaterial3D:
	var key: String = "surface:" + family + color.to_html()
	if materials.has(key):
		return materials[key]
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.albedo_texture = load("res://assets/textures/surfaces/%s_albedo.png" % family)
	result.roughness_texture = load("res://assets/textures/surfaces/%s_roughness.png" % family)
	result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	result.roughness = 1.0
	result.metallic = 0.45 if family == "steel" else 0.0
	result.normal_enabled = true
	result.normal_texture = load("res://assets/textures/surfaces/%s_normal.png" % family)
	result.normal_scale = 0.35 if family == "rubble" else (0.12 if family == "plastic" else 0.18)
	result.uv1_triplanar = true
	result.uv1_scale = Vector3.ONE
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key] = result
	return result


