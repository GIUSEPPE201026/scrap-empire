extends Node3D
var player: Node3D
var kind: String
var yaw: float
var ghost: MeshInstance3D
var label: Label3D
var ground: Dictionary={}
var preview_parts: Array=[]

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		update_preview()
		return
	ghost=MeshInstance3D.new()
	ghost.mesh=BoxMesh.new()
	ghost.mesh.size=Vector3(1.35,0.85,1.45) if kind=="handcart" else (Vector3(1.5,1.1,1.5) if kind=="field_depot" else Vector3(0.7,2,0.7))
	if kind=="bale_pallet": ghost.mesh.size=Vector3(1.5,1.3,1.3)
	if kind in preload("res://scripts/gameplay/yard_structures.gd").KINDS: ghost.mesh.size=preload("res://scripts/gameplay/yard_structures.gd").footprint(kind)
	var material=StandardMaterial3D.new()
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test=false
	ghost.material_override=material
	add_child(ghost)
	ghost.position.y=ghost.mesh.size.y/2
	if kind=="handcart":
		ghost.hide()
		var model=Node3D.new()
		add_child(model)
		preload("res://scripts/gameplay/handcart_art.gd").build(model,preload("res://scripts/gameplay/scrapyard_art.gd").new())
		preview_parts=model.find_children("*","MeshInstance3D",true,false)
		for part in preview_parts: part.material_override=material
	label=Label3D.new()
	label.font_size=24
	label.pixel_size=0.0035
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y=ghost.mesh.size.y+0.25
	add_child(label)
	update_preview()

func _physics_process(_delta: float) -> void:
	update_preview()

func update_preview() -> void:
	ground=player._craft_ground(kind,yaw)
	var valid: bool=not ground.is_empty()
	var at: Vector3=ground.point if valid else player.global_position-Vector3(sin(player.look_rotation.y),0,cos(player.look_rotation.y))*2.3
	var up: Vector3=ground.up if valid else Vector3.UP
	global_transform=Transform3D(Basis.looking_at(Vector3(-sin(yaw),0,-cos(yaw)).slide(up).normalized(),up),at)
	if ghost==null: return
	ghost.material_override.albedo_color=Color(0.25,0.9,0.55,0.24) if valid else Color(1,0.25,0.15,0.24)
	label.text=(InputMap.action_get_events("interact")[0].as_text()+" / CLIC · POSIZIONA" if valid else "SPAZIO OCCUPATO / TERRENO RIPIDO")+"\nROTELLA / R · RUOTA\nDESTRO / ESC · ANNULLA"

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
		cancel()
	elif event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT):
		update_preview()
		if ground.is_empty(): player._notify(Localization.text("Sposta l'anteprima su terreno libero."))
		elif GameState.crafting.deploy(kind,ground.point,yaw,ground.up):
			player._notify(Localization.text("Posizionato · E sull'oggetto per usarlo."))
			cancel()
		else: player._notify(Localization.text("Posizionamento non salvato: oggetto conservato nell'attrezzatura."))
	elif (event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_R) or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]):
		yaw=wrapf(yaw+(-PI/4 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_WHEEL_DOWN else PI/4),-PI,PI)
		update_preview()
	player.get_viewport().set_input_as_handled()

func cancel() -> void:
	player._ignore_drag_until_release=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	player._ignore_collect_until_release=Input.is_action_pressed("collect")
	player._placement=null
	queue_free()
