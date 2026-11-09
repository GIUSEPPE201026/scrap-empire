extends "res://scripts/gameplay/yard_vehicle.gd"
var forks: Node3D
var carried: CharacterBody3D
var lift: float=0.12
var load_collision: CollisionShape3D
var notice_cooldown: float=0.0

func motion_definition() -> Dictionary:
	return GameState.logistics_def.mobility.forklift

func available() -> bool:
	return parked and preload("res://scripts/economy/extra_mobility.gd").owned("forklift")

func _ready() -> void:
	super._ready()
	vehicle_kind="forklift"
	forks=Node3D.new()
	visual.add_child(forks)
	if DisplayServer.get_name()=="headless": return
	paint_panels.clear()
	for child in visual.get_children():
		if child!=forks and child!=rider and child not in wheels and child not in headlights:
			visual.remove_child(child)
			child.queue_free()
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.beveled_box(visual,Vector3(1.55,0.7,1.8),Vector3(0,0.7,0.3),art.YELLOW,true)
	art.beveled_box(visual,Vector3(1.5,0.85,0.65),Vector3(0,1.15,1.05),art.GRAPHITE)
	for side in [-1,1]:
		art.beam(visual,Vector3(side*0.7,0.6,0.7),Vector3(side*0.7,2.5,0.7),0.07,art.STEEL)
		art.beam(visual,Vector3(side*0.7,0.6,-0.4),Vector3(side*0.7,2.5,-0.4),0.07,art.STEEL)
		art.box(visual,Vector3(0.14,2.5,0.18),Vector3(side*0.55,1.35,-1.2),art.GRAPHITE)
		art.box(forks,Vector3(0.14,0.1,1.5),Vector3(side*0.4,0,-1.9),art.STEEL)
	art.box(visual,Vector3(1.6,0.1,1.4),Vector3(0,2.55,0.15),art.YELLOW)
	art.box(forks,Vector3(1.3,0.18,0.15),Vector3(0,0.12,-1.2),art.STEEL)

func _physics_process(delta: float) -> void:
	var driver=visual.get_parent()
	if parked or not driver is CharacterBody3D or driver._is_paused: return
	notice_cooldown=maxf(0.0,notice_cooldown-delta)
	var direction: float=float(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))-float(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	var previous_lift: float=lift
	lift=clampf(lift+direction*delta*0.7*GameState.module_effect("hydraulics"),0.12,1.55)
	forks.position.y=lift
	if is_instance_valid(carried):
		var target: Transform3D=forks.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0.05,-1.9))
		var query=PhysicsShapeQueryParameters3D.new()
		query.shape=carried.get_child(0).shape
		query.transform=target*Transform3D(Basis.IDENTITY,Vector3.UP*query.shape.size.y/2)
		query.exclude=[driver.get_rid(),body.get_rid(),carried.get_rid()]
		if not driver.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			lift=previous_lift
			forks.position.y=lift
			driver.velocity=Vector3.ZERO
			driver._vehicle_motion.speed=0.0
			if notice_cooldown<=0:
				driver._notify(Localization.text("Carico bloccato · abbassa le forche o arretra"))
				notice_cooldown=2.0
			return
		carried.global_transform=target
		if is_instance_valid(load_collision): load_collision.transform=driver.global_transform.affine_inverse()*query.transform

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H:
		var driver=visual.get_parent()
		if not parked and driver is CharacterBody3D and not driver._is_paused:
			if absf(driver._vehicle_speed)>1.0: driver._notify(Localization.text("Fermati prima di aprire il terminale pallet"))
			else: preload("res://scripts/ui/forklift_terminal_panel.gd").open(driver,self)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_G:
		var driver=visual.get_parent()
		if not parked and driver is CharacterBody3D and not driver._is_paused and absf(driver._vehicle_speed)<1.5:
			if not toggle_load(driver): driver._notify(Localization.text("Avvicina e allinea le forche basse al pallet, in uno spazio libero."))
			get_viewport().set_input_as_handled()
		elif not parked and driver is CharacterBody3D and not driver._is_paused:
			driver._notify(Localization.text("Fermati prima di agganciare o rilasciare il pallet"))

