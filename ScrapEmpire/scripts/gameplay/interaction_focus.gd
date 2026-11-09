extends RefCounted
## One spatial selection feeds both the floating prompt and E activation.
static func resolve(player) -> Dictionary:
	if player._vehicle_exit_time>0: return {"kind":"none"}
	if is_instance_valid(player._mounted_vehicle):
		if is_instance_valid(player._towed_cart) and not is_instance_valid(player._towed_cart.tow_vehicle):
			return {"kind":"uncouple","node":player._towed_cart,"anchor":player._towed_cart.global_position+Vector3.UP}
		return {"kind":"dismount","node":player._mounted_vehicle,"anchor":player.global_position+Vector3.UP*2.8}
	var hitch: Dictionary=preload("res://scripts/gameplay/cart_hitch.gd").candidate(player)
	if not hitch.is_empty(): return hitch
	if is_instance_valid(player._towed_cart):
		var vehicle=player._nearest_vehicle()
		if vehicle!=null and vehicle.level in [2,3] and (not is_instance_valid(player._towed_cart.tow_vehicle) or player._towed_cart.tow_vehicle==vehicle):
			return {"kind":"vehicle","node":vehicle,"anchor":vehicle.to_global(Vector3(0,1.45,0.15))}
		if not is_instance_valid(player._towed_cart.tow_vehicle): return {"kind":"uncouple","node":player._towed_cart,"anchor":player._towed_cart.global_position+Vector3.UP}
	if not GameState.operations.held.is_empty():
		return {"kind":"carry","anchor":player.camera.global_position-player.camera.global_basis.z*1.5+Vector3.UP*0.4}
	var candidates: Array[Dictionary] = []
	var crafted = player._near_crafted()
	if crafted!=null:
		candidates.append({"kind":"crafted","node":crafted,"aim":crafted.global_position+Vector3.UP*0.4,"anchor":crafted.global_position+Vector3.UP*1.2,"radius":0.9,"exclude":[crafted.get_rid()]})
	var cargo = player._near_cargo_bay()
	if cargo!=null:
		candidates.append({"kind":"cargo","node":cargo,"aim":cargo.to_global(Vector3(0,1.2,1.6)),"anchor":cargo.to_global(Vector3(0,1.55,1.7)),"exclude":[cargo.body.get_rid()]})
	var vehicle = player._nearest_vehicle()
	if vehicle!=null:
		candidates.append({"kind":"vehicle","node":vehicle,"aim":vehicle.to_global(Vector3(0,1.2,0.15)),"anchor":vehicle.to_global(Vector3(0,1.45,0.15)),"exclude":[vehicle.body.get_rid()]})
	for group in ["bulk_parts","operations_service","service_terminal","field_depot","world_secrets"]:
		for node in player.get_tree().get_nodes_in_group(group):
			if player.global_position.distance_to(node.global_position)>3.0:
				continue
			var entry: Dictionary = {"node":node,"radius":0.75,"exclude":[node.get_rid()] if node is CollisionObject3D else []}
			match group:
				"bulk_parts": entry.merge({"kind":"bulk","aim":node.global_position+Vector3.UP*0.35,"anchor":node.global_position+Vector3.UP*1.25})
				"operations_service": entry.merge({"kind":"operation","service":str(node.get_meta("operation")),"aim":node.global_position+Vector3.UP*1.2,"anchor":node.global_position+Vector3.UP*2})
				"service_terminal": entry.merge({"kind":"terminal","service":str(node.get_meta("service")),"aim":node.global_position+Vector3.UP*1.3,"anchor":node.global_position+Vector3.UP*(2.85 if node.get_meta("service")=="tools" else 2.55)})
				"field_depot": entry.merge({"kind":"field_depot","aim":node.global_position+Vector3.UP,"anchor":node.global_position+Vector3.UP*2})
				"world_secrets": entry.merge({"kind":"secret","aim":node.global_position+Vector3.UP*0.8,"anchor":node.global_position+Vector3.UP*2.3})
			candidates.append(entry)
	var press = player.get_tree().get_first_node_in_group("industrial_press")
	if player._near_press():
		candidates.append({"kind":"press","node":press,"aim":press.interaction_position()+Vector3.UP*1.2,"anchor":press.interaction_position()+Vector3.UP*2,"radius":1.0})
	if player._near_depot():
		var depot = player.get_tree().get_first_node_in_group("sector").get_node("DepositZone")
		candidates.append({"kind":"depot","node":depot,"aim":depot.global_position+Vector3.UP,"anchor":depot.global_position+Vector3.UP*2.3,"radius":1.3})
	var selected: Dictionary = {"kind":"none"}
	var best: float = INF
	for entry in candidates:
		if not player._aims_at(entry.aim,float(entry.get("radius",0.75)),entry.get("exclude",[])):
			continue
		var direction: Vector3 = (entry.aim-player.camera.global_position).normalized()
		var score: float = (1.0-direction.dot(-player.camera.global_basis.z))*10.0+player.camera.global_position.distance_to(entry.aim)*0.03
		if score<best:
			selected=entry
			best=score
	return selected
