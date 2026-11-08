extends StaticBody3D
## Drag-only loose geometry; no second material reward alongside pile layers.
var entity_id: String=""
var fragment_mass: float=1.0
var bounds: AABB
var _elapsed: float=0.0

func _ready() -> void:
	add_to_group("heap_fragments")

func get_drag_ground_offset() -> float:
	var rotated: AABB=Transform3D(global_basis,Vector3.ZERO)*bounds
	return maxf(0.02,-rotated.position.y+0.02)

func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<0.5: return
	_elapsed=0
	var player=get_tree().get_first_node_in_group("players")
	if is_instance_valid(player): collision_layer=1 if global_position.distance_squared_to(player.global_position)<2500 else 0
