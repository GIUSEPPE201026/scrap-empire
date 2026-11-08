## ScrapItem.gd
## Oggetto rottame raccoglibile: metallo, plastica, elettronica.

class_name ScrapItem
extends Area3D

enum ScrapType {
	METAL,
	PLASTIC,
	ELECTRONIC,
	COPPER,
	ALUMINUM,
	GLASS,
	RUBBER,
	TEXTILE,
	HAZARDOUS
}

@export var scrap_type: ScrapType = ScrapType.METAL
@export var mass: float = 1.0
@export var value: float = 10.0
@export var entity_id: String = ""

@onready var mesh: MeshInstance3D = get_node("MeshInstance3D")
@onready var glow: MeshInstance3D = get_node("GlowMesh")
@onready var collision: CollisionShape3D = get_node("CollisionShape3D")
@onready var collect_sound: AudioStreamPlayer3D = get_node_or_null("CollectSound")
@onready var deposit_sound: AudioStreamPlayer3D = get_node_or_null("DepositSound")

# Mesh per tipo di scrap (creati dinamicamente)
var _type_mesh: Mesh = null

var _is_highlighted: bool = false
var _bob_time: float = 0.0
const BOB_SPEED: float = 2.0
const BOB_HEIGHT: float = 0.15

signal collected(entity_id: String, scrap_type: int, mass: float, value: float)

func _restore_drag_position() -> void:
	var data = GameState.operations.get("loose_positions",{}).get(entity_id,[])
	if data.size()==3:
		global_position = Vector3(data[0],data[1],data[2])
	rotation.y = float(GameState.operations.get("loose_rotations",{}).get(entity_id,rotation.y))

func _ready() -> void:
	call_deferred("_restore_drag_position")
	if SessionState.is_single_player_session:
		set_deferred("monitoring",false)
	# Assegna entity_id univoco se non impostato
	if entity_id.is_empty():
		entity_id = "scrap_%s_%d" % [scrap_type, Time.get_ticks_msec()]

	# In headless mode, remove visual meshes to avoid dummy renderer errors
	var is_headless = DisplayServer.get_name() == "headless"
	if scrap_type <= ScrapType.RUBBER:
		_catalog_collision()
	if is_headless:
		# Remove mesh nodes entirely - we only need collision for headless tests
		if mesh:
			mesh.queue_free()
		if glow:
			glow.queue_free()
		return

	# Crea mesh appropriata per il tipo
	_create_type_mesh()

	# Colora in base al tipo
	_apply_type_color()
	if scrap_type <= ScrapType.RUBBER:
		_build_salvage_details()
	var material_id: String = ["metal", "plastic", "electronics", "copper", "aluminum", "glass", "rubber", "textile", "hazardous"][scrap_type]
	mass = GameState.material_defs[material_id].mass_kg
	value = GameState.material_defs[material_id].credits

	# Connetti segnali
	if not SessionState.is_single_player_session:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if scrap_type <= ScrapType.RUBBER:
		return
	# In headless mode, visual nodes are freed, skip animation
	if DisplayServer.get_name() == "headless":
		return

	# Animazione bobbing
	_bob_time += delta * BOB_SPEED
	var y_offset = sin(_bob_time) * BOB_HEIGHT
	mesh.position.y = y_offset
	glow.position.y = y_offset
	collision.position.y = y_offset

	# Rotazione lenta
	mesh.rotation.y += delta * 0.5
	collision.rotation.y = mesh.rotation.y
	glow.rotation.y -= delta * 0.3

