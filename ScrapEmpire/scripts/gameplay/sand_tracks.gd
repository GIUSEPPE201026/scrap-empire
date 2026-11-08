extends MultiMeshInstance3D
## Bounded cosmetic tyre imprints, independent of the vehicle transform.
const LIMIT=640
var cursor: int=0
var stamps: int=0
var last: Dictionary={}

func _ready() -> void:
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.instance_count=LIMIT
	multimesh.visible_instance_count=0
	var plane=PlaneMesh.new()
	plane.size=Vector2(0.25,0.56)
	multimesh.mesh=plane
	var material=ShaderMaterial.new()
	var shader=Shader.new()
	shader.code="shader_type spatial; render_mode blend_mix,depth_draw_never,cull_disabled; void fragment(){float edge=(1.0-smoothstep(0.32,0.5,abs(UV.x-0.5)))*(1.0-smoothstep(0.34,0.5,abs(UV.y-0.5))); ALBEDO=vec3(0.28,0.17,0.09); ROUGHNESS=1.0; ALPHA=edge*(0.3+0.15*step(0.5,fract(UV.y*8.0)));}"
	material.shader=shader
	material_override=material
	add_to_group("sand_tracks")

func trail(id: int, point: Vector3, normal: Vector3, direction: Vector3) -> void:
	if last.has(id) and point.distance_to(last[id])<0.35:
		return
	last[id]=point
	var forward=direction.slide(normal).normalized()
	if forward.length_squared()<0.5:
		return
	var right=forward.cross(normal).normalized()
	var pose=Transform3D(Basis(right,normal,right.cross(normal).normalized()),point+normal*0.015)
	multimesh.set_instance_transform(cursor,pose)
	cursor=(cursor+1)%LIMIT
	stamps=mini(stamps+1,LIMIT)
	multimesh.visible_instance_count=stamps
