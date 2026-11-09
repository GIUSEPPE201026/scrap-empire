extends RefCounted

static func supported(vehicle: Node) -> bool:
	return is_instance_valid(vehicle) and vehicle.vehicle_kind in ["buggy","dirtbike"]

static func point(vehicle: Node3D, driver: Node3D=null) -> Vector3:
	var transform: Transform3D=driver.global_transform if driver!=null and driver._mounted_vehicle==vehicle else vehicle.global_transform
	return transform*Vector3(0,0.55,2.1 if vehicle.vehicle_kind=="buggy" else 1.1)

static func candidate(player: Node3D) -> Dictionary:
	if is_instance_valid(player._mounted_vehicle): return {}
	for vehicle in player.get_tree().get_nodes_in_group("yard_vehicles"):
		if not supported(vehicle) or not vehicle.parked: continue
		var anchor: Vector3=point(vehicle)
		if player.global_position.distance_to(anchor)>3.0 or not player._aims_at(anchor,0.6,[vehicle.body.get_rid()]): continue
		for cart in player.get_tree().get_nodes_in_group("crafted_objects"):
			if cart.kind!="handcart": continue
			if cart.tow_vehicle==vehicle: return {"kind":"hitch","node":vehicle,"cart":cart,"anchor":anchor,"detach":true}
			if is_instance_valid(cart.tow_vehicle): continue
			if cart.to_global(Vector3(0,1,-1.55)).distance_to(anchor)<=2.0:
				return {"kind":"hitch","node":vehicle,"cart":cart,"anchor":anchor,"detach":false}
	return {}

static func bind(player: Node3D, cart: Node3D, vehicle: Node3D) -> void:
	cart.towing=player
	cart.tow_vehicle=vehicle
	player._towed_cart=cart
	cart.add_collision_exception_with(player)
	player.add_collision_exception_with(cart)
	cart.add_collision_exception_with(vehicle.body)

static func couple(player: Node3D, cart: Node3D, vehicle: Node3D) -> bool:
	if not supported(vehicle) or not vehicle.parked or player.global_position.distance_to(point(vehicle))>3 or cart.to_global(Vector3(0,1,-1.55)).distance_to(point(vehicle))>2.0: return false
	if is_instance_valid(cart.tow_vehicle): return false
	if not GameState.crafting.set_hitch(cart.craft_id,vehicle.vehicle_kind,cart.global_position,cart.rotation.y):
		player._notify(Localization.text("Aggancio non riuscito: moto massimo 20 kg; controlla carico e salvataggio."))
		return false
	bind(player,cart,vehicle)
	player._notify(Localization.text("Carrello collegato · sali dal sedile. H da fermo sgancia; E scendi."))
	return true

static func restore(player: Node3D) -> void:
	var saved: Dictionary=GameState.local_travel.get("trailer",{})
	for cart in player.get_tree().get_nodes_in_group("crafted_objects"):
		if cart.kind!="handcart": continue
		var kind: String=GameState.crafting.data().objects.get(cart.craft_id,{}).get("hitch","")
		if kind.is_empty(): continue
		for vehicle in player.get_tree().get_nodes_in_group("yard_vehicles"):
			if vehicle.vehicle_kind!=kind: continue
			if saved.get("id","")==cart.craft_id:
				var at: Array=saved.position
				var target=Vector3(at[0],at[1],at[2])
				var query=PhysicsShapeQueryParameters3D.new()
				query.shape=cart.get_child(0).shape
				query.transform=Transform3D(Basis(Vector3.UP,float(saved.yaw)),target+Vector3.UP*query.shape.size.y/2)
				query.exclude=[cart.get_rid(),vehicle.body.get_rid(),player.get_rid()]
				if player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
					cart.global_position=target
					cart.rotation.y=float(saved.yaw)
			if cart.global_position.distance_to(point(vehicle,player))<7:
				bind(player,cart,vehicle)
			else: player._notify(Localization.text("Carrello conservato all'ultima posizione sicura: controlla il gancio."))
			return