func _create_type_mesh() -> void:
	# In headless mode, skip dynamic mesh creation to avoid dummy renderer issues
	var is_headless = DisplayServer.get_name() == "headless"
	if is_headless:
		# Use default mesh from scene (BoxMesh)
		_type_mesh = mesh.mesh
		_update_collision_shape()
		return

	# Crea mesh diversa per ogni tipo di scrap
	match scrap_type:
		ScrapType.METAL:
			# Pezzi metallici: cubo irregolare
			_type_mesh = BoxMesh.new()
			_type_mesh.size = Vector3(0.8, 0.6, 0.8)
		ScrapType.PLASTIC:
			# Bottiglie/contenitori plastica: cilindro
			_type_mesh = CylinderMesh.new()
			_type_mesh.height = 1.0
			_type_mesh.bottom_radius = 0.4
			_type_mesh.top_radius = 0.3
		ScrapType.ELECTRONIC:
			# Schede elettroniche: cubo piatto
			_type_mesh = BoxMesh.new()
			_type_mesh.size = Vector3(1.0, 0.3, 0.8)
		ScrapType.COPPER:
			# Tubi/filo rame: cilindro sottile
			_type_mesh = CylinderMesh.new()
			_type_mesh.height = 1.2
			_type_mesh.bottom_radius = 0.25
			_type_mesh.top_radius = 0.25
		ScrapType.ALUMINUM:
			# Lamiere alluminio: cubo sottile
			_type_mesh = BoxMesh.new()
			_type_mesh.size = Vector3(1.2, 0.2, 1.0)
		ScrapType.GLASS:
			# Bottiglie vetro: sfera
			_type_mesh = SphereMesh.new()
			_type_mesh.radius = 0.45
		ScrapType.RUBBER:
			# Pezzi gomma: capsula
			_type_mesh = CapsuleMesh.new()
			_type_mesh.height = 0.8
			_type_mesh.radius = 0.4
		ScrapType.TEXTILE:
			# Stracci tessuto: cubo morbido
			_type_mesh = BoxMesh.new()
			_type_mesh.size = Vector3(0.9, 0.5, 0.7)
		ScrapType.HAZARDOUS:
			# Contenitori pericolosi: cubo con angoli smussati (approssimato come cubo)
			_type_mesh = BoxMesh.new()
			_type_mesh.size = Vector3(0.9, 1.0, 0.9)

	# Applica la mesh
	if _type_mesh:
		mesh.mesh = _type_mesh
		# Aggiorna anche la collision shape
		_update_collision_shape()

func _update_collision_shape() -> void:
	# Crea collision shape basata sulla mesh
	if _type_mesh is BoxMesh:
		var box_shape = BoxShape3D.new()
		box_shape.size = _type_mesh.size
		collision.shape = box_shape
	elif _type_mesh is CylinderMesh:
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.height = _type_mesh.height
		cylinder_shape.radius = _type_mesh.bottom_radius
		collision.shape = cylinder_shape
	elif _type_mesh is SphereMesh:
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = _type_mesh.radius
		collision.shape = sphere_shape
	elif _type_mesh is CapsuleMesh:
		var capsule_shape = CapsuleShape3D.new()
		capsule_shape.height = _type_mesh.height
		capsule_shape.radius = _type_mesh.radius
		collision.shape = capsule_shape

