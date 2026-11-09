extends "res://scripts/gameplay/yard_vehicle.gd"
var load_items: Array[Node3D]=[]
var proxies: Array[CollisionShape3D]=[]
var attachment: Node3D
var lift: float=0.2
var cable: MeshInstance3D
var unload_ready: bool=false

func motion_definition() -> Dictionary:
	return GameState.logistics_def.mobility[vehicle_kind]

func available() -> bool:
	return parked and preload("res://scripts/economy/extra_mobility.gd").owned(vehicle_kind)

func _ready() -> void:
	super._ready()
	attachment=Node3D.new()
	attachment.position.y=lift
	visual.add_child(attachment)
	if DisplayServer.get_name()=="headless": return
	paint_panels.clear()
	for child in visual.get_children():
		if child!=attachment and child!=rider and child not in wheels and child not in headlights:
			visual.remove_child(child)
			child.queue_free()
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.beveled_box(visual,Vector3(1.7,0.8,2.0),Vector3(0,0.8,0.3),art.YELLOW,true)
	for side in [-1,1]:
		art.beam(visual,Vector3(side*0.7,0.6,0.5),Vector3(side*0.7,2.4,0.5),0.09,art.STEEL)
	art.box(visual,Vector3(1.6,0.12,1.3),Vector3(0,2.45,0.1),art.YELLOW)
	if vehicle_kind=="crane":
		art.beam(visual,Vector3(0,0.8,0.7),Vector3(0,3.5,-0.1),0.35,art.RUST)
		art.beam(visual,Vector3(0,3.5,-0.1),Vector3(0,3.4,-2.6),0.25,art.YELLOW)
		cable=MeshInstance3D.new()
		var rope=CylinderMesh.new()
		rope.top_radius=0.025
		rope.bottom_radius=0.025
		rope.height=1.0
		rope.radial_segments=12
		cable.mesh=rope
		cable.material_override=art.material(art.STEEL)
		visual.add_child(cable)
		art.cylinder(attachment,0.65,0.25,Vector3(0,0.8,-2.8),art.GRAPHITE,24)
		art.beam(attachment,Vector3(0,0.1,-2.8),Vector3(0,1,-2.8),0.035,art.STEEL)
	else:
		for side in [-1,1]: art.beam(attachment,Vector3(side*0.7,0.5,0),Vector3(side*0.7,0,-2),0.16,art.RUST)
		art.beveled_box(attachment,Vector3(1.9,0.12,1.25),Vector3(0,0,-2.2),art.STEEL)
		art.box(attachment,Vector3(1.9,0.7,0.12),Vector3(0,0.35,-1.6),art.YELLOW)
		for side in [-1,1]: art.box(attachment,Vector3(0.12,0.5,1.25),Vector3(side*0.9,0.25,-2.2),art.YELLOW)
	_update_cable()

func _update_cable() -> void:
	if not is_instance_valid(cable): return
	var top=Vector3(0,3.4,-2.6)
	var bottom=attachment.position+Vector3(0,0.95,-2.8)
	var axis: Vector3=bottom-top
	cable.transform=Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())).scaled(Vector3(1,axis.length(),1)),(top+bottom)*0.5)

func payload_point() -> Vector3:
	return attachment.to_global(Vector3(0,-0.1,-2.8) if vehicle_kind=="crane" else Vector3(0,0.08,-2.2))

func _shape(item: Node3D) -> CollisionShape3D:
	for child in item.get_children():
		if child is CollisionShape3D: return child
	return null

