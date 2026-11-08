extends RefCounted

static func point_valid(point: Variant) -> bool:
	if not point is Array or point.size()!=3:
		return false
	for coordinate in point:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
			return false
	var below: float=-18.0 if preload("res://scripts/gameplay/subterranean_cave.gd").contains(Vector3(point[0],point[1],point[2])) else -10.0
	return absf(float(point[0]))<=638 and absf(float(point[2]))<=638 and float(point[1])>=below and float(point[1])<=100

static func _point(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

static func capture(game) -> Dictionary:
	var result: Dictionary = game.local_travel.duplicate(true)
	if int(result.get("epoch",-1))!=int(game.operations.epoch):
		result={}
	var player = game.get_tree().get_first_node_in_group("players")
	if player==null or not player.is_local_player or player.local_expedition_epoch!=int(game.operations.epoch):
		return result
	var point: Array = _point(player.global_position)
	if point_valid(point):
		result.epoch=int(game.operations.epoch)
		result.player={"position":point,"yaw":wrapf(player.look_rotation.y,-PI,PI),"pitch":clampf(player.look_rotation.x,-1.4,1.4),"vehicle":player._mounted_vehicle.level if is_instance_valid(player._mounted_vehicle) else 0,"third_person":player._vehicle_third_person,"mobility":player._mounted_vehicle.vehicle_kind if is_instance_valid(player._mounted_vehicle) else ""}
	for vehicle in game.get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.level==2 and game.vehicle_level>=2 and point_valid(_point(vehicle.global_position)):
			result.epoch=int(game.operations.epoch)
			var mounted: bool = player._mounted_vehicle==vehicle
			result.buggy={"position":_point(player.global_position if mounted else vehicle.global_position),"yaw":wrapf(player._vehicle_heading if mounted else vehicle.rotation.y,-PI,PI),"headlights":vehicle.headlights_enabled,"pitch":clampf(vehicle.visual.rotation.x,-0.9,0.9),"roll":clampf(vehicle.visual.rotation.z,-0.9,0.9)}
	for vehicle in game.get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.vehicle_kind=="dirtbike" and preload("res://scripts/economy/extra_mobility.gd").owned("dirtbike") and point_valid(_point(player.global_position if player._mounted_vehicle==vehicle else vehicle.global_position)):
			var mounted: bool=player._mounted_vehicle==vehicle
			result.dirtbike={"position":_point(player.global_position if mounted else vehicle.global_position),"yaw":wrapf(player._vehicle_heading if mounted else vehicle.rotation.y,-PI,PI),"headlights":vehicle.headlights_enabled,"pitch":clampf(vehicle.visual.rotation.x,-0.9,0.9),"roll":clampf(vehicle.visual.rotation.z,-0.9,0.9)}
	return result

static func validate(value: Variant, save: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if not SaveService._valid_count(value.get("epoch")) or int(value.epoch)!=int(save.get("operations",{}).get("epoch",0)):
		return false
	for key in ["player","buggy","dirtbike"]:
		if not value.has(key):
			continue
		var pose = value[key]
		if not pose is Dictionary or not point_valid(pose.get("position")):
			return false
		for angle in ["yaw","pitch"]+(["roll"] if key!="player" else []):
			if not (pose.get(angle) is int or pose.get(angle) is float) or not is_finite(float(pose[angle])) or absf(float(pose[angle]))>(PI if angle=="yaw" else 1.4):
				return false
		if key=="player":
			if not SaveService._valid_count(pose.get("vehicle")) or int(pose.vehicle)>3 or not pose.get("third_person") is bool:
				return false
			var mobility: String=str(pose.get("mobility","scooter" if int(pose.vehicle)==1 else ("buggy" if int(pose.vehicle)==2 else "")))
			if mobility not in {0:[""],1:["scooter","skateboard"],2:["buggy"],3:["dirtbike"]}[int(pose.vehicle)]: return false
			var owned: Array=save.get("operations",{}).get("mobility",{}).get("owned",[])
			if int(pose.vehicle)==3 and (mobility!="dirtbike" or "dirtbike" not in owned): return false
			if int(pose.vehicle)==1 and mobility=="skateboard":
				if "skateboard" not in owned: return false
			elif int(pose.vehicle)<=2 and int(pose.vehicle)>int(save.get("vehicle_level",0)): return false
			if mobility not in ["","scooter","buggy","skateboard","dirtbike"]: return false
		else:
			if not pose.get("headlights") is bool: return false
			if key=="buggy" and int(save.get("vehicle_level",0))<2: return false
			if key=="dirtbike" and "dirtbike" not in save.get("operations",{}).get("mobility",{}).get("owned",[]): return false
	return true

static func _ground(player, desired: Vector3, excluded: Array[RID]) -> Dictionary:
	# A landscape revision may raise a dune above an older checkpoint's altitude.
	var top: Vector3=desired+Vector3.UP*2.2
	top.y=maxf(top.y,preload("res://scripts/gameplay/desert_world.gd").height_at(desired)+2.2)
	if preload("res://scripts/gameplay/subterranean_cave.gd").contains(desired) and desired.y< -1: top=desired+Vector3.UP*2.2
	var query = PhysicsRayQueryParameters3D.create(top,desired-Vector3.UP*8,1,excluded)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() and hit.normal.y>0.45 else {}

static func restore(player) -> void:
	var travel: Dictionary = GameState.local_travel.duplicate(true)
	if travel.is_empty() or int(travel.get("epoch",-1))!=int(GameState.operations.epoch):
		return
	var tree: SceneTree = player.get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var buggy: Node3D
	for vehicle in player.get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.level==2:
			buggy=vehicle
	if travel.has("buggy") and buggy!=null:
		var pose: Dictionary = travel.buggy
		var point = Vector3(pose.position[0],pose.position[1],pose.position[2])
		var ground: Dictionary = _ground(player,point,[player.get_rid(),buggy.body.get_rid()])
		if not ground.is_empty():
			buggy.global_position=Vector3(point.x,ground.position.y+0.06,point.z)
			buggy.rotation.y=float(pose.yaw)
			buggy.visual.rotation=Vector3(pose.pitch,0,pose.roll)
			if buggy.headlights_enabled!=bool(pose.headlights):
				buggy.toggle_headlights()
	var bike: Node3D
	for vehicle in tree.get_nodes_in_group("yard_vehicles"):
		if vehicle.vehicle_kind=="dirtbike": bike=vehicle
	if travel.has("dirtbike") and bike!=null:
		var pose: Dictionary=travel.dirtbike
		var point=Vector3(pose.position[0],pose.position[1],pose.position[2])
		var ground: Dictionary=_ground(player,point,[player.get_rid(),bike.body.get_rid()])
		if not ground.is_empty():
			bike.global_position=ground.position+Vector3.UP*0.06
			bike.rotation.y=float(pose.yaw)
			if bike.headlights_enabled!=bool(pose.headlights): bike.toggle_headlights()
	if not travel.has("player"):
		return
	var pose: Dictionary = travel.player
	var desired = Vector3(pose.position[0],pose.position[1],pose.position[2])
	var riding_vehicle: Node3D=buggy if int(pose.vehicle)==2 else (bike if int(pose.vehicle)==3 else null)
	if riding_vehicle!=null:
		desired=riding_vehicle.to_global(Vector3(2,0,0))
	var found: bool = false
	for offset in [Vector3.ZERO,Vector3(1.5,0,0),Vector3(-1.5,0,0),Vector3(0,0,1.5),Vector3(0,0,-1.5)]:
		var ground: Dictionary = _ground(player,desired+offset,[player.get_rid()])
		if ground.is_empty():
			continue
		var point: Vector3 = ground.position+Vector3.UP*0.08
		var shape = PhysicsShapeQueryParameters3D.new()
		shape.shape=player.collision.shape
		shape.transform=Transform3D(Basis.IDENTITY,point+player.collision.position)
		shape.collision_mask=1
		shape.exclude=[player.get_rid()]
		if not player.get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty():
			continue
		player.global_position=point
		found=true
		break
	if not found:
		player._notify("Il punto salvato è occupato: ripresa all'arrivo. Progressi conservati.")
		return
	player.velocity=Vector3.ZERO
	if riding_vehicle!=null and player.global_position.distance_to(riding_vehicle.global_position)<=3:
		player._mount_vehicle(riding_vehicle)
		player._vehicle_motion.parking_brake=true
		player._vehicle_third_person=bool(pose.third_person)
	elif int(pose.vehicle)==1:
		player._toggle_scooter(str(pose.get("mobility","scooter")))
	player.look_rotation=Vector2(float(pose.pitch),float(pose.yaw))
