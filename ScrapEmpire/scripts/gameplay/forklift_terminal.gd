extends RefCounted
## Seated pallet handling. Sale is always a separate, explicit action.

static func station(machine: Node3D, driver: CharacterBody3D) -> String:
	if driver._mounted_vehicle!=machine or not is_instance_valid(machine.carried): return ""
	var points: Array[Node]=driver.get_tree().get_nodes_in_group("operations_service")
	var sector=driver.get_tree().get_first_node_in_group("sector")
	if sector!=null: points.append(sector.get_node("DepositZone"))
	for point in points:
		var kind: String=str(point.get_meta("operation","warehouse"))
		if kind not in ["warehouse","recovery","dispatch"] or machine.carried.global_position.distance_to(point.global_position)>4.0: continue
		var excluded: Array[RID]=[driver.get_rid(),machine.body.get_rid(),machine.carried.get_rid()]
		if point is CollisionObject3D: excluded.append(point.get_rid())
		var query=PhysicsRayQueryParameters3D.create(machine.carried.global_position+Vector3.UP*1.3,point.global_position+Vector3.UP*1.3,1,excluded)
		if driver.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return "dispatch" if kind=="dispatch" else "warehouse"
	return ""

static func execute(machine: Node3D, driver: CharacterBody3D, action: String, expected: int, ticket: int) -> bool:
	if driver._mounted_vehicle!=machine or absf(driver._vehicle_speed)>1.0 or not is_instance_valid(machine.carried): return false
	var id: String=machine.carried.craft_id
	var object: Dictionary=GameState.crafting.data().objects.get(id,{})
	if object.get("kind","")!="bale_pallet" or int(object.get("bales",0))!=expected: return false
	var location: String=station(machine,driver)
	var success: bool=false
	if action=="ship":
		if location!="dispatch": return false
		success=GameState.crafting.ship_pallet(id,ticket)
	elif action in ["load","return"]:
		if location!="warehouse": return false
		if action=="load":
			var amount: int=mini(GameState.press_bales,int(GameState.logistics_def.crafting.bale_pallet.capacity_bales)-expected)
			if amount<=0 or not fits(machine,driver,expected+amount): return false
		success=GameState.crafting.transfer_bales(id,action=="load")
	if success:
		machine.sync_load_collision(driver)
		if action!="ship": driver._play_feedback("deposit")
	return success

static func fits(machine: Node3D, driver: CharacterBody3D, bales: int) -> bool:
	var shape=BoxShape3D.new()
	shape.size=Vector3(1.4,0.22+ceilf(bales/2.0)*0.48,1.2)
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=machine.carried.global_transform*Transform3D(Basis.IDENTITY,Vector3.UP*shape.size.y/2)
	query.exclude=[driver.get_rid(),machine.body.get_rid(),machine.carried.get_rid()]
	return driver.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
