extends Node3D

var platen: Node3D
var bale: Node3D
var status_label: Label3D
var lamps: MeshInstance3D
var _last_owned: bool = false

func _ready() -> void:
	add_to_group("industrial_press")
	var body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(3.8, 3.6, 2.6)
	collision_shape.position.y = 1.8
	body.add_child(collision_shape)
	add_child(body)
	if DisplayServer.get_name() == "headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.box(self, Vector3(4.5, 0.2, 4.0), Vector3(0, 0.1, 0), art.GRAPHITE)
	for index in 10:
		art.box(self, Vector3(0.22, 0.02, 0.35), Vector3(-2 + index * 0.43, 0.22, -1.8), art.YELLOW).rotation.y = 0.3
	art.box(self, Vector3(3.4, 0.7, 2.5), Vector3(0, 0.55, 0), art.YELLOW, true)
	art.box(self, Vector3(2.9, 0.18, 2.2), Vector3(0, 1.0, 0), art.STEEL)
	for side in [-1, 1]:
		art.box(self, Vector3(0.38, 3.5, 0.5), Vector3(side * 1.6, 1.9, 0.6), art.YELLOW, true)
		art.cylinder(self, 0.13, 2.0, Vector3(side * 1.2, 2.35, 0.6), art.STEEL)
	art.box(self, Vector3(3.8, 0.65, 1.3), Vector3(0, 3.6, 0.55), art.YELLOW, true)
	art.cylinder(self, 0.3, 0.7, Vector3(0, 4.2, 0.55), art.GRAPHITE)
	platen = Node3D.new()
	platen.position.y = 2.7
	add_child(platen)
	art.box(platen, Vector3(2.85, 0.28, 2.0), Vector3.ZERO, art.GRAPHITE)
	art.cylinder(platen, 0.15, 0.9, Vector3(0, 0.6, 0.55), art.STEEL)
	bale = Node3D.new()
	bale.position = Vector3(0, 1.5, 0)
	add_child(bale)
	art.box(bale, Vector3(1.9, 0.95, 1.4), Vector3.ZERO, art.MINT, true)
	for offset in [-0.6, 0.6]:
		art.box(bale, Vector3(0.07, 0.98, 1.43), Vector3(offset, 0, 0), art.STEEL)
	art.box(self, Vector3(0.8, 1.15, 0.5), Vector3(2.05, 0.8, -1), art.MINT)
	lamps = art.cylinder(self, 0.09, 0.06, Vector3(2.05, 1.45, -1), art.YELLOW)
	art.beveled_box(self,Vector3(0.65,0.4,0.02),Vector3(2.05,1.05,-1.26),art.GRAPHITE)
	status_label = art.sign_text(self, "", Vector3(2.05,1.05,-1.28), 24)
	status_label.rotation.y = PI
	status_label.pixel_size = 0.0018
	status_label.outline_size = 0
	_last_owned = not GameState.press_owned
	_update_visuals()

func interaction_position() -> Vector3:
	return global_position + Vector3(0, 0, -2.1)

func _process(_delta: float) -> void:
	if status_label:
		_update_visuals()

func _update_visuals() -> void:
	var running: bool = GameState.press_remaining > 0
	var progress: float = clampf(1.0 - GameState.press_remaining / GameState.press_cycle_seconds(),0,1)
	platen.position.y = 2.7 - sin(progress * PI) * 1.1 if running else 2.7
	bale.visible = GameState.press_owned and (running or GameState.press_bales > 0)
	bale.scale.y = 1.0 - sin(progress * PI) * 0.55 if running else 0.45
	if not GameState.press_owned:
		status_label.text = Localization.text("P-01\n%d BULLONI") % int(GameState.press_def.cost)
	elif running:
		status_label.text = Localization.text("CICLO\n%.1f s") % GameState.press_remaining
	else:
		status_label.text = Localization.text("PRONTA\n%d BALLE") % GameState.press_bales
	if _last_owned != GameState.press_owned:
		_last_owned = GameState.press_owned
		modulate_machine(GameState.press_owned)

func modulate_machine(owned_machine: bool) -> void:
	var lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color("#74e8a3") if owned_machine else Color("#e4a945")
	lamp_material.emission_enabled = owned_machine
	lamp_material.emission = lamp_material.albedo_color
	lamps.material_override = lamp_material
