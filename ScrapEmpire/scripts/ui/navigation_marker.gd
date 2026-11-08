extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")

static func marker(view: Vector2, camera: Camera3D, target: Vector3) -> Dictionary:
	var center=view*0.5
	var local=camera.to_local(target)
	var front: bool=local.z< -0.1
	var point=camera.unproject_position(target) if front else center+Vector2(local.x,maxf(local.z,0.1)).normalized()*view.length()
	var safe=Rect2(Vector2(65,180),view-Vector2(130,370))
	var inside: bool=front and safe.has_point(point)
	if not inside:
		var direction=(point-center).normalized()
		var extent=Vector2(view.x*0.5-65,view.y*0.5-190)
		var scale: float=minf(extent.x/maxf(absf(direction.x),0.001),extent.y/maxf(absf(direction.y),0.001))
		point=center+direction*scale
	return {"position":point,"inside":inside,"angle":(point-center).angle()}

static func draw_marker(hud: Control, player: Node3D) -> void:
	if player._is_paused: return
	var distance: float=Vector2(player.global_position.x-player._navigation_target.x,player.global_position.z-player._navigation_target.z).length()
	var target: Vector3=player._navigation_target+Vector3.UP*2.5
	var data=marker(hud.get_viewport_rect().size,player.camera,target)
	var at: Vector2=data.position
	var color: Color=UI.ORANGE if distance>5 else Color("#8ad6b2")
	if data.inside:
		hud.draw_polyline(PackedVector2Array([at+Vector2(0,-10),at+Vector2(9,0),at+Vector2(0,10),at+Vector2(-9,0),at+Vector2(0,-10)]),color,2.5,true)
	else:
		var direction=Vector2.from_angle(data.angle)
		hud.draw_colored_polygon(PackedVector2Array([at+direction*13,at-direction.rotated(0.75)*10,at-direction.rotated(-0.75)*10]),color)
	var label="ARRIVATO" if distance<=5 else "%.0f m" % distance
	var box=Rect2(at+Vector2(-40,18),Vector2(80,24))
	hud.draw_style_box(UI.style(Color("#202321e8"),false,2),box)
	hud.draw_string(hud.get_theme_default_font(),box.position+Vector2(7,17),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