func toggle_load(driver: CharacterBody3D) -> bool:
	if is_instance_valid(carried): return release_load(driver)
	if lift>0.35: return false
	var target: Vector3=forks.to_global(Vector3(0,0,-1.9))
	for pallet in get_tree().get_nodes_in_group("crafted_objects"):
		if pallet.kind!="bale_pallet" or pallet.global_position.distance_to(target)>1.0: continue
		var query=PhysicsRayQueryParameters3D.create(visual.global_position+Vector3.UP*0.4,pallet.global_position+Vector3.UP*0.15,1,[driver.get_rid(),body.get_rid(),pallet.get_rid()])
		if not driver.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		carried=pallet
		carried.add_collision_exception_with(driver)
		driver.add_collision_exception_with(carried)
		carried.set_meta("carried_by",self)
		load_collision=CollisionShape3D.new()
		load_collision.shape=carried.get_child(0).shape.duplicate()
		load_collision.transform=driver.global_transform.affine_inverse()*carried.global_transform*Transform3D(Basis.IDENTITY,Vector3.UP*load_collision.shape.size.y/2)
		driver.add_child(load_collision)
		driver._notify(Localization.text("Pallet agganciato · sinistro/destro alza/abbassa · G rilascia"))
		return true
	return false

func sync_load_collision(driver: CharacterBody3D) -> void:
	if not is_instance_valid(carried) or not is_instance_valid(load_collision): return
	load_collision.shape=carried.get_child(0).shape.duplicate()
	load_collision.transform=driver.global_transform.affine_inverse()*carried.global_transform*Transform3D(Basis.IDENTITY,Vector3.UP*load_collision.shape.size.y/2)

func restore_load(driver: CharacterBody3D, id: String, height: float) -> bool:
	if id.is_empty(): return true
	for pallet in get_tree().get_nodes_in_group("crafted_objects"):
		if pallet.craft_id!=id or pallet.kind!="bale_pallet": continue
		var previous: Transform3D=pallet.global_transform
		lift=0.12
		forks.position.y=lift
		var target: Transform3D=forks.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0.05,-1.9))
		var query=PhysicsShapeQueryParameters3D.new()
		query.shape=pallet.get_child(0).shape
		query.transform=target*Transform3D(Basis.IDENTITY,Vector3.UP*query.shape.size.y/2)
		query.exclude=[driver.get_rid(),body.get_rid(),pallet.get_rid()]
		if not driver.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
		pallet.global_transform=target
		if toggle_load(driver):
			lift=clampf(height,0.12,1.55)
			return true
		pallet.global_transform=previous
	return false

func release_load(driver: CharacterBody3D) -> bool:
	if not is_instance_valid(carried): return true
	var query=PhysicsRayQueryParameters3D.create(carried.global_position+Vector3.UP*0.1,carried.global_position-Vector3.UP*2.5,1,[driver.get_rid(),body.get_rid(),carried.get_rid()])
	var hit: Dictionary=driver.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y<0.9: return false
	var target: Vector3=hit.position+Vector3.UP*0.02
	var space=PhysicsShapeQueryParameters3D.new()
	space.shape=carried.get_child(0).shape
	space.transform=Transform3D(Basis(Vector3.UP,driver._vehicle_heading),target+Vector3.UP*space.shape.size.y/2)
	space.exclude=[driver.get_rid(),body.get_rid(),carried.get_rid()]
	if not driver.get_world_3d().direct_space_state.intersect_shape(space).is_empty(): return false
	if not GameState.crafting.move_object(carried.craft_id,target,driver._vehicle_heading): return false
	carried.remove_meta("carried_by")
	if is_instance_valid(load_collision):
		load_collision.set_deferred("disabled",true)
		load_collision.queue_free()
		load_collision=null
	carried.global_position=target
	carried.global_rotation=Vector3(0,driver._vehicle_heading,0)
	carried.remove_collision_exception_with(driver)
	driver.remove_collision_exception_with(carried)
	carried=null
	return true
