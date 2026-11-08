extends RefCounted

static func build(root: Node3D) -> void:
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var workshop = Node3D.new()
	workshop.name = "WorkshopInterior"
	workshop.position = Vector3(4, 0, 25)
	root.add_child(workshop)
	art.box(root, Vector3(8, 0.04, 9), Vector3(22, 0.02, 29), art.GRAPHITE)
	for side in [-1, 1]:
		art.box(root, Vector3(0.12, 0.02, 8.5), Vector3(22 + side * 3.7, 0.05, 29), art.YELLOW)
	art.sign_text(root, "PARCHEGGIO MEZZI\nRITIRO BUGGY", Vector3(22, 2.7, 34), 30, true)
	art.box(workshop, Vector3(12.5, 0.06, 6), Vector3(0, 0.03, 0), art.GRAPHITE)
	art.box(workshop, Vector3(12.6, 3.8, 0.05), Vector3(0, 2.1, 2.85), Color("#596969"))
	art.box(workshop, Vector3(12.6, 0.5, 0.07), Vector3(0, 0.32, 2.8), art.GRAPHITE)
	for index in 13:
		art.box(workshop, Vector3(0.045, 3.8, 0.06), Vector3(-6 + index, 2.1, 2.8), art.STEEL.darkened(0.35))
	art.sign_text(workshop, "SCRAP EMPIRE  /  SERVICE BAY", Vector3(0, 3.45, 2.65), 32).rotation.y = PI
	for side in [-1, 1]:
		art.box(workshop, Vector3(0.14, 0.03, 5.4), Vector3(side * 2.2, 0.08, 0), art.YELLOW)
	art.box(workshop, Vector3(6, 0.15, 1.2), Vector3(0, 1.0, 2.1), art.STEEL)
	for side in [-1, 1]:
		art.box(workshop, Vector3(0.2, 0.9, 1), Vector3(side * 2.6, 0.45, 2.1), art.YELLOW)
	art.box(workshop, Vector3(5.9, 1.3, 0.1), Vector3(0, 2, 2.65), art.GRAPHITE)
	for index in 8:
		var tool = art.box(workshop, Vector3(0.05, 0.5, 0.06), Vector3(-2.4 + index * 0.65, 2.0, 2.55), art.STEEL)
		tool.rotation.z = 0.25 if index % 2 else -0.25
		art.cylinder(workshop, 0.07, 0.04, Vector3(-2.4 + index * 0.65, 2.27, 2.53), art.YELLOW, 6).rotation.x = PI / 2
	art.box(workshop, Vector3(1.3, 0.7, 0.7), Vector3(-4.8, 0.35, 1.8), art.MINT)
	for index in 4:
		art.box(workshop, Vector3(1.2, 0.12, 0.05), Vector3(-4.8, 0.12 + index * 0.16, 1.42), art.GRAPHITE)
	for side in [-1, 1]:
		art.box(workshop, Vector3(0.08, 2.5, 0.85), Vector3(3.7 + side * 0.9, 1.25, 2.2), art.YELLOW)
	for shelf in 3:
		art.box(workshop, Vector3(1.9, 0.08, 0.9), Vector3(3.7, 0.35 + shelf * 0.8, 2.2), art.STEEL)
		art.box(workshop, Vector3(0.7, 0.5, 0.65), Vector3(3.4, 0.64 + shelf * 0.8, 2.2), art.MINT if shelf % 2 else art.RUST)
	for index in 3:
		var tyre = TorusMesh.new()
		tyre.inner_radius = 0.25
		tyre.outer_radius = 0.5
		var visual = MeshInstance3D.new()
		visual.mesh = tyre
		visual.material_override = art.material(art.GRAPHITE)
		visual.position = Vector3(4.9, 0.25 + index * 0.36, 1.6)
		workshop.add_child(visual)
	art.sign_text(workshop, "OFFICINA / GARAGE", Vector3(0, 3.65, -3.2), 65).rotation.y = PI
	var light = OmniLight3D.new()
	light.position = Vector3(0, 3.4, 0)
	light.omni_range = 10
	light.light_energy = 1.5
	light.light_color = Color("#ffe4b1")
	workshop.add_child(light)
	art.box(workshop, Vector3(4.5, 0.08, 0.3), Vector3(0, 4.25, 0), Color("#f7d491"))
