extends StaticBody3D
var part_id: String = ""
var kind: String = "engine"
var quality: int = 0

func _ready() -> void:
	add_to_group("bulk_parts")
	var collider = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(1.0,0.75,0.8) if kind == "engine" else (Vector3(1.55,0.35,2.1) if kind == "frame" else Vector3(0.75,0.55,0.7))
	collider.position.y = collider.shape.size.y*0.5
	add_child(collider)
	if DisplayServer.get_name() != "headless":
		build_model(self,kind,quality)

func display_name() -> String:
	return Localization.format_text("%s · %d kg · %s", [GameState.part_defs[kind].name,GameState.part_defs[kind].mass_kg,"FUNZIONANTE" if quality == 1 else "DA RIPARARE"])

static func build_model(root: Node3D, type: String, condition: int) -> void:
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var paint: Color = art.MINT if condition == 1 else art.RUST
	if type == "engine":
		art.beveled_box(root,Vector3(0.8,0.55,0.65),Vector3(0,0.36,0),art.STEEL)
		for side in [-1,1]:
			art.beveled_box(root,Vector3(0.1,0.12,0.8),Vector3(side*0.46,0.1,0),art.GRAPHITE)
		for index in 5:
			art.beveled_box(root,Vector3(0.9,0.025,0.7),Vector3(0,0.25+index*0.075,0),art.STEEL.darkened(0.15))
		art.beveled_box(root,Vector3(0.65,0.1,0.6),Vector3(0,0.7,0),paint)
		art.cylinder(root,0.18,0.2,Vector3(0,0.38,-0.43),art.GRAPHITE,32).rotation.x = PI/2
		for side in [-1,1]:
			art.beam(root,Vector3(side*0.3,0.65,0.1),Vector3(side*0.3,0.84,0.1),0.055,paint)
		art.beam(root,Vector3(-0.3,0.84,0.1),Vector3(0.3,0.84,0.1),0.055,paint)
	elif type == "frame":
		for side in [-1,1]:
			art.beveled_box(root,Vector3(0.16,0.25,2.0),Vector3(side*0.65,0.17,0),paint)
		for z in [-0.85,0,0.85]:
			art.beveled_box(root,Vector3(1.35,0.16,0.14),Vector3(0,0.16,z),art.STEEL)
	elif type == "battery":
		art.beveled_box(root,Vector3(0.65,0.48,0.48),Vector3(0,0.27,0),art.GRAPHITE)
		art.beveled_box(root,Vector3(0.68,0.07,0.5),Vector3(0,0.54,0),paint)
		for side in [-1,1]:
			art.cylinder(root,0.055,0.07,Vector3(side*0.2,0.6,0),art.YELLOW if side < 0 else art.STEEL,24)
		art.box(root,Vector3(0.3,0.22,0.012),Vector3(0,0.28,-0.246),art.YELLOW)
	elif type == "wheel":
		preload("res://scripts/gameplay/scrap_catalog.gd").build(root,6,0,art)
		art.cylinder(root,0.2,0.13,Vector3(0,0.16,0),art.STEEL,32)
	else:
		art.beveled_box(root,Vector3(1.0,0.09,0.7),Vector3(0,0.09,0),paint)
		for side in [-1,1]:
			art.beveled_box(root,Vector3(0.04,0.1,0.6),Vector3(side*0.43,0.15,0),art.STEEL)
