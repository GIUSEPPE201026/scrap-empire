extends Node3D

func _ready() -> void:
	add_to_group("crafting_world")
	var station = Node3D.new()
	station.name = "GarageCraftBench"
	station.position = Vector3(4,0,26.4)
	station.set_meta("operation","craft")
	station.add_to_group("operations_service")
	add_child(station)
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.sign_text(self,"OFFICINA DEL RIUSO\nATTREZZATURA · PRODOTTI",Vector3(4,2.85,27.35),28).rotation.y = PI
	var assembly = preload("res://scripts/gameplay/fabrication_display.gd").new()
	assembly.position=Vector3(8.8,0,25.9)
	add_child(assembly)
	_build_customers()
	GameState.operations_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var data: Dictionary = GameState.crafting.data().objects
	for child in get_children():
		if child.is_in_group("crafted_objects") and not data.has(child.craft_id):
			remove_child(child)
			child.queue_free()
	for id in data:
		var object: Node3D
		for child in get_children():
			if child is CharacterBody3D and child.craft_id==id:
				object = child
		if object==null:
			object = CharacterBody3D.new()
			object.set_script(preload("res://scripts/gameplay/crafted_object.gd"))
			object.craft_id = id
			object.kind = data[id].kind
			add_child(object)
		object.update_load(data[id].cargo)
		if not is_instance_valid(object.towing):
			var pos: Array = data[id].position
			object.position = Vector3(pos[0],pos[1],pos[2])
			object.rotation = Vector3(0,float(data[id].yaw),0)
			if data[id].has("up"):
				var up=Vector3(data[id].up[0],data[id].up[1],data[id].up[2])
				var direction=Vector3(-sin(float(data[id].yaw)),0,-cos(float(data[id].yaw)))
				object.basis=Basis.looking_at(direction.slide(up).normalized(),up)

func _build_customers() -> void:
	for spec in GameState.logistics_def.customers:
		var person = preload("res://scripts/gameplay/yard_customer.gd").new()
		person.name=str(spec.id).capitalize()
		person.position=Vector3(spec.position[0],spec.position[1],spec.position[2])
		person.definition=spec
		add_child(person)


