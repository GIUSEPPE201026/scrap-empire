extends StaticBody3D
var definition_id: String = "car"
var entity_id: String = ""
var stage: int = 0
var parts: Array[Node3D] = []
var status_label: Label3D
var shape_node: CollisionShape3D
var component_shapes: Array[CollisionShape3D] = []
var targets: Array[Area3D] = []
var selected_component: int = -1
var recover_intact: bool = false
var outline: MeshInstance3D
var _work_index: int = -1
var _work_progress: float = 0.0
var _work_phase: float = 0.0
var _work_rest: Transform3D = Transform3D.IDENTITY

func _restore_drag_position() -> void:
	var data: Array = GameState.operations.get("loose_positions",{}).get(entity_id,[])
	if data.size()==3:
		global_position = Vector3(data[0],data[1],data[2])
	rotation.y = float(GameState.operations.get("loose_rotations",{}).get(entity_id,rotation.y))

func _ready() -> void:
	set_process(false)
	call_deferred("_restore_drag_position")
	add_to_group("salvage_assemblies")
	var steps: Array = GameState.salvage_defs[definition_id].steps
	for index in steps.size():
		var part = Node3D.new()
		add_child(part)
		parts.append(part)
		var physical = CollisionShape3D.new()
		physical.shape = BoxShape3D.new()
		physical.shape.size = _vector(steps[index].hitbox)*0.98
		physical.position = _vector(steps[index].anchor)
		add_child(physical)
		component_shapes.append(physical)
		_add_target(index,physical.position,physical.shape.size*1.035)
	shape_node = component_shapes.back()
	if definition_id == "car":
		for side in [-1,1]:
			for z in [-1.2,1.2]:
				_add_target(1,Vector3(side*1.02,0.43,z),Vector3(0.4,0.86,0.86))
	if DisplayServer.get_name() != "headless":
		_build_visual()
	_refresh()

func _vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func _add_target(index: int, location: Vector3, dimensions: Vector3) -> void:
	var target = Area3D.new()
	target.collision_layer = 1
	target.collision_mask = 0
	target.monitoring = false
	target.set_meta("assembly",self)
	target.set_meta("component",index)
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = dimensions
	shape.position = location
	target.add_child(shape)
	add_child(target)
	targets.append(target)

