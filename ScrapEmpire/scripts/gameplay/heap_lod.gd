extends Node
var batches: Array[MultiMeshInstance3D] = []
var detailed: Array[Mesh] = []
var simplified: Array[Mesh] = []
var _elapsed: float = 0.0
var _level: int = -1

func register(batch: MultiMeshInstance3D) -> void:
	var high: Mesh = batch.multimesh.mesh
	var low: Mesh = high
	if high is CylinderMesh:
		var cylinder = high.duplicate() as CylinderMesh
		cylinder.radial_segments=10
		cylinder.rings=1
		low=cylinder
	elif high is TorusMesh:
		var tyre = high.duplicate() as TorusMesh
		tyre.rings=12
		tyre.ring_segments=6
		low=tyre
	batches.append(batch)
	detailed.append(high)
	simplified.append(low)

func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<0.4:
		return
	_elapsed=0
	var camera = get_viewport().get_camera_3d()
	if camera==null:
		return
	var distance: float = camera.global_position.distance_to(get_parent().global_position)
	# Hysteresis avoids switching when standing near a threshold.
	var level: int = 0 if distance<(48.0 if _level==0 else 40.0) else 1
	if level==_level:
		return
	_level=level
	for index in batches.size():
		batches[index].multimesh.mesh=detailed[index] if level==0 else simplified[index]
		batches[index].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
