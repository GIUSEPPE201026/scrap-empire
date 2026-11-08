extends "res://scripts/gameplay/yard_vehicle.gd"
var steering_bar: Node3D
var push_clock: float=0.0

func _process(delta: float) -> void:
	push_clock+=delta
	if vehicle_kind=="skateboard" and is_instance_valid(rider):
		var driver=visual.get_parent()
		rider.skate_push=maxf(0,sin(push_clock*7))*float(not parked and driver is CharacterBody3D and driver.is_on_floor() and Input.is_action_pressed("move_forward"))

func available() -> bool:
	return visible and parked and preload("res://scripts/economy/extra_mobility.gd").owned(vehicle_kind)

func _ready() -> void:
	add_to_group("yard_vehicles")
	body=StaticBody3D.new()
	var collision=CollisionShape3D.new()
	collision.shape=BoxShape3D.new()
	collision.shape.size=Vector3(0.55,0.35,1.05) if vehicle_kind=="skateboard" else Vector3(0.65,1.2,1.9)
	collision.position.y=0.2 if vehicle_kind=="skateboard" else 0.7
	body.add_child(collision)
	add_child(body)
	visual=Node3D.new()
	add_child(visual)
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	if vehicle_kind=="skateboard":
		for x in [-0.20,0.20]:
			for z in [-0.36,0.36]: _add_wheel(Vector3(x,0.075,z),0.075,0.06,art)
	else:
		for z in [-0.85,0.82]: _add_wheel(Vector3(0,0.42,z),0.42,0.15,art)
		_build_headlights()
		headlights.pop_back().queue_free()
		for light in headlights:
			light.position=Vector3(0,1.1,-0.88)
	if DisplayServer.get_name()=="headless": return
	if vehicle_kind=="skateboard":
		art.beveled_box(visual,Vector3(0.43,0.055,0.94),Vector3(0,0.17,0),Color("#bc6548"),true)
		art.beveled_box(visual,Vector3(0.40,0.012,0.80),Vector3(0,0.205,0),art.GRAPHITE)
		for side in [-1,1]:
			var kick=art.beveled_box(visual,Vector3(0.4,0.05,0.2),Vector3(0,0.2,side*0.48),art.RUST)
			kick.rotation.x=-side*0.22
			art.beam(visual,Vector3(-0.22,0.11,side*0.36),Vector3(0.22,0.11,side*0.36),0.06,art.STEEL)
	else:
		for wheel in wheels:
			for index in 12:
				var angle: float=index*TAU/12
				art.beam(wheel.get_child(0),Vector3.ZERO,Vector3(0,cos(angle)*0.3,sin(angle)*0.3),0.018,art.STEEL)
				var tread=art.box(wheel.get_child(0),Vector3(0.19,0.06,0.13),Vector3(0,cos(angle)*0.41,sin(angle)*0.41),art.GRAPHITE)
				tread.rotation.x=angle
		for side in [-1,1]:
			art.beam(visual,Vector3(0,0.42,0.82),Vector3(side*0.15,0.8,0),0.075,art.STEEL)
			art.beam(visual,Vector3(side*0.15,0.8,0),Vector3(0,1.2,-0.55),0.075,art.RUST)
			art.beam(visual,Vector3(side*0.14,1.1,-0.6),Vector3(0,0.42,-0.85),0.07,art.YELLOW)
			art.beam(visual,Vector3(side*0.15,0.65,0.15),Vector3(0,1.08,0.65),0.07,art.STEEL)
		art.beveled_box(visual,Vector3(0.46,0.3,0.62),Vector3(0,0.98,-0.18),art.RUST,true)
		art.beveled_box(visual,Vector3(0.36,0.12,0.85),Vector3(0,1.16,0.27),art.GRAPHITE)
		art.beveled_box(visual,Vector3(0.42,0.055,0.68),Vector3(0,0.98,0.75),art.RUST,true)
		art.beveled_box(visual,Vector3(0.42,0.055,0.6),Vector3(0,0.95,-0.88),art.RUST,true)
		art.cylinder(visual,0.22,0.4,Vector3(0,0.6,0),art.STEEL,24).rotation.z=PI/2
		for index in 4: art.box(visual,Vector3(0.45,0.035,0.38),Vector3(0,0.49+index*0.07,0),art.GRAPHITE)
		art.beam(visual,Vector3(0.22,0.6,0),Vector3(0.29,1,0.75),0.13,art.STEEL)
		steering_bar=Node3D.new()
		steering_bar.position=Vector3(0,1.35,-0.55)
		visual.add_child(steering_bar)
		art.beam(steering_bar,Vector3(-0.4,0,-0.08),Vector3(0.4,0,-0.08),0.06,art.GRAPHITE)
		art.box(visual,Vector3(0.26,0.18,0.1),Vector3(0,1.15,-0.78),Color("#fff0b3"))
	rider=preload("res://scripts/gameplay/worker_model.gd").new()
	rider.seated=0.0 if level==1 else 0.55
	rider.skate_pose=level==1
	rider.bike_pose=level==3
	rider.position.y=0.21 if level==1 else -0.05
	visual.add_child(rider)
	if vehicle_kind=="skateboard":
		for index in [2,3,6,7]: rider.segments[index].layers=1<<19
	rider.hide()

func animate_wheels(distance: float, steering: float) -> void:
	super.animate_wheels(distance,steering)
	if is_instance_valid(steering_bar): steering_bar.rotation.y=-steering*0.4