func _build_visual() -> void:
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	if definition_id == "car":
		var color: Color = [art.MINT,art.RUST,art.YELLOW][absi(entity_id.hash())%3]
		art.beveled_box(parts[3],Vector3(2,0.4,3.8),Vector3(0,0.45,0),color,true)
		art.beveled_box(parts[0],Vector3(1.8,0.18,1.1),Vector3(0,0.98,-1.25),color,true)
		art.beveled_box(parts[0],Vector3(1.8,0.15,0.7),Vector3(0,0.9,1.5),art.RUST,true)
		art.beveled_box(parts[1],Vector3(1.7,0.12,1.5),Vector3(0,1.65,0.1),color,true)
		art.box(parts[1],Vector3(1.6,0.7,1.4),Vector3(0,1.15,0.1),art.GRAPHITE)
		art.box(parts[1],Vector3(1.55,0.5,0.05),Vector3(0,1.3,-0.64),Color("#54747d")).rotation.x = 0.25
		for side in [-1,1]:
			for z in [-1.2,1.2]:
				art.cylinder(parts[1],0.42,0.22,Vector3(side,0.43,z),art.GRAPHITE,32).rotation.z = PI/2
				art.cylinder(parts[1],0.2,0.24,Vector3(side*1.02,0.43,z),art.STEEL,24).rotation.z = PI/2
		art.beveled_box(parts[2],Vector3(0.9,0.45,0.75),Vector3(0,0.78,-1.25),art.STEEL)
		for index in 4:
			art.box(parts[2],Vector3(0.94,0.025,0.8),Vector3(0,0.65+index*0.09,-1.25),art.GRAPHITE)
	elif definition_id == "generator":
		art.beveled_box(parts[0],Vector3(1.5,1.5,1.2),Vector3(0,0.9,0),art.YELLOW,true)
		art.box(parts[0],Vector3(0.6,0.45,0.04),Vector3(0,1.2,-0.62),art.GRAPHITE)
		art.cylinder(parts[1],0.42,1.0,Vector3(0,0.8,0),art.RUST,32).rotation.x = PI/2
		art.beveled_box(parts[2],Vector3(1.6,0.25,1.4),Vector3(0,0.15,0),art.GRAPHITE)
	elif definition_id=="aircraft_turbine":
		art.cylinder(parts[0],0.95,2.3,Vector3(0,1,0),art.STEEL,40).rotation.x=PI/2
		for side in [-1,1]: art.cylinder(parts[0],0.98,0.12,Vector3(0,1,side*1.1),art.RUST,40).rotation.x=PI/2
		for index in 5:
			art.beam(parts[1],Vector3(-0.55+index*0.26,0.65,-0.8),Vector3(-0.55+index*0.26,1.05,0.7),0.075,art.MINT)
		art.cylinder(parts[2],0.6,1.5,Vector3(0,0.9,0),art.GRAPHITE,32).rotation.x=PI/2
		for index in 12:
			var blade=art.beveled_box(parts[2],Vector3(0.1,0.5,0.12),Vector3(sin(index*TAU/12)*0.4,0.9+cos(index*TAU/12)*0.4,0.78),art.STEEL)
			blade.rotation.z=-index*TAU/12+0.3
	elif definition_id=="survey_rig":
		art.beveled_box(parts[0],Vector3(1.7,1.3,1.5),Vector3(0,0.7,0),art.RUST,true)
		art.box(parts[0],Vector3(0.8,0.3,0.04),Vector3(0,1,-0.77),art.GRAPHITE)
		art.beveled_box(parts[1],Vector3(0.6,0.7,1),Vector3(-0.35,0.55,0),art.YELLOW,true)
		art.beveled_box(parts[2],Vector3(0.75,0.8,1),Vector3(0.35,0.6,0),art.STEEL,true)
		for index in 4: art.cylinder(parts[2],0.1,0.1,Vector3(0.1+index*0.15,0.85,-0.55),art.MINT,16).rotation.x=PI/2
	elif definition_id=="signal_receiver":
		art.cylinder(parts[0],0.9,0.5,Vector3(0,1.25,0),art.STEEL,40)
		for index in 6:
			var ring=art.cylinder(parts[1],0.6-index*0.035,0.07,Vector3(0,0.5+index*0.1,0),art.RUST,32)
			ring.rotation.z=0.12
		art.cylinder(parts[2],0.75,0.4,Vector3(0,0.25,0),art.GRAPHITE,32)
		art.cylinder(parts[2],0.2,0.65,Vector3(0,0.6,0),art.MINT,24)
	elif definition_id=="sealed_crate":
		var color: Color=[art.MINT,art.RUST,art.YELLOW][absi(entity_id.hash())%3]
		art.beveled_box(parts[0],Vector3(1.85,0.18,1.55),Vector3(0,1.25,0),color,true)
		for side in [-1,1]:
			art.box(parts[1],Vector3(0.07,0.9,1.52),Vector3(side*0.55,0.8,0),art.STEEL)
			art.beveled_box(parts[2],Vector3(0.12,0.95,1.55),Vector3(side*0.85,0.55,0),color,true)
		art.beveled_box(parts[2],Vector3(1.8,0.16,1.55),Vector3(0,0.12,0),art.GRAPHITE)
		art.box(parts[2],Vector3(1.3,0.45,1.1),Vector3(0,0.5,0),art.STEEL)
		art.box(parts[1],Vector3(1.6,0.08,0.08),Vector3(0,1.05,0),art.RUST)
	else:
		art.beveled_box(parts[0],Vector3(1.4,1.7,1.1),Vector3(0,0.85,0),Color("#ddd3b9"),true)
		art.cylinder(parts[0],0.42,0.08,Vector3(0,0.8,-0.59),art.GRAPHITE,32).rotation.x = PI/2
		art.beveled_box(parts[1],Vector3(0.48,0.35,0.7),Vector3(0.48,0.4,0),art.MINT)
		art.cylinder(parts[2],0.55,0.8,Vector3(0,0.9,0),art.STEEL,32)
	outline = MeshInstance3D.new()
	outline.mesh = BoxMesh.new()
	var highlight = StandardMaterial3D.new()
	highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.albedo_color = Color(0.4,0.9,0.7,0.12)
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.material_override = highlight
	outline.hide()
	add_child(outline)

func select_component(index: int) -> void:
	if index >= 0 and index < parts.size():
		selected_component = index

