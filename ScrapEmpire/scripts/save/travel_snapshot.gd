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
	for vehicle in game.get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.vehicle_kind=="forklift" and preload("res://scripts/economy/extra_mobility.gd").owned("forklift"):
			var mounted: bool=player._mounted_vehicle==vehicle
			result.forklift={"position":_point(player.global_position if mounted else vehicle.global_position),"yaw":wrapf(player._vehicle_heading if mounted else vehicle.rotation.y,-PI,PI),"pitch":0.0,"roll":0.0,"headlights":vehicle.headlights_enabled}
			if mounted and is_instance_valid(vehicle.carried):
				result.forklift.pallet=vehicle.carried.craft_id
				result.forklift.lift=vehicle.lift
	for vehicle in game.get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.vehicle_kind in ["crane","loader"]:
			var mounted: bool=player._mounted_vehicle==vehicle
			result[vehicle.vehicle_kind]={"position":_point(player.global_position if mounted else vehicle.global_position),"yaw":wrapf(player._vehicle_heading if mounted else vehicle.rotation.y,-PI,PI),"pitch":0.0,"roll":0.0,"headlights":vehicle.headlights_enabled}
			if mounted and not vehicle.load_items.is_empty():
				result[vehicle.vehicle_kind].load=vehicle.payload_ids()
				result[vehicle.vehicle_kind].lift=vehicle.lift
	result.erase("trailer")
	if is_instance_valid(player._towed_cart) and is_instance_valid(player._towed_cart.tow_vehicle) and game.crafting.data().objects.get(player._towed_cart.craft_id,{}).get("hitch","")==player._towed_cart.tow_vehicle.vehicle_kind and point_valid(_point(player._towed_cart.global_position)):
		result.trailer={"id":player._towed_cart.craft_id,"position":_point(player._towed_cart.global_position),"yaw":wrapf(player._towed_cart.rotation.y,-PI,PI)}
	return result

