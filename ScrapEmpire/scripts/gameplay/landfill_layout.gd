extends RefCounted

const CENTERS: Array[Vector3] = [
	Vector3(-25, 0, 0), Vector3(25, 0, 0),
	Vector3(-25, 0, -28), Vector3(25, 0, -28),
	Vector3(-25, 0, -56), Vector3(25, 0, -56)
]
const NAMES = ["ROTTAMI MISTI", "PLASTICHE", "AUTODEMOLIZIONE", "MACERIE", "FERRO VECCHIO", "RECUPERO ELETTRONICO"]

static func scrap_position(index: int) -> Vector3:
	var zone: int = index % CENTERS.size()
	var local_index: int = index / CENTERS.size()
	var angle: float = (local_index % 10) * TAU / 10.0 + zone * 0.17
	var radius: float = 10.0 + (local_index / 10) * 2.8
	if local_index % 2 == 0:
		# Keep collectible pockets clear of the partially buried assemblies.
		if zone >= 3 and absf(wrapf(angle-(zone-3)*0.45,-PI,PI)) < 0.7:
			angle += 0.95
		radius = 2.0 + (local_index % 7) * 0.62
		radius *= footprint_scale(angle,zone)
		return CENTERS[zone] + Vector3(cos(angle) * radius, surface_height(Vector3(cos(angle)*radius,0,sin(angle)*radius),zone) + 0.1, sin(angle) * radius)
	return CENTERS[zone] + Vector3(cos(angle) * radius, 0, sin(angle) * radius)

static func pile_height(radius: float) -> float:
	return 4.4 - radius * 0.4 if radius < 3 else maxf(0, (6.5 - radius) * 3.2 / 3.5)

static func surface_height(local: Vector3, zone: int) -> float:
	var radius: float = Vector2(local.x,local.z).length()
	var angle: float = atan2(local.z,local.x)
	var normalized_radius: float = radius/(6.5*footprint_scale(angle,zone))
	var falloff: float = maxf(0,1-normalized_radius*normalized_radius)
	var crest: float = [1.2,2.5,3.8,5.0,6.5][zone%5]
	var ridges: float = sin(local.x*0.85+zone)*0.15 + cos(local.z*0.7-zone*0.6)*0.1
	return maxf(0,(crest+ridges)*pow(falloff,1.5))

static func footprint_scale(angle: float, zone: int) -> float:
	return (1.18 + cos(angle*2+zone*0.7)*0.12 + sin(angle*3-zone)*0.06)*[0.65,1.0,1.35,1.65,2.0][zone%5]

static func build(root: Node3D) -> void:
	var random = RandomNumberGenerator.new()
	random.seed = 55913
	var visible_geometry: bool = DisplayServer.get_name() != "headless"
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var heaps: Array[Vector3] = CENTERS.duplicate()
	for side in [-1, 1]:
		for depth in [-60, -25, 10, 48]:
			heaps.append(Vector3(side * 58, 0, depth))
	for width in [-28, 0, 28]:
		heaps.append(Vector3(width, 0, 57))
	for zone in heaps.size():
		make_pile(root, heaps[zone], zone, random, "landfill_piles" if zone < CENTERS.size() else "landfill_scenery", "LandfillPile%d" % zone)
	if visible_geometry:
		for offset in [-10, 10]:
			art.box(root, Vector3(0.16, 5, 0.16), Vector3(offset, 2.5, -12), art.GRAPHITE)
		art.sign_text(root, "DISCARICA NORD\n↑ RECUPERO / MACERIE\n↓ BASE · BILANCIA · PRESSA", Vector3(0, 4, -12), 60, true)
static func make_pile(root: Node3D, location: Vector3, zone: int, random: RandomNumberGenerator, group_name: String, node_name: String) -> StaticBody3D:
	var visible_geometry: bool = DisplayServer.get_name() != "headless"
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var body = StaticBody3D.new()
	body.set_script(preload("res://scripts/gameplay/searchable_pile.gd"))
	body.definition_id = ["pile","pile_plastic","pile_electronics","pile_rubble","pile_metal","pile_electronics"][zone % 6]
	body.name = node_name
	body.set_meta("profile_zone",zone)
	body.position = location
	body.add_to_group(group_name)
	var collision = CollisionShape3D.new()
	var faces = PackedVector3Array()
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii = [0.0,1.1,2.2,3.2,4.4,5.5,6.5]
	for ring in range(radii.size()-1):
		for segment in 32:
			var angle: float = segment * TAU/32
			var next: float = (segment+1) * TAU/32
			var corners: Array[Vector3] = []
			for spec in [[radii[ring],angle],[radii[ring+1],angle],[radii[ring+1],next],[radii[ring],next]]:
				var point = Vector3(cos(spec[1])*spec[0],0,sin(spec[1])*spec[0])
				point *= footprint_scale(spec[1],zone)
				point.y = surface_height(point,zone)
				corners.append(point)
			var indices: Array = [0,1,2] if ring == 0 else [0,1,2,0,2,3]
			for index in indices:
				faces.append(corners[index])
				if visible_geometry:
					surface.add_vertex(corners[index])
	var hull = ConcavePolygonShape3D.new()
	hull.set_faces(faces)
	hull.backface_collision = true
	collision.shape = hull
	body.add_child(collision)
	root.add_child(body)
	if not visible_geometry:
		return body
	surface.index()
	surface.generate_normals()
	var visual = MeshInstance3D.new()
	visual.mesh = surface.commit()
	visual.material_override = art.surface_material(Color("#9c7858") if zone % 6 == 3 else Color("#76523c"),"rubble")
	body.add_child(visual)
	var profile = func(radius: float, angle: float) -> float: return surface_height(Vector3(cos(angle)*radius,0,sin(angle)*radius),zone)
	preload("res://scripts/gameplay/heap_details.gd").build(body, zone, random, art, profile,6.5*[0.65,1.0,1.35,1.65,2.0][zone%5])
	if zone < NAMES.size():
		art.box(body, Vector3(0.07, 1.6, 0.07), Vector3(-5.7, 0.8, 5.7), art.STEEL)
		art.box(body, Vector3(2.7, 0.55, 0.12), Vector3(-5.7, 1.5, 5.7), art.GRAPHITE)
		var nameplate = art.sign_text(body, NAMES[zone], Vector3(-5.7, 1.5, 5.78), 30)
		nameplate.pixel_size = 0.0035
	return body

