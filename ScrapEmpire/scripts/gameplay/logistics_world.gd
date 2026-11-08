extends Node3D
var field_root: Node3D

func _ready() -> void:
	name = "LogisticsWorld"
	field_root = Node3D.new()
	add_child(field_root)
	GameState.operations_changed.connect(refresh)
	GameState.land_unlocked.connect(_land_opened)
	GameState.ops.seed_field_parts()
	refresh()

func _land_opened(_level: int) -> void:
	GameState.ops.seed_field_parts()
	refresh()

func refresh() -> void:
	for child in field_root.get_children():
		if not GameState.operations.field.has(child.part_id):
			field_root.remove_child(child)
			child.queue_free()
	for id in GameState.operations.field:
		var existing: Node3D
		for child in field_root.get_children():
			if child.part_id == id:
				existing = child
		if existing == null:
			existing = StaticBody3D.new()
			existing.set_script(preload("res://scripts/gameplay/haul_part.gd"))
			existing.part_id = id
			existing.kind = GameState.operations.field[id].kind
			existing.quality = int(GameState.operations.field[id].quality)
			field_root.add_child(existing)
		var position_data: Array = GameState.operations.field[id].position
		existing.position = Vector3(position_data[0],position_data[1],position_data[2])
		existing.rotation.y = float(GameState.operations.get("loose_rotations",{}).get(id,existing.rotation.y))
