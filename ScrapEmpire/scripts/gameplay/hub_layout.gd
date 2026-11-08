extends RefCounted

const TOOLS = Vector3(-18, 0, 24.5)
const LAND = Vector3(-26, 0, 21)
const VEHICLES = Vector3(15, 0, 25)
const JOURNAL = Vector3(-20, 0, 24.5)
const PRESS = Vector3(-10, 0, 14)

static func build(root: Node3D) -> void:
	# La casa ufficio è separata dal garage storico (4, 0, 25).
	root._yard_box("OfficeBack", Vector3(8, 3.4, 0.18), Vector3(-18, 1.7, 28), Color("#c8c8b6"))
	root._yard_box("OfficeLeft", Vector3(0.18, 3.4, 6), Vector3(-22, 1.7, 25), Color("#c8c8b6"))
	root._yard_box("OfficeRight", Vector3(0.18, 3.4, 6), Vector3(-14, 1.7, 25), Color("#c8c8b6"))
	for x in [-20.7, -15.3]:
		root._yard_box("OfficeFront" + str(x), Vector3(2.5, 3.4, 0.18), Vector3(x, 1.7, 22), Color("#c8c8b6"))
	root._yard_box("OfficeRoof", Vector3(8.5, 0.2, 6.5), Vector3(-18, 3.5, 25), Color("#344b50"))
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var layout = Node3D.new()
	layout.name = "CentralHubArt"
	root.add_child(layout)
	# Pad funzionali e corsie libere fra i servizi.
	art.box(layout, Vector3(64, 0.015, 31), Vector3(-1, 0.009, 23), Color("#837c65"))
	art.box(layout, Vector3(8, 0.015, 19), Vector3(0, 0.025, 20), art.GRAPHITE)
	art.box(layout, Vector3(16, 0.015, 9), Vector3(-12, 0.026, 14), Color("#595b52"))
	art.box(layout, Vector3(8, 0.015, 6), Vector3(-18, 0.027, 25), Color("#4b5958"))
	for x in [-29, -8, 9, 29]:
		for z in [9, 12, 15, 18, 21, 24, 27, 30, 33]:
			art.box(layout, Vector3(0.08, 0.015, 1.3), Vector3(x, 0.042, z), art.YELLOW)
	for x in [-18, -9, 0, 10, 20]:
		art.box(layout, Vector3(1.3, 0.016, 0.12), Vector3(x, 0.046, 19), art.MINT)
	art.box(layout, Vector3(3.4, 0.13, 1.4), TOOLS + Vector3(0, 1.0, 0.1), Color("#8f7757"))
	for side in [-1, 1]:
		art.box(layout, Vector3(0.6, 0.92, 1.0), TOOLS + Vector3(side * 1.3, 0.46, 0.1), Color("#314950"))
	art.box(layout, Vector3(0.7, 0.035, 0.23), TOOLS + Vector3(0, 1.09, -0.45), art.GRAPHITE)
	art.box(layout, Vector3(0.35, 0.02, 0.5), TOOLS + Vector3(1.0, 1.085, 0), Color("#d2d4be"))
	art.box(layout, Vector3(5.5, 0.12, 1), Vector3(-18, 1, 27.2), art.STEEL)
	for x in [-20.5, -15.5]:
		art.box(layout, Vector3(0.15, 1, 0.8), Vector3(x, 0.5, 27.2), art.GRAPHITE)
	art.box(layout, Vector3(2.2, 1.0, 0.08), Vector3(-20.7, 2.0, 21.87), Color("#345e6a"))
	art.box(layout, Vector3(1.8, 1.0, 0.08), Vector3(-15.3, 2, 21.87), Color("#345e6a"))
	art.box(layout, Vector3(4.2, 0.5, 0.12), Vector3(-18, 3.04, 19.92), Color("#263e45"))
	var office_sign = art.sign_text(layout, "OFFICINA / COMMESSE", Vector3(-18, 3.04, 19.83), 45, true)
	office_sign.pixel_size = 0.0035
	for side in [-1, 1]:
		art.box(layout, Vector3(0.10, 2.9, 0.10), Vector3(-18 + side * 3.3, 1.45, 20.7), art.GRAPHITE)
	art.box(layout, Vector3(8.2, 0.13, 2), Vector3(-18, 3.06, 21), Color("#314950"))
	for index in 11:
		art.box(layout, Vector3(0.035, 2.9, 0.08), Vector3(-21.7 + index * 0.72, 1.5, 28.11), Color("#adb7aa"))
	for side in [-1, 1]:
		art.box(layout, Vector3(0.05, 0.65, 5.9), Vector3(-18 + side * 4.1, 0.35, 25), Color("#314950"))
	for plank in 10:
		art.box(layout, Vector3(0.77, 0.012, 5.8), Vector3(-21.5 + plank * 0.78, 0.044, 25), Color("#757360") if plank % 2 else Color("#686b5a"))
	var interior_light = OmniLight3D.new()
	interior_light.position = Vector3(-18, 2.9, 25)
	interior_light.omni_range = 6
	interior_light.light_energy = 1.0
	interior_light.light_color = Color("#ffe8c7")
	layout.add_child(interior_light)
	for index in 3:
		art.box(layout, Vector3(1.8, 0.08, 2.5), Vector3(-20.5 + index * 2.5, 3.68, 25), Color("#234753")).rotation.x = -0.12
	# Stoccaggio e produzione sulla sinistra, mai nel corridoio di ingresso.
	for index in 3:
		art.box(layout, Vector3(2.3, 1, 1.7), Vector3(-15 - index * 3, 0.5, 17), [art.MINT, art.STEEL, art.YELLOW][index])
		art.box(layout, Vector3(2.1, 0.06, 1.5), Vector3(-15 - index * 3, 1.03, 17), art.GRAPHITE)
	for entry in [["BILANCIA / VENDITA", Vector3(0, 2.7, 11)], ["PRODUZIONE / PRESSA", Vector3(-10, 3.3, 10)], ["GARAGE / RITIRO MEZZI", Vector3(15, 3.0, 22)]]:
		var sign_label = art.sign_text(layout, entry[0], entry[1], 34, true)
		sign_label.pixel_size = 0.0035
	for x in [-29, 29]:
		art.box(layout, Vector3(0.12, 5.8, 0.12), Vector3(x, 2.9, 20), art.GRAPHITE)
		var light = OmniLight3D.new()
		light.position = Vector3(x, 5.5, 20)
		light.omni_range = 18
		light.light_energy = 0.8
		light.light_color = Color("#ffe2ad")
		layout.add_child(light)
