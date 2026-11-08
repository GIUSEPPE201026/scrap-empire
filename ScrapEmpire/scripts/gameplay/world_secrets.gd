extends StaticBody3D

var secret_id: String = ""
var relic: Node3D
const LOCATIONS = [Vector3(-180, 0, -135), Vector3(270, 0, 100), Vector3(-65, 0, 250)]

static func build(root: Node3D) -> void:
	for index in GameState.secret_defs.size():
		var secret = StaticBody3D.new()
		secret.set_script(load("res://scripts/gameplay/world_secrets.gd"))
		secret.secret_id = GameState.secret_defs[index].id
		var position: Vector3 = LOCATIONS[index]
		position.y = preload("res://scripts/gameplay/desert_world.gd").height_at(position) + 0.08
		secret.position = position
		root.add_child(secret)

func _ready() -> void:
	add_to_group("world_secrets")
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.2, 1.4, 1.2)
	shape.position.y = 0.8
	add_child(shape)
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.cylinder(self, 1.3, 0.3, Vector3(0, 0.15, 0), art.GRAPHITE, 8)
	relic = Node3D.new()
	relic.position.y = 0.8
	add_child(relic)
	if secret_id == "rusty_duck":
		_ball(relic, Vector3(0, 0, 0), Vector3(0.9, 0.65, 1.0), art.YELLOW)
		_ball(relic, Vector3(0, 0.42, -0.3), Vector3.ONE * 0.5, art.YELLOW)
		art.box(relic, Vector3(0.3, 0.1, 0.22), Vector3(0, 0.36, -0.61), art.RUST)
		for side in [-1, 1]:
			_ball(relic, Vector3(side * 0.19, 0.49, -0.4), Vector3.ONE * 0.07, art.GRAPHITE)
		art.car(self, Vector3(5, -0.1, 2), art.RUST, 1.1)
		for index in 4:
			art.barrel(self, Vector3(-3 + index, 0, 4), art.MINT)
	elif secret_id == "signal_42":
		art.box(relic, Vector3.ONE * 0.65, Vector3.ZERO, art.MINT)
		for side in [-1, 1]:
			art.box(relic, Vector3(0.68, 0.12, 0.7), Vector3(0, side * 0.22, 0), art.YELLOW)
		art.beam(self, Vector3(4, -2, 3), Vector3(4, 9, 3), 0.2, art.STEEL)
		var dish = art.cylinder(self, 2.8, 0.3, Vector3(4, 8, 3), art.STEEL, 12)
		dish.rotation.x = 0.8
		art.beam(self, Vector3(4, 8, 3), Vector3(4, 10, 1), 0.08, art.YELLOW)
	else:
		var ring = TorusMesh.new()
		ring.inner_radius = 1.2
		ring.outer_radius = 2.2
		ring.rings = 6
		ring.ring_segments = 6
		var statue = MeshInstance3D.new()
		statue.mesh = ring
		statue.material_override = art.material(art.YELLOW)
		statue.position = Vector3(4, 3.5, 3)
		statue.rotation.x = PI / 2
		add_child(statue)
		art.box(self, Vector3(4, 0.6, 2), Vector3(4, -0.2, 3), art.GRAPHITE)
		for side in [-1, 1]:
			art.box(self, Vector3(0.25, 4.8, 0.25), Vector3(4 + side * 1.3, 1.3, 3), art.STEEL)
		art.cylinder(relic, 0.28, 0.38, Vector3.ZERO, art.YELLOW, 6)
		art.cylinder(relic, 0.12, 0.4, Vector3(0, 0.03, 0), art.GRAPHITE, 6)
	var plaque = art.sign_text(self, "ARCHIVIO DELLA DISCARICA", Vector3(0, 0.19, 1.31), 18)
	plaque.pixel_size = 0.0028

func _ball(parent: Node3D, position: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radial_segments = 12
	mesh.mesh.rings = 6
	mesh.position = position
	mesh.scale = dimensions
	mesh.material_override = preload("res://scripts/gameplay/scrapyard_art.gd").new().material(color)
	parent.add_child(mesh)

func _process(delta: float) -> void:
	if relic:
		relic.rotation.y += delta * 0.5

func discover() -> bool:
	return GameState.discover_secret(secret_id)
