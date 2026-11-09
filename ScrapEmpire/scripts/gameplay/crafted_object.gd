extends CharacterBody3D
var craft_id: String = ""
var kind: String = ""
var towing: Node3D
var tow_vehicle: Node3D
var hitch_line: MeshInstance3D
var wheels: Array[Node3D] = []
var load_visual: Node3D
var load_signature: String = ""

func _refresh_pallet() -> void:
	var bales: int=int(GameState.crafting.data().objects.get(craft_id,{}).get("bales",0))
	for child in get_children():
		if child is CollisionShape3D:
			child.shape.size.y=0.22+ceilf(bales/2.0)*0.48
			child.position.y=child.shape.size.y/2.0
	if DisplayServer.get_name()=="headless": return
	if is_instance_valid(load_visual):
		remove_child(load_visual)
		load_visual.queue_free()
	load_visual=Node3D.new()
	add_child(load_visual)
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	for side in [-1,1]: art.box(load_visual,Vector3(0.16,0.12,1.2),Vector3(side*0.5,0.06,0),Color("#775333"))
	for index in 5: art.beveled_box(load_visual,Vector3(1.4,0.08,0.20),Vector3(0,0.16,-0.48+index*0.24),Color("#aa8051"))
	var amount: int=int(GameState.crafting.data().objects.get(craft_id,{}).get("bales",0))
	for index in amount:
		var at=Vector3((index%2)*0.66-0.33,0.45+(index/2)*0.48,0)
		art.beveled_box(load_visual,Vector3(0.61,0.44,0.95),at,art.STEEL,true)
		for z in [-0.25,0.25]: art.box(load_visual,Vector3(0.63,0.46,0.035),at+Vector3(0,0,z),art.GRAPHITE)

func _ready() -> void:
	add_to_group("crafted_objects")
	if kind=="bale_pallet":
		var pallet_shape=CollisionShape3D.new()
		pallet_shape.shape=BoxShape3D.new()
		pallet_shape.shape.size=Vector3(1.4,0.22,1.2)
		pallet_shape.position.y=0.11
		add_child(pallet_shape)
		_refresh_pallet()
		GameState.operations_changed.connect(_refresh_pallet)
		return
	if kind=="field_depot":
		add_to_group("field_depot")
	collision_layer = 1
	collision_mask = 1
	if kind in preload("res://scripts/gameplay/yard_structures.gd").KINDS:
		preload("res://scripts/gameplay/yard_structures.gd").build(self,kind)
		return
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.3,0.8,1.35) if kind=="handcart" else Vector3(0.65,1.9,0.65)
	if kind=="field_depot":
		box.size=Vector3(1.5,1.1,1.5)
	shape.shape = box
	shape.position.y = box.size.y/2
	add_child(shape)
	if kind=="work_lamp":
		var light = OmniLight3D.new()
		light.position = Vector3(0,1.9,-0.15)
		light.omni_range = float(GameState.logistics_def.crafting.work_lamp.range)
		light.light_energy = 3
		light.light_color = Color("#ffe7bd")
		add_child(light)
	if DisplayServer.get_name()=="headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	if kind=="handcart":
		wheels=preload("res://scripts/gameplay/handcart_art.gd").build(self,art)
	elif kind=="field_depot":
		art.beveled_box(self,Vector3(1.5,0.95,1.5),Vector3(0,0.52,0),art.MINT,true)
		art.beveled_box(self,Vector3(1.58,0.14,1.58),Vector3(0,1.07,0),art.YELLOW)
		for side in [-1,1]:
			art.box(self,Vector3(0.08,1,1.56),Vector3(side*0.58,0.55,0),art.STEEL)
		art.sign_text(self,"DEPOSITO",Vector3(0,1.65,0),28,true)
	else:
		for index in 3:
			art.beam(self,Vector3(0,0.65,0),Vector3(sin(index*TAU/3)*0.4,0.04,cos(index*TAU/3)*0.4),0.05,art.STEEL)
		art.cylinder(self,0.035,1.5,Vector3(0,1,0),art.YELLOW,10)
		art.box(self,Vector3(0.65,0.42,0.15),Vector3(0,1.85,0),art.YELLOW)
		art.box(self,Vector3(0.54,0.31,0.03),Vector3(0,1.85,-0.09),Color("#fff1ca"))
		var bubble = art.box(self,Vector3(0.52,0.04,0.03),Vector3(0,1.85,-0.11),Color.WHITE)
		var glow = bubble.material_override.duplicate()
		glow.emission_enabled = true
		glow.emission = Color("#ffe7bd")
		glow.emission_energy_multiplier = 2
		bubble.material_override = glow