func get_step() -> Dictionary:
	var completed: Array = GameState.ops.completed_components(entity_id)
	if selected_component < 0 or selected_component in completed:
		selected_component = -1
		for index in parts.size():
			if index not in completed:
				selected_component = index
				break
	if selected_component < 0:
		return {}
	var step: Dictionary = GameState.salvage_defs[definition_id].steps[selected_component].duplicate(true)
	step.index = selected_component
	return step

func collection_seconds() -> float:
	return float(get_step().get("seconds",1))*(1.4 if recover_intact else 1.0)

func display_name() -> String:
	var step: Dictionary = get_step()
	if step.is_empty():
		return Localization.text("SMONTAGGIO COMPLETATO")
	return Localization.format_text("%s · %s\n%s", [GameState.salvage_defs[definition_id].name,step.component_name,Localization.text("RECUPERO INTERO · %d kg") % GameState.part_defs[step.part].mass_kg if recover_intact else Localization.text("SEPARA MATERIALI")])

func requirement(peer: int, tool: int) -> String:
	var step: Dictionary = get_step()
	return "" if step.is_empty() else GameState.ops.component_requirement(entity_id,definition_id,int(step.index),tool,recover_intact,peer)

func commit_stage(peer: int, tool: int = 0) -> Dictionary:
	var step: Dictionary = get_step()
	if step.is_empty():
		return {"success":false,"message":"Oggetto già smontato."}
	var result: Dictionary = GameState.ops.claim_component(entity_id,definition_id,int(step.index),peer,tool,recover_intact)
	if result.success:
		_detach_effect(int(step.index))
		selected_component = -1
		_refresh()
	return result

func _detach_effect(index: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ghost: Node3D = parts[index].duplicate()
	get_tree().current_scene.add_child(ghost)
	ghost.add_to_group("salvage_effects")
	ghost.global_transform = parts[index].global_transform
	var tween = ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost,"global_position",ghost.global_position+Vector3(0,0.4,0),0.3)
	tween.tween_property(ghost,"scale",Vector3.ONE*0.05,0.3)
	tween.chain().tween_callback(ghost.queue_free)

func set_highlighted(value: bool) -> void:
	if not value:
		set_work_progress(0)
	if outline == null:
		return
	var step: Dictionary = get_step()
	outline.visible = value and not step.is_empty()
	if not step.is_empty():
		outline.position = _vector(step.anchor)
		outline.mesh.size = _vector(step.hitbox)*1.06

func _refresh() -> void:
	set_work_progress(0)
	var completed: Array = GameState.ops.completed_components(entity_id)
	stage = completed.size()
	for index in parts.size():
		parts[index].visible = index not in completed
		component_shapes[index].set_deferred("disabled",index in completed)
	for target in targets:
		target.collision_layer = 0 if int(target.get_meta("component")) in completed else 1
	if outline != null:
		outline.hide()

func set_work_progress(progress: float) -> void:
	if progress<=0:
		if _work_index>=0 and _work_index<parts.size():
			parts[_work_index].transform=_work_rest
		_work_index=-1
		_work_progress=0.0
		set_process(false)
		return
	var step: Dictionary = get_step()
	if step.is_empty():
		set_work_progress(0)
		return
	var index: int = int(step.index)
	if _work_index!=index:
		set_work_progress(0)
		_work_index=index
		_work_rest=parts[index].transform
		_work_phase=0.0
	_work_progress=clampf(progress,0,1)
	set_process(true)

func _process(delta: float) -> void:
	if _work_index<0:
		return
	_work_phase+=delta
	var step: Dictionary = GameState.salvage_defs[definition_id].steps[_work_index]
	var anchor: Vector3 = _vector(step.anchor)
	var hammer: bool = int(step.tool)==2
	var pulse: float = sin(_work_phase*(19.0 if hammer else 28.0))
	var angle: float = pulse*(0.014 if hammer else 0.007)*minf(_work_progress*5.0,1.0)
	var turn = Basis.from_euler(Vector3(angle*0.6,angle,angle*0.4))
	var lift: float = _work_progress*(0.08 if step.part in ["panel","battery"] else 0.035)
	var offset: Vector3 = Vector3.UP*(lift+absf(pulse)*(0.012 if hammer else 0.004))
	parts[_work_index].transform=Transform3D(turn,anchor-turn*anchor+offset)*_work_rest
