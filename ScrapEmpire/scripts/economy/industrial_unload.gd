extends RefCounted

static func nearby(machine: Node3D, driver: Node3D) -> bool:
	var points: Array[Node]=driver.get_tree().get_nodes_in_group("field_depot")
	var sector=driver.get_tree().get_first_node_in_group("sector")
	if sector!=null: points.append(sector.get_node("DepositZone"))
	for node in driver.get_tree().get_nodes_in_group("operations_service"):
		if node.get_meta("operation","") in ["warehouse","recovery"]: points.append(node)
	for point in points:
		if machine.payload_point().distance_to(point.global_position)>4.0: continue
		var excluded: Array[RID]=[driver.get_rid(),machine.body.get_rid()]
		if point is CollisionObject3D: excluded.append(point.get_rid())
		for item in machine.load_items: excluded.append(item.get_rid())
		var query=PhysicsRayQueryParameters3D.create(machine.payload_point()+Vector3.UP*0.8,point.global_position+Vector3.UP*1.2,1,excluded)
		if driver.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return true
	return false

static func unload(machine: Node3D, driver: Node3D) -> bool:
	if driver._mounted_vehicle!=machine or absf(driver._vehicle_speed)>1.0 or machine.load_items.is_empty() or not nearby(machine,driver): return false
	var identities: Dictionary={}
	for item in machine.load_items:
		if not is_instance_valid(item) or item.is_queued_for_deletion(): return false
		var id: String=item.part_id if item.is_in_group("bulk_parts") else item.entity_id
		if identities.has(id): return false
		identities[id]=true
		if item.is_in_group("bulk_parts"):
			if not GameState.operations.field.has(id) or GameState.operations.stored_parts.size()+machine.load_items.size()>1000: return false
		else:
			var material: String=driver._scrap_type_to_material_id(item.scrap_type)
			var index: int=id.get_slice("_",1).to_int()
			if index<0 or index>=int(GameState.sector_initial_counts.get(material,0)) or id!="%s_%03d" % [material,index] or id in GameState.sector_consumed_ids: return false
			var permitted: bool=false
			for tool in GameState.material_defs[material].get("tools",[0]): permitted=permitted or GameState.recovery_allowed(material,int(tool))
			if not permitted: return false
			var variant: int=preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(id)
			if GameState.specifics.needs("%d_%d" % [int(item.scrap_type),variant]): return false
	var before: Dictionary=GameState.serialize().duplicate(true)
	var loaded: Array=machine.load_items.duplicate()
	for item in loaded:
		if item.is_in_group("bulk_parts"):
			var stored: Dictionary=GameState.operations.field[item.part_id].duplicate(true)
			stored.erase("position")
			stored.erase("dropped")
			GameState.operations.stored_parts.append(stored)
			GameState.operations.field.erase(item.part_id)
		else:
			var material: String=driver._scrap_type_to_material_id(item.scrap_type)
			GameState.team_deposit_counts[material]+=1
			GameState.mark_scrap_consumed(item.entity_id)
			var album: Array=GameState.operations.get("scrap_album",[]).duplicate()
			var key: String="%d_%d" % [int(item.scrap_type),preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(item.entity_id)]
			if key not in album: album.append(key)
			GameState.operations.scrap_album=album
	# The saved travel snapshot must no longer reference deposited objects.
	machine.load_items.clear()
	preload("res://scripts/economy/industrial_jobs.gd").record(machine.vehicle_kind,loaded.size())
	if not GameState.ops._finish(before):
		machine.load_items.assign(loaded)
		return false
	for item in loaded:
		if is_instance_valid(item):
			if item is PhysicsBody3D: driver.remove_collision_exception_with(item)
			if not item.is_queued_for_deletion(): item.queue_free()
	for proxy in machine.proxies:
		proxy.set_deferred("disabled",true)
		proxy.queue_free()
	machine.proxies.clear()
	driver._play_feedback("deposit")
	driver._notify(Localization.text("Carico depositato · materiali e componenti conservati, nessuna vendita"))
	return true
