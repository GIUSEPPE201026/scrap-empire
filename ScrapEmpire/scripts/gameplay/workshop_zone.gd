extends Area3D

var auto_open_enabled: bool = true

func _ready() -> void:
	add_to_group("workshop_zone")
	collision_layer = 0
	collision_mask = 1
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(4.4, 2.8, 3)
	shape.position.y = 1.4
	add_child(shape)
	body_entered.connect(_on_entered)

func _on_entered(body: Node3D) -> void:
	if auto_open_enabled and body.is_in_group("players") and body.is_local_player:
		body.call_deferred("_enter_workshop_zone")