static func validate(value: Variant, save: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if not SaveService._valid_count(value.get("epoch")) or int(value.epoch)!=int(save.get("operations",{}).get("epoch",0)):
		return false
	if value.has("trailer"):
		var trailer=value.trailer
		if not trailer is Dictionary or not trailer.get("id") is String or not point_valid(trailer.get("position")): return false
		if not (trailer.get("yaw") is int or trailer.get("yaw") is float) or not is_finite(float(trailer.yaw)) or absf(float(trailer.yaw))>PI: return false
		var record: Dictionary=save.get("operations",{}).get("crafting",{}).get("objects",{}).get(trailer.id,{})
		if record.get("kind","")!="handcart" or record.get("hitch","") not in ["buggy","dirtbike"]: return false
	for key in ["player","buggy","dirtbike","forklift","crane","loader"]:
		if not value.has(key):
			continue
		var pose = value[key]
		if not pose is Dictionary or not point_valid(pose.get("position")):
			return false
		for angle in ["yaw","pitch"]+(["roll"] if key!="player" else []):
			if not (pose.get(angle) is int or pose.get(angle) is float) or not is_finite(float(pose[angle])) or absf(float(pose[angle]))>(PI if angle=="yaw" else 1.4):
				return false
		if key=="player":
			if not SaveService._valid_count(pose.get("vehicle")) or int(pose.vehicle)>6 or not pose.get("third_person") is bool:
				return false
			var mobility: String=str(pose.get("mobility","scooter" if int(pose.vehicle)==1 else ("buggy" if int(pose.vehicle)==2 else "")))
			if mobility not in {0:[""],1:["scooter","skateboard"],2:["buggy"],3:["dirtbike"],4:["forklift"],5:["crane"],6:["loader"]}[int(pose.vehicle)]: return false
			if int(pose.vehicle)>=5 and mobility not in save.get("operations",{}).get("mobility",{}).get("owned",[]): return false
			if int(pose.vehicle)==4 and mobility!="forklift": return false
			var owned: Array=save.get("operations",{}).get("mobility",{}).get("owned",[])
			if int(pose.vehicle)==4 and "forklift" not in owned: return false
			if int(pose.vehicle)==3 and (mobility!="dirtbike" or "dirtbike" not in owned): return false
			if int(pose.vehicle)==1 and mobility=="skateboard":
				if "skateboard" not in owned: return false
			elif int(pose.vehicle)<=2 and int(pose.vehicle)>int(save.get("vehicle_level",0)): return false
			if mobility not in ["","scooter","buggy","skateboard","dirtbike","forklift","crane","loader"]: return false
		else:
			if not pose.get("headlights") is bool: return false
			if key=="buggy" and int(save.get("vehicle_level",0))<2: return false
			if key in ["crane","loader"] and key not in save.get("operations",{}).get("mobility",{}).get("owned",[]): return false
			if key in ["crane","loader"] and pose.has("load") and not _valid_industrial_load(pose,key,save,value.get("player",{})): return false
			if key=="forklift" and "forklift" not in save.get("operations",{}).get("mobility",{}).get("owned",[]): return false
			if key=="forklift" and pose.has("pallet"):
				if not pose.pallet is String or not pose.get("lift") is float and not pose.get("lift") is int: return false
				if not is_finite(float(pose.lift)) or float(pose.lift)<0.12 or float(pose.lift)>1.55: return false
				if save.get("operations",{}).get("crafting",{}).get("objects",{}).get(pose.pallet,{}).get("kind","")!="bale_pallet": return false
				if int(value.get("player",{}).get("vehicle",0))!=4: return false
			if key=="dirtbike" and "dirtbike" not in save.get("operations",{}).get("mobility",{}).get("owned",[]): return false
	return true

static func _valid_industrial_load(pose: Dictionary, kind: String, save: Dictionary, driver: Dictionary) -> bool:
	var spec: Dictionary=GameState.logistics_def.mobility[kind]
	if not pose.load is Array or pose.load.is_empty() or pose.load.size()>int(spec.capacity_items) or driver.get("mobility","")!=kind: return false
	if not (pose.get("lift") is float or pose.get("lift") is int) or not is_finite(float(pose.lift)) or pose.lift<0.2 or pose.lift>(2.3 if kind=="crane" else 1.4): return false
	var counts: Dictionary=GameState.base_sector_counts.duplicate()
	for land in GameState.land_defs:
		if int(land.level)<=int(save.get("yard_level",0)): counts.merge(land.materials,true)
	var mass: float=0
	for key in pose.load:
		if not key is String or pose.load.count(key)!=1: return false
		var id: String=key.get_slice(":",1)
		if kind=="crane":
			if key!="part:"+id: return false
			var part: Dictionary=save.get("operations",{}).get("field",{}).get(id,{})
			if part.get("kind","") not in ["engine","frame","panel"]: return false
			mass+=float(GameState.part_defs[part.kind].mass_kg)
		else:
			if key!="scrap:"+id or id in save.get("local_expedition",{}).get("consumed",[]): return false
			var material: String=id.get_slice("_",0)
			var index: int=id.get_slice("_",1).to_int()
			if not counts.has(material) or index<0 or index>=int(counts[material]) or id!="%s_%03d" % [material,index]: return false
			mass+=float(GameState.material_defs[material].mass_kg)
	return mass<=float(spec.capacity_kg)

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
	var forklift: Node3D
	for vehicle in tree.get_nodes_in_group("yard_vehicles"):
		if vehicle.vehicle_kind=="forklift": forklift=vehicle
	if travel.has("forklift") and forklift!=null:
		var location: Dictionary=travel.forklift
		var point=Vector3(location.position[0],location.position[1],location.position[2])
		var ground: Dictionary=_ground(player,point,[player.get_rid(),forklift.body.get_rid()])
		if not ground.is_empty():
			forklift.global_position=ground.position+Vector3.UP*0.06
			forklift.rotation.y=float(location.yaw)
	var industrial: Node3D
	for vehicle in tree.get_nodes_in_group("yard_vehicles"):
		if vehicle.vehicle_kind not in ["crane","loader"]: continue
		if travel.has(vehicle.vehicle_kind):
			var saved: Dictionary=travel[vehicle.vehicle_kind]
			var desired_point=Vector3(saved.position[0],saved.position[1],saved.position[2])
			var terrain: Dictionary=_ground(player,desired_point,[player.get_rid(),vehicle.body.get_rid()])
			vehicle.global_position=terrain.position+Vector3.UP*0.06 if not terrain.is_empty() else desired_point
			vehicle.rotation.y=float(saved.yaw)
		if travel.get("player",{}).get("mobility","")==vehicle.vehicle_kind: industrial=vehicle
	if not travel.has("player"):
		return
	var pose: Dictionary = travel.player
	var desired = Vector3(pose.position[0],pose.position[1],pose.position[2])
	var riding_vehicle: Node3D=buggy if int(pose.vehicle)==2 else (bike if int(pose.vehicle)==3 else (forklift if int(pose.vehicle)==4 else null))
	if int(pose.vehicle)>=5: riding_vehicle=industrial
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
		preload("res://scripts/gameplay/cart_hitch.gd").restore(player)
		return
	player.velocity=Vector3.ZERO
	if riding_vehicle!=null and player.global_position.distance_to(riding_vehicle.global_position)<=3:
		player._mount_vehicle(riding_vehicle)
		player._vehicle_motion.parking_brake=true
		player._vehicle_third_person=bool(pose.third_person)
		if riding_vehicle.vehicle_kind=="forklift" and travel.has("forklift"):
			if not riding_vehicle.restore_load(player,str(travel.forklift.get("pallet","")),float(travel.forklift.get("lift",0.12))):
				player._notify("Carico non ripristinabile qui: pallet conservato nell'ultima posizione libera.")
		if riding_vehicle.vehicle_kind in ["crane","loader"]:
			var cargo_pose: Dictionary=travel.get(riding_vehicle.vehicle_kind,{})
			if not riding_vehicle.restore_payload(player,cargo_pose.get("load",[]),float(cargo_pose.get("lift",0.2))):
				player._notify("Carico conservato nell'ultima posizione libera: spazio sulle attrezzature occupato.")
	elif int(pose.vehicle)==1:
		player._toggle_scooter(str(pose.get("mobility","scooter")))
	player.look_rotation=Vector2(float(pose.pitch),float(pose.yaw))
	preload("res://scripts/gameplay/cart_hitch.gd").restore(player)
