extends StaticBody3D
## Stationary vendors arrive with campaign milestones. Visual animation never moves their collider.
var definition: Dictionary = {}
var _person: Node3D
var _product: Node3D
var _head: Node3D
var _arm: Node3D
var _label: Label3D
var _shape: CollisionShape3D
var _active: bool = false
var _phase: float = 0.0
var _wave: float = 0.0
var _last_day: int = -1
var _last_units: int = 0
var _receipt_initialized: bool = false
var _player: Node3D

func _ready() -> void:
	set_meta("operation","customer")
	set_meta("customer",str(definition.id))
	add_to_group("operations_service")
	_shape=CollisionShape3D.new()
	_shape.shape=CapsuleShape3D.new()
	_shape.shape.radius=0.3
	_shape.shape.height=1.8
	_shape.position.y=0.9
	add_child(_shape)
	var table = CollisionShape3D.new()
	table.shape=BoxShape3D.new()
	table.shape.size=Vector3(1.8,0.12,0.7)
	table.position=Vector3(0,0.9,-0.85)
	add_child(table)
	if DisplayServer.get_name()!="headless":
		_build_visual()
	GameState.credits_changed.connect(_credits_changed)
	GameState.operations_changed.connect(_refresh_presence)
	_refresh_presence()
	var receipt: Dictionary = GameState.crafting.data().get("sales",{}).get(str(definition.id),{})
	_last_day=int(receipt.get("day",-1))
	_last_units=int(receipt.get("units",0))
	_receipt_initialized=true

func _credits_changed(_amount: int) -> void:
	_refresh_presence()

func _refresh_presence() -> void:
	_active=GameState.completed_orders.size()>=int(definition.orders)
	set_meta("customer_active",_active)
	_shape.set_deferred("disabled",not _active)
	if _person!=null:
		_person.visible=_active
		_product.visible=_active
		_label.text=definition.name.get_slice(" · ",0)+"\n"+(GameState.crafting.definitions()[definition.product].name.to_upper() if _active else "RIAPRE DOPO %d COMMESSE" % definition.orders)
	var receipt: Dictionary = GameState.crafting.data().get("sales",{}).get(str(definition.id),{})
	var day: int = int(receipt.get("day",-1))
	var units: int = int(receipt.get("units",0))
	if _receipt_initialized and units>0 and (day>_last_day or (day==_last_day and units>_last_units)):
		_wave=2.4
	_last_day=day
	_last_units=units

func _process(delta: float) -> void:
	if _person==null or not _active:
		return
	_wave=maxf(0,_wave-delta)
	if not is_instance_valid(_player):
		_player=get_tree().get_first_node_in_group("players")
	if _player==null or _player.global_position.distance_to(global_position)>28:
		return
	_phase+=delta
	_person.position.y=sin(_phase*1.8+float(str(definition.id).hash()%10))*0.006
	var direction: Vector3 = to_local(_player.global_position)
	var yaw: float = clampf(atan2(-direction.x,-direction.z),-0.65,0.65) if direction.z<0 and direction.length()<7 else 0.0
	_head.rotation.y=lerp_angle(_head.rotation.y,yaw,1.0-exp(-delta*4))
	_arm.rotation.z=lerp_angle(_arm.rotation.z,1.9+sin(_phase*10)*0.18 if _wave>0 else 0.0,1.0-exp(-delta*8))
	_arm.rotation.x=sin(_phase*8)*0.12 if _wave>0 else 0.0

func _sphere(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> void:
	var visual = MeshInstance3D.new()
	var shape = SphereMesh.new()
	shape.radius=0.5
	shape.height=1
	shape.radial_segments=24
	shape.rings=12
	visual.mesh=shape
	visual.scale=size
	visual.position=point
	var material = StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.85
	visual.material_override=material
	parent.add_child(visual)

func _build_visual() -> void:
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var jacket: Color = {"marta":art.MINT,"enzo":art.YELLOW,"nina":Color("#7297bd"),"bruno":Color("#c9774f"),"ada":Color("#78905c")}.get(str(definition.id),art.MINT)
	var skin: Color = {"marta":Color("#c59672"),"enzo":Color("#bb8a64"),"nina":Color("#9c7356"),"bruno":Color("#bd916b"),"ada":Color("#d3a17c")}.get(str(definition.id),Color("#c59672"))
	_person=Node3D.new()
	_person.name="VendorVisual"
	add_child(_person)
	art.beveled_box(_person,Vector3(0.49,0.62,0.3),Vector3(0,1.13,0),jacket)
	art.box(_person,Vector3(0.48,0.05,0.31),Vector3(0,0.87,0),art.GRAPHITE)
	art.box(_person,Vector3(0.025,0.45,0.018),Vector3(0,1.15,-0.16),art.STEEL)
	for side in [-1,1]:
		art.beveled_box(_person,Vector3(0.14,0.16,0.03),Vector3(side*0.14,1.22,-0.17),jacket.darkened(0.2))
		art.beam(_person,Vector3(side*0.14,0.86,0),Vector3(side*0.14,0.16,0),0.18,art.GRAPHITE)
		art.beveled_box(_person,Vector3(0.21,0.14,0.34),Vector3(side*0.14,0.09,-0.08),art.GRAPHITE.darkened(0.1))
		var arm = Node3D.new()
		arm.position=Vector3(side*0.29,1.36,0)
		_person.add_child(arm)
		art.beam(arm,Vector3.ZERO,Vector3(side*0.055,-0.22,-0.02),0.135,jacket)
		art.beam(arm,Vector3(side*0.055,-0.22,-0.02),Vector3(side*0.08,-0.4,-0.12),0.11,jacket)
		_sphere(arm,Vector3(side*0.08,-0.43,-0.12),Vector3(0.1,0.14,0.1),skin)
		if side==1:
			_arm=arm
	_head=Node3D.new()
	_head.position=Vector3(0,1.64,-0.01)
	_person.add_child(_head)
	_sphere(_head,Vector3.ZERO,Vector3(0.31,0.36,0.3),skin)
	_sphere(_head,Vector3(0,-0.015,-0.15),Vector3(0.075,0.09,0.08),skin)
	for side in [-1,1]:
		art.beveled_box(_head,Vector3(0.032,0.026,0.016),Vector3(side*0.065,0.035,-0.145),art.GRAPHITE)
		art.box(_head,Vector3(0.065,0.015,0.025),Vector3(side*0.065,0.075,-0.14),art.GRAPHITE)
	art.beveled_box(_head,Vector3(0.34,0.08,0.32),Vector3(0,0.16,0),jacket.darkened(0.45))
	art.box(_head,Vector3(0.33,0.025,0.15),Vector3(0,0.125,-0.19),jacket.darkened(0.45))
	art.box(self,Vector3(1.8,0.12,0.7),Vector3(0,0.9,-0.85),art.STEEL)
	for side in [-1,1]:
		art.box(self,Vector3(0.1,0.9,0.55),Vector3(side*0.72,0.45,-0.85),jacket)
	_label=art.sign_text(self,"",Vector3(0,2.15,0),22,true)
	_label.pixel_size=0.0025
	_label.visibility_range_end=14
	_label.visibility_range_end_margin=3
	_product=Node3D.new()
	_product.position=Vector3(0,0.98,-0.85)
	add_child(_product)
	preload("res://scripts/gameplay/product_models.gd").build(_product,str(definition.product))
