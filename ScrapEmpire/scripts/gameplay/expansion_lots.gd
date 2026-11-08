extends RefCounted

const CENTERS = [Vector3(130, 0, -25), Vector3(215, 0, -25)]

static func refresh(root: Node3D) -> void:
	var lots = root.get_node_or_null("ExpansionLots")
	if lots == null:
		lots = Node3D.new()
		lots.name = "ExpansionLots"
		root.add_child(lots)
	for index in GameState.land_defs.size():
		var owned: bool = GameState.yard_level > index
		var old = lots.get_node_or_null("Lot%d" % index)
		if old != null and old.get_meta("owned") == owned:
			continue
		if old != null:
			for gate in old.find_children("LockedGate", "StaticBody3D", true, false):
				gate.collision_layer = 0
			lots.remove_child(old)
			old.queue_free()
		var lot = Node3D.new()
		lot.name = "Lot%d" % index
		lot.position = CENTERS[index]
		lot.set_meta("owned", owned)
		lot.set_meta("level", index + 1)
		lots.add_child(lot)
		_build_lot(lot, index, owned)
		if owned:
			lot.add_to_group("unlocked_lots")
			GameState.sector_initial_counts.merge(GameState.land_defs[index].materials, true)
			var number: int = 0
			for id in GameState.land_defs[index].materials:
				for unit in int(GameState.land_defs[index].materials[id]):
					var position = CENTERS[index] + Vector3(-26 + (number % 12) * 4.5, 0, 32 - (number / 12) * 10)
					root.spawn_lot_scrap(id, "%s_%03d" % [id, unit], position, index + 1)
					number += 1

static func _build_lot(lot: Node3D, index: int, owned: bool) -> void:
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var half_width: float = 35 if index == 0 else 40
	var visible_geometry: bool = DisplayServer.get_name() != "headless"
	if not owned:
		var gate = StaticBody3D.new()
		gate.name = "LockedGate"
		gate.position = Vector3(-half_width, 1.1, 25)
		var shape = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(0.4, 2.2, 14)
		gate.add_child(shape)
		lot.add_child(gate)
		if visible_geometry:
			art.box(gate, shape.shape.size, Vector3.ZERO, art.YELLOW)
	if visible_geometry:
		var ground = art.box(lot, Vector3(half_width * 2, 0.02, 80), Vector3(0, 0.005, 0), Color("#a58e70"))
		var soil = ShaderMaterial.new()
		soil.shader = preload("res://assets/materials/yard_ground.gdshader")
		soil.set_shader_parameter("sand_detail", load("res://assets/textures/surfaces/sand_albedo.png"))
		ground.material_override = soil
		if owned:
			art.box(lot, Vector3(half_width * 2, 0.018, 6), Vector3(0, 0.026, 25), art.GRAPHITE.lightened(0.1))
			for mark in range(-30, 31, 6):
				art.box(lot, Vector3(2, 0.018, 0.1), Vector3(mark, 0.04, 25), art.YELLOW)
		for side in [-1, 1]:
			for segment in 17:
				var z: float = -40 + segment * 5
				if z > 16 and z < 34:
					continue
				art.box(lot, Vector3(0.12, 2.1, 0.12), Vector3(side * half_width, 1.05, z), art.GRAPHITE)
				art.box(lot, Vector3(0.07, 0.08, 4.8), Vector3(side * half_width, 1.7, z + 2.4), art.STEEL)
			art.box(lot, Vector3(half_width * 2, 0.12, 0.12), Vector3(0, 1.6, side * 40), art.STEEL)
		var label = art.sign_text(lot, ("LOTTO EST" if index == 0 else "LOTTO DELLE DUNE") + ("\nACCESSO APERTO" if owned else "\nACQUISTA ALLA PLANIMETRIA"), Vector3(-half_width, 3.8, 25), 40, true)
		label.pixel_size = 0.004
		for offset in [-7.5, 7.5]:
			art.box(lot, Vector3(0.18, 3.1, 0.18), Vector3(-half_width, 1.55, 25 + offset), art.MINT if owned else art.YELLOW)
	if not owned:
		return
	preload("res://scripts/gameplay/worksite_services.gd").build(lot,index)
	var random = RandomNumberGenerator.new()
	random.seed = 6291 + index
	for number in 3:
		var location: Vector3 = [Vector3(-17, 0, -15), Vector3(12, 0, -20), Vector3(0, 0, 15)][number]
		preload("res://scripts/gameplay/landfill_layout.gd").make_pile(lot, location, 100 + index * 3 + number, random, "expansion_piles", "Lot%dPile%d" % [index + 1, number])
	for number in 2:
		var assembly = StaticBody3D.new()
		assembly.set_script(preload("res://scripts/gameplay/salvage_assembly.gd"))
		assembly.definition_id = "generator" if index == 0 else "appliance"
		assembly.entity_id = "lot%d_assembly%d" % [index + 1, number]
		assembly.position = Vector3(-18 + number * 30, 0, 2)
		assembly.add_to_group("lot_salvage")
		lot.add_child(assembly)
	var depot = Node3D.new()
	depot.name = "FieldDepot"
	depot.position = Vector3(27, 0, 25)
	depot.add_to_group("field_depot")
	depot.set_meta("level", index + 1)
	lot.add_child(depot)
	if visible_geometry:
		art.box(depot, Vector3(2.2, 1.1, 1.6), Vector3(0, 0.55, 0), art.MINT)
		art.box(depot, Vector3(2, 0.06, 1.4), Vector3(0, 1.12, 0), art.GRAPHITE)
		var label = art.sign_text(depot, "SCARICO SATELLITE", Vector3(0, 0.65, 0.82), 24)
		label.pixel_size = 0.003
		for number in 4:
			art.barrel(lot, Vector3(-28 + number * 2, 0, -30), art.MINT if index == 0 else art.YELLOW)
		for side in [-1, 1]:
			art.box(lot, Vector3(0.15, 3.4, 0.15), Vector3(-25 + side * 4, 1.7, -33), art.STEEL)
		art.box(lot, Vector3(9, 0.15, 5), Vector3(-25, 3.5, -33), art.MINT if index == 0 else art.YELLOW)
		for number in 5:
			var stack = Node3D.new()
			stack.position = Vector3(-27 + number * 3, 0.5, -20)
			lot.add_child(stack)
			if index == 0:
				art.cylinder(stack, 0.55, 0.7, Vector3(0, 0.3, 0), Color("#b77a48"), 12).rotation.x = PI / 2
				for side in [-1, 1]:
					art.cylinder(stack, 0.75, 0.07, Vector3(0, 0.3, side * 0.4), art.STEEL, 12).rotation.x = PI / 2
			else:
				for layer in 3:
					art.box(stack, Vector3(1.8, 0.2, 1.3), Vector3(0, layer * 0.25, 0), art.MINT if layer % 2 else art.STEEL)
