extends RefCounted

static func stroke(machine: Node3D, driver: Node3D) -> bool:
	if driver._mounted_vehicle!=machine or machine.vehicle_kind!="loader" or not machine.load_items.is_empty() or machine.lift>0.4 or absf(driver._vehicle_speed)>1.0: return false
	var at: Vector3=machine.payload_point()
	var choice: Dictionary={}
	var nearest: float=2.0
	for source in driver.get_tree().get_nodes_in_group("heap_fragment_sources"):
		if source.scenery_piece or source.owner_pile.global_position.distance_to(at)>20: continue
		var cell=Vector2i(floori(at.x/2),floori(at.z/2))
		for x in range(cell.x-2,cell.x+3):
			for z in range(cell.y-2,cell.y+3):
				for index in source.cells.get(Vector2i(x,z),[]):
					var record: Dictionary=source.records[index]
					if record.has("batch") and record.batch.multimesh.visible_instance_count>=0 and record.index>=record.batch.multimesh.visible_instance_count: continue
					var point: Vector3=source.taken[record.id].global_position if source.taken.has(record.id) else record.transform.origin
					var dimensions: Vector3=record.bounds.size*record.transform.basis.get_scale()
					var mass: float=clampf(dimensions.x*dimensions.y*dimensions.z*35,1,180)
					if mass>float(machine.motion_definition().capacity_kg) or point.distance_to(at)>=nearest: continue
					choice={"source":source,"index":index}
					nearest=point.distance_to(at)
	if choice.is_empty(): return false
	var fragment: Node3D=choice.source.promote(choice.index)
	var forward: Vector3=-driver.global_basis.z
	var destination: Vector3=fragment.global_position+forward*1.3
	var ground: Dictionary=driver.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(destination+Vector3.UP*4,destination-Vector3.UP*6,1,[driver.get_rid(),machine.body.get_rid(),fragment.get_rid()]))
	if ground.is_empty() or ground.normal.y<0.55: return false
	destination=ground.position+Vector3.UP*fragment.get_drag_ground_offset()
	var collider: CollisionShape3D=fragment.get_child(0)
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=collider.shape
	query.transform=collider.global_transform
	query.motion=destination-fragment.global_position
	var excluded: Array[RID]=[driver.get_rid(),machine.body.get_rid(),fragment.get_rid()]
	if choice.source.owner_pile is CollisionObject3D: excluded.append(choice.source.owner_pile.get_rid())
	query.exclude=excluded
	var travel: PackedFloat32Array=driver.get_world_3d().direct_space_state.cast_motion(query)
	if travel[0]<0.98: return false
	query.motion=Vector3.ZERO
	query.transform.origin+=destination-fragment.global_position
	query.exclude=[driver.get_rid(),machine.body.get_rid(),fragment.get_rid()]
	if not driver.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	var before: Dictionary=GameState.serialize().duplicate(true)
	if not GameState.operations.has("loose_positions"): GameState.operations.loose_positions={}
	GameState.operations.loose_positions[fragment.entity_id]=[destination.x,destination.y,destination.z]
	if not GameState.ops._finish(before): return false
	fragment.global_position=destination
	driver._notify(Localization.text("Macerie spostate · cerca i rottami rimasti scoperti"))
	return true
