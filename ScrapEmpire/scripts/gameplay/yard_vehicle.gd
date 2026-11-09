extends Node3D

var level: int = 1
var vehicle_kind: String="scooter"

func motion_definition() -> Dictionary:
	return GameState.logistics_def.mobility[vehicle_kind] if vehicle_kind in ["skateboard","dirtbike"] else GameState.vehicle_defs[level-1]
var parked: bool = true
var visual: Node3D
var body: StaticBody3D
var wheels: Array[Node3D] = []
var rider: Node3D
var cargo_visual: Node3D
var _cargo_signature: String = ""
var headlights: Array[SpotLight3D] = []
var headlights_enabled: bool = true
var _tracks: MultiMeshInstance3D
var paint_panels: Array[MeshInstance3D]=[]
var _paint_index: int=-1
var _boarding: Tween
var _exit_ghost: Node3D
var _exit_tween: Tween
var _dust_emitters: Array[CPUParticles3D]=[]

func update_dust(driver: CharacterBody3D, speed: float, slip: float) -> void:
	if level!=2 or DisplayServer.get_name()=="headless": return
	if _dust_emitters.is_empty():
		for side in [-1,1]:
			var dust=CPUParticles3D.new()
			dust.emitting=false
			dust.amount=40
			dust.lifetime=0.8
			dust.local_coords=false
			dust.direction=Vector3(side*0.5,0.5,1)
			dust.spread=35
			dust.initial_velocity_min=1.2
			dust.initial_velocity_max=3.2
			dust.gravity=Vector3(0,0.4,0)
			dust.scale_amount_min=0.12
			dust.scale_amount_max=0.4
			var mesh=SphereMesh.new()
			mesh.radial_segments=8
			mesh.rings=4
			var material=StandardMaterial3D.new()
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color=Color(0.72,0.52,0.31,0.22)
			mesh.material=material
			dust.mesh=mesh
			var gradient=Gradient.new()
			gradient.set_color(0,Color.WHITE)
			gradient.set_color(1,Color(1,1,1,0))
			dust.color_ramp=gradient
			visual.add_child(dust)
			dust.position=Vector3(side*1.1,0.25,1.3)
			_dust_emitters.append(dust)
	for index in _dust_emitters.size():
		var wheel=wheels[index*2+1]
		var point: Vector3=wheel.get_meta("ground_point",driver.global_position)
		var concrete: bool=maxf(absf(point.x),absf(point.z))<82 or (point.x>70 and point.x<265 and point.z>-75 and point.z<22)
		_dust_emitters[index].emitting=not parked and driver.is_on_floor() and wheel.get_meta("grounded",false) and not concrete and speed>3 and slip>0.12

func stop_dust() -> void:
	for emitter in _dust_emitters: emitter.emitting=false