func _apply_type_color() -> void:
	var mat = mesh.material_override.duplicate() as StandardMaterial3D
	match scrap_type:
		ScrapType.METAL:
			mat.albedo_color = Color(0.65, 0.55, 0.35, 1)
			mat.metallic = 0.9
			mat.roughness = 0.3
			mass = 2.0
			value = 15.0
		ScrapType.PLASTIC:
			mat.albedo_color = Color(0.35, 0.55, 0.75, 1)
			mat.metallic = 0.0
			mat.roughness = 0.6
			mass = 0.5
			value = 8.0
		ScrapType.ELECTRONIC:
			mat.albedo_color = Color(0.75, 0.7, 0.15, 1)
			mat.metallic = 0.7
			mat.roughness = 0.4
			mat.emission_enabled = true
			mat.emission_energy = 0.2
			mat.emission = Color(0.8, 0.75, 0.2, 1)
			mass = 1.0
			value = 30.0
		ScrapType.COPPER:
			mat.albedo_color = Color(0.72, 0.45, 0.2, 1)
			mat.metallic = 0.95
			mat.roughness = 0.25
			mass = 1.5
			value = 18.0
		ScrapType.ALUMINUM:
			mat.albedo_color = Color(0.8, 0.8, 0.85, 1)
			mat.metallic = 0.9
			mat.roughness = 0.2
			mass = 0.8
			value = 8.0
		ScrapType.GLASS:
			mat.albedo_color = Color(0.45, 0.75, 0.85, 1)
			mat.metallic = 0.0
			mat.roughness = 0.05
			mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
			mass = 2.5
			value = 12.0
		ScrapType.RUBBER:
			mat.albedo_color = Color(0.15, 0.15, 0.18, 1)
			mat.metallic = 0.0
			mat.roughness = 0.85
			mass = 1.2
			value = 6.0
		ScrapType.TEXTILE:
			mat.albedo_color = Color(0.55, 0.45, 0.65, 1)
			mat.metallic = 0.0
			mat.roughness = 0.9
			mass = 0.5
			value = 3.0
		ScrapType.HAZARDOUS:
			mat.albedo_color = Color(0.9, 0.25, 0.1, 1)
			mat.metallic = 0.3
			mat.roughness = 0.4
			mat.emission_enabled = true
			mat.emission_energy = 0.4
			mat.emission = Color(1.0, 0.3, 0.1, 1)
			mass = 4.0
			value = 50.0
	mesh.material_override = mat

	# Glow colorato per evidenziazione
	var glow_mat = glow.material_override.duplicate() as StandardMaterial3D
	glow_mat.emission_enabled = true
	glow_mat.emission_energy = 0.6
	glow_mat.emission = mat.albedo_color
	glow_mat.metallic = 0.0
	glow_mat.roughness = 0.1
	# Usa stessa mesh per glow (leggermente più grande)
	if _type_mesh:
		glow.mesh = _type_mesh.duplicate()
		if glow.mesh is BoxMesh:
			glow.mesh.size *= 1.12
		elif glow.mesh is CylinderMesh:
			glow.mesh.bottom_radius *= 1.12
			glow.mesh.top_radius *= 1.12
		elif glow.mesh is SphereMesh:
			glow.mesh.radius *= 1.12
		elif glow.mesh is CapsuleMesh:
			glow.mesh.radius *= 1.12
	else:
		glow.mesh = BoxMesh.new()
		glow.mesh.size = Vector3(1.12, 1.12, 1.12)
	glow.material_override = glow_mat

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and body.has_method("set_target_scrap"):
		body.set_target_scrap(self)
		set_highlighted(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players") and body.has_method("set_target_scrap"):
		body.set_target_scrap(null)
		set_highlighted(false)

func set_highlighted(highlighted: bool) -> void:
	_is_highlighted = highlighted
	if scrap_type <= ScrapType.RUBBER:
		if is_instance_valid(mesh):
			for child in mesh.find_children("*", "MeshInstance3D", true, false):
				if child.material_override is StandardMaterial3D:
					child.material_override.emission_enabled = highlighted
					child.material_override.emission = Color(0.06,0.11,0.07)
		return
	if is_instance_valid(glow):
		glow.visible = highlighted

func _build_salvage_details() -> void:
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	glow.hide()
	mesh.mesh = null
	catalog.build(mesh, scrap_type, catalog.variant_for(entity_id), art)
	preload("res://scripts/gameplay/static_art_batch.gd").object(mesh)
	_catalog_collision()

func _catalog_collision() -> void:
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.9,0.78,0.9)
	collision.shape = shape
	collision.position = Vector3(0,0.33,0)

func display_name() -> String:
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	return catalog.item_name(scrap_type,catalog.variant_for(entity_id))

func collect() -> void:
	if is_queued_for_deletion():
		return
	collected.emit(entity_id, int(scrap_type), mass, value)
	if collect_sound:
		collect_sound.play()
	queue_free()

func _spawn_collection_particles() -> void:
	# Crea particelle di raccolta
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	particles.spread = 45.0
	particles.initial_velocity = 3.0
	particles.gravity = Vector3(0, -2.0, 0)
	particles.scale = 0.3
	particles.scale_curve = PackedFloat32Array([1.0, 0.0])
	particles.color_ramp = _get_particle_color_ramp()
	particles.local_coords = false
	particles.global_position = global_position + Vector3(0, 0.5, 0)
	get_tree().root.add_child(particles)
	# Auto-remove after lifetime
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(particles.queue_free.bind())
	particles.add_child(timer)
	timer.start()

func _get_particle_color_ramp() -> Gradient:
	var gradient = Gradient.new()
	var mat = mesh.material_override as StandardMaterial3D
	var base_color = mat.albedo_color
	var color1 = Color(base_color.r, base_color.g, base_color.b, 1.0)
	var color2 = Color(base_color.r * 1.2, base_color.g * 1.2, base_color.b * 1.2, 0.5)
	var color3 = Color(base_color.r, base_color.g, base_color.b, 0.0)
	gradient.set_color_at_offset(0.0, color1)
	gradient.set_color_at_offset(0.5, color2)
	gradient.set_color_at_offset(1.0, color3)
	return gradient

func get_scrap_data() -> Dictionary:
	return {
		"entity_id": entity_id,
		"type": int(scrap_type),
		"mass": mass,
		"value": value,
		"global_position": global_position
	}