func _physics_process(delta: float) -> void:
	var driver=visual.get_parent()
	if parked or not driver is CharacterBody3D or driver._is_paused: return
	unload_ready=not load_items.is_empty() and absf(driver._vehicle_speed)<=1.0 and preload("res://scripts/economy/industrial_unload.gd").nearby(self,driver)
	var previous_lift: float=lift
	lift=clampf(lift+(float(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))-float(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))*delta*0.7*GameState.module_effect("hydraulics"),0.2,2.3 if vehicle_kind=="crane" else 1.4)
	attachment.position.y=lift
	var pending: Array[Transform3D]=[]
	var proxy_poses: Array[Transform3D]=[]
	for index in load_items.size():
		var item=load_items[index]
		if not is_instance_valid(item): continue
		var point: Vector3=payload_point()+visual.global_basis*Vector3((index%2)*0.5-0.25,0,(index/2)*0.45)
		var shape=_shape(item)
		var candidate=Transform3D(visual.global_basis,point)*shape.transform
		var query=PhysicsShapeQueryParameters3D.new()
		query.shape=shape.shape
		query.transform=candidate
		var excluded: Array[RID]=[driver.get_rid(),body.get_rid()]
		for other in load_items: excluded.append(other.get_rid())
		query.exclude=excluded
		if not driver.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			lift=previous_lift
			attachment.position.y=lift
			driver.velocity=Vector3.ZERO
			driver._vehicle_motion.speed=0
			return
		pending.append(Transform3D(visual.global_basis,point))
		proxy_poses.append(driver.global_transform.affine_inverse()*candidate)
	for index in pending.size():
		load_items[index].global_transform=pending[index]
		proxies[index].transform=proxy_poses[index]
	_update_cable()

func payload_mass() -> float:
	var amount: float=0
	for item in load_items:
		amount+=float(GameState.part_defs[item.kind].mass_kg) if item.is_in_group("bulk_parts") else float(item.mass)
	return amount

func payload_ids() -> Array:
	var result: Array=[]
	for item in load_items:
		result.append(("part:"+item.part_id) if item.is_in_group("bulk_parts") else ("scrap:"+item.entity_id))
	return result

func restore_payload(driver: CharacterBody3D, ids: Array, height: float) -> bool:
	if ids.is_empty(): return true
	if ids.size()>int(motion_definition().capacity_items) or not is_finite(height) or height<0.2 or height>(2.3 if vehicle_kind=="crane" else 1.4): return false
	if not load_items.is_empty(): return false
	var found: Array[Node3D]=[]
	var mass: float=0
	for id in ids:
		var group: String="bulk_parts" if str(id).begins_with("part:") else "scrap"
		var wanted: String=str(id).get_slice(":",1)
		var match_item: Node3D
		for item in get_tree().get_nodes_in_group(group):
			if (str(item.part_id) if group=="bulk_parts" else str(item.entity_id))==wanted: match_item=item; break
		if match_item==null: return false
		if found.has(match_item): return false
		if vehicle_kind=="crane" and (group!="bulk_parts" or match_item.kind not in ["engine","frame","panel"]): return false
		if vehicle_kind=="loader" and group!="scrap": return false
		mass+=float(GameState.part_defs[match_item.kind].mass_kg) if group=="bulk_parts" else float(match_item.mass)
		if mass>float(motion_definition().capacity_kg): return false
		found.append(match_item)
	var origin: float=lift
	lift=height
	attachment.position.y=lift
	var excluded: Array[RID]=[driver.get_rid(),body.get_rid()]
	for item in found: excluded.append(item.get_rid())
	var positions: Array[Transform3D]=[]
	for index in found.size():
		var point: Vector3=payload_point()+visual.global_basis*Vector3((index%2)*0.5-0.25,0,(index/2)*0.45)
		var transform=Transform3D(visual.global_basis,point)
		var query=PhysicsShapeQueryParameters3D.new()
		query.shape=_shape(found[index]).shape
		query.transform=transform*_shape(found[index]).transform
		query.exclude=excluded
		if not driver.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			lift=origin
			attachment.position.y=lift
			return false
		positions.append(transform)
	for index in found.size():
		found[index].global_transform=positions[index]
		_attach(driver,found[index])
	return true