func animate_entry(side: float) -> void:
	if level not in [2,3,4,5,6] or not is_instance_valid(rider): return
	if _boarding: _boarding.kill()
	if _exit_tween: _exit_tween.kill()
	if is_instance_valid(_exit_ghost): _exit_ghost.queue_free()
	rider.position=Vector3(side*1.35,-0.15,0)
	rider.rotation.y=side*0.7
	rider.seated=0.0
	_boarding=create_tween().set_parallel(true)
	_boarding.tween_property(rider,"position",Vector3(0,-0.05,0) if level==3 else Vector3.ZERO,0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_boarding.tween_property(rider,"rotation:y",0.0,0.55)
	_boarding.tween_property(rider,"seated",0.55 if level==3 else 1.0,0.55)

func animate_exit(destination: Vector3) -> void:
	if level not in [2,3,4,5,6] or not is_instance_valid(rider): return
	if _boarding: _boarding.kill()
	if is_instance_valid(_exit_ghost): _exit_ghost.queue_free()
	# Independent articulated actor, not a duplicate player/collider.
	_exit_ghost=preload("res://scripts/gameplay/worker_model.gd").new()
	visual.add_child(_exit_ghost)
	_exit_ghost.position=rider.position
	_exit_ghost.rotation=rider.rotation
	_exit_ghost.seated=rider.seated
	_exit_ghost.bike_pose=level==3
	var target: Vector3=visual.to_local(destination)
	_exit_tween=create_tween().set_parallel(true)
	_exit_tween.tween_property(_exit_ghost,"position",target,0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_exit_tween.tween_property(_exit_ghost,"seated",0.0,0.6)
	_exit_tween.chain().tween_callback(_exit_ghost.queue_free)

func _refresh_paint() -> void:
	var identity=preload("res://scripts/economy/yard_identity.gd")
	var index: int=int(identity.data()["scooter" if level==1 else "buggy"])
	if index==_paint_index:
		return
	_paint_index=index
	for panel in paint_panels:
		var material: Material=panel.material_override.duplicate()
		if material is ShaderMaterial:
			material.set_shader_parameter("paint_color",identity.COLORS[index])
		elif material is StandardMaterial3D:
			material.albedo_color=identity.COLORS[index]
		panel.material_override=material

func update_tracks(driver: CharacterBody3D, _delta: float, speed: float) -> void:
	if DisplayServer.get_name()=="headless" or absf(speed)<0.65 or not driver.is_on_floor():
		return
	if not is_instance_valid(_tracks):
		_tracks=MultiMeshInstance3D.new()
		_tracks.set_script(preload("res://scripts/gameplay/sand_tracks.gd"))
		get_tree().current_scene.add_child(_tracks)
	for index in wheels.size():
		var wheel=wheels[index]
		if not wheel.get_meta("grounded",false):
			continue
		var point: Vector3=wheel.get_meta("ground_point")
		if maxf(absf(point.x),absf(point.z))<82 or (point.x>70 and point.x<265 and point.z>-75 and point.z<22):
			continue # Concrete hub/lots do not receive sand imprints.
		_tracks.trail(index,point,wheel.get_meta("ground_normal"),-driver.global_basis.z)

func _ready() -> void:
	if level==2: vehicle_kind="buggy"
	add_to_group("yard_vehicles")
	body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	collision_shape.shape.size = Vector3(0.6, 1.2, 1.5) if level == 1 else Vector3(1.8, 1.2, 3.5)
	collision_shape.position.y = 0.6
	body.add_child(collision_shape)
	add_child(body)
	visual = Node3D.new()
	add_child(visual)
	if level==2:
		_build_headlights()
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	if level==2 and DisplayServer.get_name()!="headless":
		art.box(visual,Vector3(0.15,0.12,0.65),Vector3(0,0.45,1.95),art.STEEL)
	if level==1:
		for axle in [-0.6,0.6]:
			_add_wheel(Vector3(0,0.22,axle),0.22,0.16,art)
	else:
		for side in [-1,1]:
			for axle in [-1.1,1.15]:
				_add_wheel(Vector3(side*1.1,0.42,axle),0.42,0.25,art)
	if DisplayServer.get_name() == "headless":
		return
	if level == 1:
		paint_panels.append(art.beveled_box(visual, Vector3(0.42, 0.12, 1.45), Vector3(0, 0.3, 0), art.MINT))
		art.beam(visual, Vector3(0, 0.3, -0.55), Vector3(0, 1.35, -0.65), 0.08, art.STEEL)
		art.box(visual, Vector3(0.8, 0.07, 0.07), Vector3(0, 1.35, -0.65), art.GRAPHITE)
		art.box(visual, Vector3(0.3, 0.018, 0.9), Vector3(0, 0.37, 0.05), art.GRAPHITE)
		art.beam(visual, Vector3(0.06, 0.4, -0.55), Vector3(0.06, 1.2, -0.64), 0.018, art.GRAPHITE)
		for side in [-1,1]:
			art.box(visual, Vector3(0.2, 0.075, 0.1), Vector3(side * 0.3, 1.35, -0.65), art.GRAPHITE)
		art.box(visual, Vector3(0.13, 0.07, 0.03), Vector3(0, 1.28, -0.7), Color("#ffe6aa"))
		art.box(visual, Vector3(0.17, 0.04, 0.05), Vector3(0, 0.38, 0.66), Color("#d95b4b"))
	else:
		paint_panels.append(art.beveled_box(visual, Vector3(1.55, 0.22, 3.15), Vector3(0, 0.6, 0), art.YELLOW, true))
		var hood=art.beveled_box(visual, Vector3(1.38, 0.32, 1.2), Vector3(0, 0.95, -1.0), art.YELLOW, true)
		hood.rotation.x=0.12
		paint_panels.append(hood)
		paint_panels.append(art.beveled_box(visual, Vector3(1.65, 0.38, 1.1), Vector3(0, 1.0, 1.15), art.MINT, true))
		art.beveled_box(visual, Vector3(1.2, 0.25, 0.8), Vector3(0, 0.9, 0.1), art.GRAPHITE)
		art.beveled_box(visual, Vector3(1.2, 0.7, 0.2), Vector3(0, 1.3, 0.5), art.GRAPHITE)
		for side in [-1, 1]:
			for axle in [-1.1, 1.15]:
				art.beveled_box(visual, Vector3(0.4, 0.12, 0.95), Vector3(side * 1.1, 1.12, axle), art.YELLOW)
			art.beam(visual, Vector3(side * 0.8, 0.8, -0.55), Vector3(side * 0.75, 2.15, -0.4), 0.09, art.GRAPHITE)
			art.beam(visual, Vector3(side * 0.8, 0.8, 0.8), Vector3(side * 0.75, 2.15, 0.6), 0.09, art.GRAPHITE)
			art.beam(visual, Vector3(side * 0.75, 2.15, -0.4), Vector3(side * 0.75, 2.15, 0.6), 0.09, art.YELLOW)
			art.box(visual, Vector3(0.2, 0.2, 0.08), Vector3(side * 0.62, 1.1, -1.55), Color("#f4d985"))
		art.box(visual, Vector3(1.3, 0.13, 0.12), Vector3(0, 0.46, -1.82), art.GRAPHITE)
		for slat in 7:
			art.box(visual, Vector3(0.055, 0.18, 0.02), Vector3(-0.24 + slat * 0.08, 0.85, -1.77), art.GRAPHITE)
		art.box(visual, Vector3(1.2, 0.18, 0.16), Vector3(0, 1.18, -0.42), art.STEEL.darkened(0.3))
		art.cylinder(visual, 0.18, 0.04, Vector3(0, 1.4, -0.19), art.GRAPHITE, 28).rotation.x = 0.8
		art.beveled_box(visual,Vector3(1.65,0.07,1.25),Vector3(0,2.18,0.13),Color("#4b6159"))
		art.beam(visual,Vector3(-0.75,2.12,0.62),Vector3(0.75,0.8,0.8),0.065,art.STEEL)
		art.beam(visual,Vector3(0.75,2.12,0.62),Vector3(-0.75,0.8,0.8),0.065,art.STEEL)
		for side in [-1,1]:
			art.beam(visual,Vector3(side*0.82,0.64,-1.5),Vector3(side*0.82,0.64,1.6),0.10,art.GRAPHITE)
			art.beveled_box(visual,Vector3(0.3,0.18,0.75),Vector3(side*0.77,0.45,0),art.STEEL)
			art.beveled_box(visual,Vector3(0.13,0.24,0.09),Vector3(side*0.64,0.95,1.72),Color("#ba4c36"))
	if level == 2:
		cargo_visual = Node3D.new()
		cargo_visual.position = Vector3(0,1.22,1.15)
		visual.add_child(cargo_visual)
		GameState.operations_changed.connect(_refresh_cargo)
		_refresh_cargo()
	_build_rider(art)
	GameState.operations_changed.connect(_refresh_paint)
	_refresh_paint()
	# Interaction labels are shown only when the player aims at a usable part.

func available() -> bool:
	return visible and parked and GameState.vehicle_level >= level

func set_parked(value: bool) -> void:
	parked = value
	if value: stop_dust()
	if is_instance_valid(rider):
		rider.visible = not value
	body.collision_layer = 1 if value else 0
	for child in visual.get_children():
		if child is Label3D:
			child.visible = value
func _add_wheel(location: Vector3, radius: float, width: float, art) -> void:
	var pivot = Node3D.new()
	pivot.position = location
	pivot.set_meta("rest_position",location)
	pivot.set_meta("front", location.z < 0)
	pivot.set_meta("radius", radius)
	visual.add_child(pivot)
	wheels.append(pivot)
	if DisplayServer.get_name()=="headless":
		return
	var spinner = Node3D.new()
	pivot.add_child(spinner)
	art.cylinder(spinner, radius, width, Vector3.ZERO, art.GRAPHITE, 32).rotation.z = PI / 2
	for side in [-1,1]:
		art.cylinder(spinner, radius * 0.57, 0.02, Vector3(side * (width * 0.5 + 0.01),0,0), art.STEEL, 24).rotation.z = PI / 2
		art.cylinder(spinner, radius * 0.19, 0.025, Vector3(side * (width * 0.5 + 0.025),0,0), art.YELLOW, 20).rotation.z = PI / 2

func animate_wheels(distance: float, steering: float) -> void:
	for wheel in wheels:
		wheel.rotation.y = -steering * 0.35 if wheel.get_meta("front") else 0.0
		if wheel.get_child_count()>0:
			wheel.get_child(0).rotation.x = -distance / float(wheel.get_meta("radius"))
func _build_rider(art) -> void:
	if level in [1,2,4,5,6]:
		rider=preload("res://scripts/gameplay/worker_model.gd").new()
		rider.name="RiderBody"
		if level==1:
			rider.scooter_pose=true
			rider.seated=0.0
			rider.position.y=0.37
			rider.scale=Vector3.ONE*0.78
		visual.add_child(rider)
		rider.hide()
		return
	rider = Node3D.new()
	rider.name = "RiderBody"
	visual.add_child(rider)
	rider.hide()
	var trousers = Color("#344756")
	var jacket = Color("#ca9941")
	var shoulder_height: float = 1.2 if level == 1 else 1.35
	art.beveled_box(rider,Vector3(0.43,0.46 if level == 1 else 0.6,0.25),Vector3(0,shoulder_height,0.1),jacket)
	art.beveled_box(rider,Vector3(0.44,0.06,0.26),Vector3(0,shoulder_height-0.15,0.1),art.MINT)
	var head_height: float = 1.7 if level == 1 else 1.92
	var head = MeshInstance3D.new()
	head.name = "RiderHelmet"
	var helmet = SphereMesh.new()
	helmet.radius = 0.15
	helmet.height = 0.3
	helmet.radial_segments = 24
	helmet.rings = 12
	head.mesh = helmet
	head.position = Vector3(0,head_height,0.06)
	head.layers = 1 << 19
	head.material_override = art.surface_material(jacket,"plastic")
	rider.add_child(head)
	var visor = art.beveled_box(rider,Vector3(0.24,0.1,0.05),Vector3(0,head_height+0.01,-0.075),art.GRAPHITE)
	visor.layers = 1 << 19
	var neck = art.cylinder(rider,0.06,0.15,Vector3(0,head_height-0.2,0.07),art.GRAPHITE,24)
	neck.layers = 1 << 19
	if level == 1:
		for side in [-1,1]:
			var foot = Vector3(side*0.1,0.46,side*0.19)
			art.beveled_box(rider,Vector3(0.16,0.12,0.28),foot,art.GRAPHITE)
			art.beam(rider,foot+Vector3.UP*0.1,Vector3(side*0.13,1.0,0.12),0.16,trousers)
			art.beam(rider,Vector3(side*0.23,1.35,0.05),Vector3(side*0.3,1.35,-0.65),0.1,jacket)
			art.beveled_box(rider,Vector3(0.1,0.09,0.13),Vector3(side*0.3,1.36,-0.63),art.GRAPHITE)
	else:
		for side in [-1,1]:
			art.beam(rider,Vector3(side*0.17,0.98,0.08),Vector3(side*0.17,0.95,-0.45),0.17,trousers)
			art.beam(rider,Vector3(side*0.17,0.95,-0.45),Vector3(side*0.17,0.65,-0.62),0.15,trousers)
			art.beveled_box(rider,Vector3(0.17,0.11,0.3),Vector3(side*0.17,0.61,-0.63),art.GRAPHITE)
			art.beam(rider,Vector3(side*0.23,1.65,0.13),Vector3(side*0.18,1.4,-0.2),0.11,jacket)
func _refresh_cargo() -> void:
	if cargo_visual == null:
		return
	var next_signature: String = JSON.stringify([GameState.operations.cargo,GameState.operations.cargo_parts,GameState.workshop_modules.get("cargo_rack",0),GameState.specifics.payload().get("cargo",{})])
	if next_signature==_cargo_signature:
		return
	_cargo_signature = next_signature
	for child in cargo_visual.get_children():
		cargo_visual.remove_child(child)
		child.queue_free()
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	for side in [-1,1]:
		art.beveled_box(cargo_visual,Vector3(0.06,0.5,0.95),Vector3(side*0.78,0.22,0),art.GRAPHITE)
	var visible: int = 0
	for item in GameState.operations.cargo_parts:
		if visible >= 4:
			break
		var model = Node3D.new()
		model.position = Vector3(-0.38+(visible%2)*0.75,0.05,-0.25+(visible/2)*0.45)
		model.scale = Vector3.ONE*0.36
		cargo_visual.add_child(model)
		preload("res://scripts/gameplay/haul_part.gd").build_model(model,item.kind,int(item.quality))
		visible += 1
	if not GameState.operations.cargo.is_empty() or GameState.specifics.units("cargo")>0:
		art.beveled_box(cargo_visual,Vector3(0.55,0.35,0.65),Vector3(0,0.2,0),art.MINT)
	if int(GameState.workshop_modules.get("cargo_rack",0)) > 0:
		for side in [-1,1]:
			art.beam(cargo_visual,Vector3(side*0.75,0,0.4),Vector3(side*0.75,0.85,0.4),0.055,art.YELLOW)
		art.beam(cargo_visual,Vector3(-0.75,0.85,0.4),Vector3(0.75,0.85,0.4),0.055,art.YELLOW)

func _build_headlights() -> void:
	for side in [-1,1]:
		var light = SpotLight3D.new()
		light.position = Vector3(side*0.62,1.12,-1.65)
		light.rotation.x = -0.08
		light.light_color = Color("#ffe3ac")
		light.light_energy = 3.0
		light.spot_range = float(GameState.logistics_def.get("buggy_headlight_range_m",26))
		light.spot_angle = 35
		light.shadow_enabled = false
		visual.add_child(light)
		headlights.append(light)

func toggle_headlights() -> void:
	headlights_enabled = not headlights_enabled
	for light in headlights:
		light.visible = headlights_enabled




