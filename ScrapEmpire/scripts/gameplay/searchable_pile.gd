extends StaticBody3D
var definition_id: String = "pile"
var _release_required: bool = false
var _last_layer: int = -1
var recovery_point: Vector3

func _ready() -> void:
	GameState.operations_changed.connect(_refresh_layers)
	call_deferred("_refresh_layers")

func layer_count() -> int:
	return int(GameState.operations.get("pile_layers",{}).get("searched_"+str(name),0))

func _process(_delta: float) -> void:
	if _release_required and not Input.is_action_pressed("collect"):
		_release_required = false

func set_recovery_point(point: Vector3) -> void:
	recovery_point = point

func _refresh_layers() -> void:
	var completed: int = layer_count()
	if completed==_last_layer:
		return
	_last_layer = completed
	for child in get_children():
		if child is MultiMeshInstance3D:
			child.multimesh.visible_instance_count = int(child.multimesh.instance_count*(1.0-completed*0.21))

func get_step() -> Dictionary:
	var steps: Array = GameState.salvage_defs[definition_id].steps
	return steps[layer_count()] if layer_count()<steps.size() else {}

func collection_seconds() -> float:
	return float(get_step().get("seconds",1))

func can_start_collection() -> bool:
	return not _release_required and layer_count()<GameState.salvage_defs[definition_id].steps.size()

func display_name() -> String:
	if _release_required:
		return "Rilascia il sinistro per passare allo strato successivo"
	return GameState.salvage_defs[definition_id].name+" · STRATO %d/%d" % [layer_count()+1,GameState.salvage_defs[definition_id].steps.size()] if can_start_collection() else "STRATI RECUPERATI · cerca gli oggetti sporgenti"

func set_highlighted(_value: bool) -> void:
	pass

func commit_stage(peer_id: int, tool: int = 0) -> Dictionary:
	if not can_start_collection():
		return {"success":false,"message":display_name()}
	var point: Vector3 = recovery_point if recovery_point!=Vector3.ZERO else global_position+Vector3.UP*preload("res://scripts/gameplay/landfill_layout.gd").surface_height(Vector3.ZERO,int(get_meta("profile_zone",0)))
	var result: Dictionary = GameState.ops.claim_pile("searched_"+str(name),definition_id,layer_count(),peer_id,tool,point)
	if result.success:
		_release_required = true
	return result