func _physics_process(delta: float) -> void:
	if is_instance_valid(hitch_line): hitch_line.visible=is_instance_valid(tow_vehicle)
	if not is_instance_valid(towing):
		return
	var motorized: bool=preload("res://scripts/gameplay/cart_hitch.gd").supported(tow_vehicle)
	var driver: Node3D=towing if motorized and towing._mounted_vehicle==tow_vehicle else tow_vehicle
	var origin: Vector3=driver.global_position if motorized else towing.global_position
	var basis_yaw: Basis=driver.global_basis if motorized else towing.global_basis
	if motorized and DisplayServer.get_name()!="headless":
		if not is_instance_valid(hitch_line):
			hitch_line=MeshInstance3D.new()
			var tube=CylinderMesh.new()
			tube.top_radius=0.035
			tube.bottom_radius=0.035
			tube.height=1
			hitch_line.mesh=tube
			var material=StandardMaterial3D.new()
			material.albedo_color=Color("#b0b7b3")
			hitch_line.material_override=material
			add_child(hitch_line)
		var from: Vector3=to_global(Vector3(0,1,-1.55))
		var to: Vector3=preload("res://scripts/gameplay/cart_hitch.gd").point(tow_vehicle,towing)
		var axis: Vector3=to-from
		if axis.length()>0.001: hitch_line.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())).scaled(Vector3(1,axis.length(),1)),(to+from)*0.5)
	if (is_instance_valid(towing._mounted_vehicle) and not motorized) or (not motorized and not towing._game_state.operations.held.is_empty()) or global_position.distance_to(origin)>(7.0 if motorized else 4.0):
		towing._stop_cart()
		return
	var distance: float=float(GameState.logistics_def.crafting.handcart.towing[tow_vehicle.vehicle_kind].distance) if motorized else 1.65
	var target: Vector3 = origin+basis_yaw.z*distance
	var offset: Vector3 = target-global_position
	offset.y = 0
	var speed: float = minf(offset.length()*4,15.0 if motorized else float(GameState.logistics_def.crafting.handcart.tow_speed_mps)+0.5)
	var direction: Vector3 = offset.normalized()
	velocity.x = direction.x*speed
	velocity.z = direction.z*speed
	velocity.y = 0 if is_on_floor() else velocity.y-18*delta
	if direction.length()>0.1:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*5)
	var previous: Vector3 = global_position
	move_and_slide()
	for wheel in wheels:
		wheel.rotate_y(previous.distance_to(global_position)/0.28)

func update_load(cargo: Dictionary) -> void:
	if DisplayServer.get_name()=="headless" or kind!="handcart":
		return
	var signature: String = JSON.stringify(cargo)
	if signature==load_signature:
		return
	load_signature = signature
	if is_instance_valid(load_visual):
		remove_child(load_visual)
		load_visual.queue_free()
	load_visual = Node3D.new()
	add_child(load_visual)
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var families: Array = ["metal","plastic","electronics","copper","aluminum","glass","rubber"]
	var index: int = 0
	for material in cargo:
		var family: int = families.find(material)
		if family<0 or int(cargo[material])<=0:
			continue
		for number in mini(2,int(cargo[material])):
			var piece = Node3D.new()
			piece.position = Vector3(-0.2+(index%2)*0.4,0.47+(index/4)*0.2,-0.3+((index/2)%2)*0.5)
			piece.scale = Vector3.ONE*0.48
			piece.rotation.y = index*0.65
			load_visual.add_child(piece)
			preload("res://scripts/gameplay/scrap_catalog.gd").build(piece,family,number,art)
			index += 1
			if index>=8:
				return