func _attach(driver: CharacterBody3D, item: Node3D) -> void:
	load_items.append(item)
	item.set_meta("industrial_carrier",self)
	if item is PhysicsBody3D: driver.add_collision_exception_with(item)
	var collider=_shape(item)
	var proxy=CollisionShape3D.new()
	proxy.shape=collider.shape.duplicate()
	proxy.transform=driver.global_transform.affine_inverse()*item.global_transform*collider.transform
	driver.add_child(proxy)
	proxies.append(proxy)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H and vehicle_kind=="loader":
		var operator=visual.get_parent()
		if not parked and operator is CharacterBody3D and not operator._is_paused:
			if not preload("res://scripts/gameplay/loader_earthwork.gd").stroke(self,operator): operator._notify(Localization.text("Benna bassa e vuota · avvicinati a macerie leggere, con spazio davanti"))
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_G: return
	var driver=visual.get_parent()
	if parked or not driver is CharacterBody3D or driver._is_paused: return
	if absf(driver._vehicle_speed)>1.0: driver._notify(Localization.text("Fermati prima di usare il carico")); return
	if not load_items.is_empty():
		if preload("res://scripts/economy/industrial_unload.gd").nearby(self,driver):
			if not preload("res://scripts/economy/industrial_unload.gd").unload(self,driver): driver._notify(Localization.text("Scarico non riuscito: controlla attrezzi, richieste riservate o salvataggio"))
		elif not release_load(driver): driver._notify(Localization.text("Abbassa il carico su una superficie libera"))
	else:
		if not pickup(driver): driver._notify(Localization.text("Avvicina l'attrezzo basso a un oggetto compatibile"))
	get_viewport().set_input_as_handled()

func pickup(driver: CharacterBody3D) -> bool:
	if not load_items.is_empty() or lift>0.4: return false
	var candidates: Array=get_tree().get_nodes_in_group("bulk_parts") if vehicle_kind=="crane" else get_tree().get_nodes_in_group("scrap")
	for item in candidates:
		if item.is_queued_for_deletion(): continue
		if vehicle_kind=="crane" and item.kind not in ["engine","frame","panel"]: continue
		var mass: float=float(GameState.part_defs[item.kind].mass_kg) if item.is_in_group("bulk_parts") else float(item.mass)
		if mass+payload_mass()>float(motion_definition().capacity_kg): continue
		if item.global_position.distance_to(payload_point())>1.8: continue
		var query=PhysicsRayQueryParameters3D.create(visual.global_position+Vector3.UP, item.global_position+Vector3.UP*0.4,1,[driver.get_rid(),body.get_rid(),item.get_rid()])
		if not driver.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var collider=_shape(item)
		if collider==null: continue
		_attach(driver,item)
		if load_items.size()>=int(motion_definition().capacity_items): break
	return not load_items.is_empty()

func release_load(driver: CharacterBody3D) -> bool:
	if load_items.is_empty(): return true
	var targets: Array[Vector3]=[]
	for item in load_items:
		var hit: Dictionary=driver.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(item.global_position+Vector3.UP*0.1,item.global_position-Vector3.UP*4,1,[driver.get_rid(),body.get_rid(),item.get_rid()]))
		if hit.is_empty() or hit.normal.y<0.8: return false
		var target: Vector3=hit.position+Vector3.UP*0.12
		var space=PhysicsShapeQueryParameters3D.new()
		space.shape=_shape(item).shape
		space.transform=Transform3D(item.global_basis,target)*_shape(item).transform
		var excluded: Array[RID]=[driver.get_rid(),body.get_rid()]
		for other in load_items: excluded.append(other.get_rid())
		space.exclude=excluded
		if not driver.get_world_3d().direct_space_state.intersect_shape(space,1).is_empty(): return false
		targets.append(target)
	var before: Dictionary=GameState.serialize().duplicate(true)
	if not GameState.operations.has("loose_positions"): GameState.operations.loose_positions={}
	for index in load_items.size():
		var item=load_items[index]
		var at: Vector3=targets[index]
		if item.is_in_group("bulk_parts"):
			GameState.operations.field[item.part_id].position=[at.x,at.y,at.z]
			GameState.operations.field[item.part_id].dropped=true
		else: GameState.operations.loose_positions[item.entity_id]=[at.x,at.y,at.z]
	if not GameState.ops._finish(before): return false
	for index in load_items.size():
		load_items[index].global_position=targets[index]
		load_items[index].remove_meta("industrial_carrier")
		if load_items[index] is PhysicsBody3D: driver.remove_collision_exception_with(load_items[index])
		proxies[index].set_deferred("disabled",true)
		proxies[index].queue_free()
	load_items.clear()
	proxies.clear()
	return true
