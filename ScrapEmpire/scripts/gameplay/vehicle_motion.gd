extends RefCounted
## Local drivetrain. Bicycle steering/velocity alignment adapted from KidsCanCode
## 3d_car_tutorial (MIT, Copyright (c) 2020 KidsCanCode).
## See third_party/kidscancode_car/LICENSE.txt and README.md.
var speed: float = 0.0
var heading: float = 0.0
var contact_up: Vector3 = Vector3.UP
var chassis_up: Vector3 = Vector3.UP
var coyote: float = 0.0
var jump_buffer: float = 0.0
var jump_lock: float = 0.0
var wheel_distance: float = 0.0
var contact_offset: float = 0.0
var config: Dictionary = {}
var suspension_velocity: float = 0.0
var wheel_offsets: Array[float] = [0.0,0.0,0.0,0.0]
var contacts: int = 0
var contact_points: Array[Vector3] = []
var contact_valid: Array[bool] = []
var body_angles: Vector2 = Vector2.ZERO
var angular_velocity: Vector2 = Vector2.ZERO
var last_speed: float = 0.0
var parking_brake: bool = false
var steer_angle: float = 0.0
var _vehicle: Node3D
var _delta: float = 1.0/60.0
var drift_blend: float = 0.0
var drift_angle: float = 0.0
var drifting: bool=false

func reset(yaw: float, inherited_velocity: Vector3, definition: Dictionary) -> void:
	heading = yaw
	config = definition
	var forward = Vector3(-sin(yaw), 0, -cos(yaw))
	speed = clampf(inherited_velocity.dot(forward), -float(config.speed_mps) * 0.35, float(config.speed_mps))
	contact_up = Vector3.UP
	chassis_up = Vector3.UP
	coyote = 0.0
	jump_buffer = 0.0
	jump_lock = 0.0
	wheel_distance = 0.0
	contact_offset = 0.0
	body_angles = Vector2.ZERO
	angular_velocity = Vector2.ZERO
	last_speed = speed
	parking_brake = false
	suspension_velocity = 0.0
	wheel_offsets = [0.0,0.0,0.0,0.0]
	steer_angle=0.0
	drift_blend=0.0
	drift_angle=0.0
	drifting=false

func sample_contacts(body: CharacterBody3D, vehicle: Node3D) -> void:
	var half_length: float = 0.54 if vehicle.level == 1 else 1.15
	var half_width: float = 0.17 if vehicle.level == 1 else 1.1
	var basis_yaw = Basis(Vector3.UP, heading)
	var points: Array[Vector3] = []
	var valid_points: Array[Vector3] = []
	var normals=Vector3.ZERO
	contacts = 0
	contact_points.clear()
	contact_valid.clear()
	var offsets: Array=[Vector3(-half_width,0,-half_length),Vector3(half_width,0,-half_length),Vector3(-half_width,0,half_length),Vector3(half_width,0,half_length)]
	if vehicle.level==3: offsets=[Vector3(0,0,-0.85),Vector3(0,0,0.82)]
	for offset in offsets:
		var origin: Vector3 = body.global_position + basis_yaw * offset
		var query = PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 1.8, origin - Vector3.UP * 2.5, 1, [body.get_rid(), vehicle.body.get_rid()])
		var hit = body.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.45:
			points.append(origin-Vector3.UP*0.35)
		else:
			contacts += 1
			points.append(hit.position)
			valid_points.append(hit.position)
			normals+=hit.normal
		contact_points.append(points[-1])
		contact_valid.append(not hit.is_empty() and hit.normal.y>=0.45)
		wheel_offsets[points.size()-1] = clampf(points[-1].y-body.global_position.y,-0.28,0.22)
	if contacts == 0:
		contact_offset = -0.12
		return
	var normal: Vector3 = normals.normalized()
	if contacts==4:
		var across: Vector3=points[1]+points[3]-points[0]-points[2]
		var forward: Vector3=points[0]+points[1]-points[2]-points[3]
		var plane: Vector3=across.cross(forward)
		if plane.length_squared()>0.001:
			normal=plane.normalized()
	elif contacts>=3:
		var plane: Vector3=(valid_points[1]-valid_points[0]).cross(valid_points[2]-valid_points[0])
		if plane.length_squared()>0.001:
			normal=plane.normalized()
			if normal.y<0:
				normal=-normal
	if normal.y > 0.45:
		contact_up = normal
		var total: float=0.0
		for point in valid_points:
			total+=point.y
		contact_offset = clampf(total/contacts-body.global_position.y, -0.95, 0.6)

func step(body: CharacterBody3D, vehicle: Node3D, throttle: float, steering: float, jump: bool, delta: float) -> void:
	_vehicle=vehicle
	_delta=delta
	jump_lock = maxf(0.0, jump_lock - delta)
	var grounded: bool = body.is_on_floor() and jump_lock <= 0
	coyote = 0.1 if grounded else maxf(0.0, coyote - delta)
	jump_buffer = 0.12 if jump else maxf(0.0, jump_buffer - delta)
	if grounded:
		sample_contacts(body, vehicle)
	var motor: float = GameState.module_effect("motor")
	var suspension: float = GameState.module_effect("suspension")
	var top_speed: float = float(config.speed_mps) * motor
	var acceleration: float = float(config.acceleration) * motor
	if vehicle.vehicle_kind=="skateboard": acceleration*=0.35+0.65*maxf(0,sin(vehicle.push_clock*7))
	if vehicle.level == 2:
		var load_ratio: float = minf(GameState.ops.cargo_mass()/float(GameState.logistics_def.cargo_capacity_kg),2.0)
		top_speed *= 1.0-load_ratio*0.06
		acceleration *= 1.0-load_ratio*0.18
	var braking: float = float(config.braking)*(GameState.module_effect("brakes") if vehicle.level==2 else 1.0)
	var tyre_grip: float = GameState.module_effect("tyres") if vehicle.level==2 else 1.0
	var opposite: bool = throttle * speed < -0.1
	if grounded:
		if absf(throttle) > 0.01:
			var target: float = throttle * top_speed * (0.35 if throttle < 0 else 1.0)
			if opposite or absf(speed)<absf(target):
				speed = move_toward(speed, target, braking * delta if opposite else acceleration * delta)
		else:
			speed = move_toward(speed, 0.0, (float(config.get("coast_drag",0.45))*0.3+absf(speed)*0.025) * delta)
		var forward = Vector3(-sin(heading), 0, -cos(heading))
		var tangent: Vector3 = forward.slide(body.get_floor_normal()).normalized()
		# Climbing costs torque; descents gently accelerate rather than magnetic adhesion.
		speed += Vector3.DOWN.dot(tangent) * 9.81 * delta
		speed = clampf(speed, -top_speed * 0.4, top_speed * 1.65)
	var holding_brake: bool = vehicle.level in [2,3] and parking_brake
	var handbrake: bool = vehicle.level==2 and jump and not parking_brake
	if grounded and holding_brake:
		speed = move_toward(speed,0.0,braking*1.4*delta)
	elif grounded and handbrake:
		speed=move_toward(speed,0.0,braking*0.12*delta)
	var speed_ratio: float = clampf(absf(speed) / top_speed, 0, 1)
	var steering_rate: float = float(config.steering) * lerpf(1.0, 0.48, speed_ratio) * minf(suspension, 1.25)
	if vehicle.level == 2:
		var safe_angle: float=minf(0.62,atan(2.25*7.5*tyre_grip/(speed*speed+1.0)))
		if handbrake: safe_angle=maxf(safe_angle,0.38)
		steer_angle=move_toward(steer_angle,steering*safe_angle,2.4*delta*minf(suspension,1.4))
		if grounded:
			# Bicycle model: advance rear wheel along travel velocity, front wheel
			# along the steered velocity. The body can point away from its motion.
			var axis=Vector3(-sin(heading),0,-cos(heading))
			var rear=body.global_position-axis*1.125+body.velocity*delta
			var front=body.global_position+axis*1.125+body.velocity.rotated(Vector3.UP,-steer_angle)*delta
			var new_heading=(front-rear).normalized()
			heading=atan2(-new_heading.x,-new_heading.z)
	else:
		heading -= steering * steering_rate * delta * clampf(absf(speed) / 2, 0, 1) * signf(speed) * (1.0 if grounded else 0.12)
	var direction = Vector3(-sin(heading), 0, -cos(heading))
	var desired: Vector3 = direction * speed
	if grounded:
		desired = direction.slide(body.get_floor_normal()).normalized() * speed
		var normal: Vector3=body.get_floor_normal()
		var forward: Vector3=direction.slide(normal).normalized()
		var planar: Vector3=body.velocity.slide(normal)
		var longitudinal: float=planar.dot(forward)
		# Engine/brake changes the forward component; never invent lateral motion.
		planar+=forward*clampf(speed-longitudinal,-braking*delta,acceleration*delta)
		var slip: float=acos(clampf(planar.normalized().dot(forward*signf(speed)),-1,1)) if planar.length()>0.5 else 0.0
		if handbrake and absf(speed)>2.5 and absf(steering)>0.1: drifting=true
		if not handbrake and (slip<0.12 or planar.length()<2.5): drifting=false
		drift_blend=move_toward(drift_blend,1.0 if drifting else 0.0,delta*5.0)
		# KidsCanCode traction_fast/slow, expressed as rates for frame independence.
		# Countersteer aligns the chassis with travel and restores ordinary grip.
		var traction: float=1.25*tyre_grip if drifting else 10.0*tyre_grip
		var travel_heading=forward*(1.0 if planar.dot(forward)>=0 else -1.0)
		planar=planar.lerp(travel_heading*planar.length(),1.0-exp(-traction*delta))
		body.velocity=planar-normal*0.15
		drift_angle=acos(clampf(planar.normalized().dot(travel_heading),-1,1)) if planar.length()>0.1 else 0.0
		if holding_brake and absf(speed)<0.1:
			speed = 0.0
			body.velocity = -body.get_floor_normal()*0.15
	else:
		drift_angle=0.0
		drift_blend=move_toward(drift_blend,0.0,delta*2)
		body.velocity.x = move_toward(body.velocity.x, desired.x, acceleration * 0.15 * delta)
		body.velocity.z = move_toward(body.velocity.z, desired.z, acceleration * 0.15 * delta)
	if vehicle.level in [1,3] and jump_buffer > 0 and coyote > 0:
		body.velocity.y = float(config.jump_velocity)
		jump_lock = 0.2
		coyote = 0.0
		jump_buffer = 0.0
	wheel_distance += speed * delta
	body.rotation.y = heading
	chassis_up = smooth_contact_up(chassis_up, contact_up if grounded else Vector3.UP, 1 - exp(-float(config.suspension_response) * suspension * delta))
	var local_up: Vector3 = Basis(Vector3.UP, -heading) * chassis_up
	var local_forward = Vector3.FORWARD.slide(local_up).normalized()
	var chassis = Basis.looking_at(local_forward, local_up)
	var lean: float = 0.0
	if vehicle.level == 2:
		var terrain_angles: Vector3 = chassis.get_euler()
		var longitudinal: float = clampf((speed-last_speed)/maxf(delta,0.001),-15,15)
		var yaw_rate: float = -speed/2.25*tan(steer_angle)
		var target_angles = Vector2(terrain_angles.x-longitudinal*0.008,terrain_angles.z+clampf(yaw_rate*speed*0.008,-0.12,0.12)/suspension)
		var angular_remaining: float = minf(delta,0.1)
		while angular_remaining>0:
			var dt: float = minf(angular_remaining,1.0/120.0)
			angular_velocity += ((target_angles-body_angles)*70.0*suspension-angular_velocity*12.0*sqrt(suspension))*dt
			body_angles += angular_velocity*dt
			angular_remaining -= dt
		vehicle.visual.rotation = Vector3(body_angles.x,0,body_angles.y)
	else:
		if vehicle.level==3: lean=steering*speed_ratio*0.32
		elif vehicle.vehicle_kind=="skateboard": lean=steering*speed_ratio*0.12
		vehicle.visual.basis = chassis * Basis(Vector3.FORWARD, lean)
	last_speed = speed
	# Damped spring in small steps: bounded travel and no unstable large-frame bounce.
	var remaining: float = minf(delta,0.1)
	while remaining > 0:
		var dt: float = minf(remaining,1.0/120.0)
		var target_height: float = contact_offset if grounded else -0.08
		suspension_velocity += ((target_height-vehicle.visual.position.y)*85.0*suspension-suspension_velocity*15.0)*dt
		vehicle.visual.position.y = clampf(vehicle.visual.position.y+suspension_velocity*dt,-0.95,0.6)
		remaining -= dt
	vehicle.animate_wheels(wheel_distance, steering)
	if vehicle.level in [2,3]:
		for wheel in vehicle.wheels:
			wheel.rotation.y=-steer_angle if wheel.get_meta("front") else 0.0
		_align_wheels(body,vehicle)

func _align_wheels(body: CharacterBody3D, vehicle: Node3D) -> void:
	var axis: Vector3=vehicle.visual.global_basis.y.normalized()
	for wheel in vehicle.wheels:
		var base: Vector3=wheel.get_meta("rest_position")
		var strut: Vector3=vehicle.visual.to_global(base)
		var hit: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(strut+axis*0.7,strut-axis*1.5,1,[body.get_rid(),vehicle.body.get_rid()]))
		wheel.set_meta("grounded",false)
		var target: float=base.y-0.42
		if not hit.is_empty() and hit.normal.y>0.45:
			var hub: Vector3=hit.position+axis*float(wheel.get_meta("radius"))/maxf(axis.dot(hit.normal),0.5)
			target=vehicle.visual.to_local(hub).y
			wheel.set_meta("ground_point",hit.position)
			wheel.set_meta("ground_normal",hit.normal)
			wheel.set_meta("grounded",target>=base.y-0.42 and target<=base.y+0.18)
		# The visible hub follows the contact immediately; chassis springs absorb
		# motion. Smoothing a second time made tyres hover behind the terrain.
		wheel.position.y=clampf(target,base.y-0.42,base.y+0.18)

static func smooth_contact_up(previous: Vector3, target: Vector3, weight: float) -> Vector3:
	# Up vectors stay in the upper hemisphere. Normalized linear interpolation
	# avoids the tiny cross-product axis used by Vector3.slerp near parallel vectors.
	var blended: Vector3 = previous.lerp(target, clampf(weight, 0, 1))
	return blended.normalized() if blended.length_squared() > 0.000001 else Vector3.UP

func after_slide(body: CharacterBody3D) -> void:
	# Reconcile drivetrain with actual displacement, including floor/crest
	# collisions that Godot does not classify as a wall. No phantom acceleration.
	if body.is_on_floor() or body.is_on_wall():
		var forward=Vector3(-sin(heading),0,-cos(heading))
		if body.is_on_floor(): forward=forward.slide(body.get_floor_normal()).normalized()
		speed=body.get_real_velocity().dot(forward)
		# move_and_slide can flatten velocity.y while snapping downhill. Feeding
		# that flattened vector through slide(normal) every tick erased momentum
		# (and the gravity added above), especially on steeper descents.
		# Carry the actual travelled vector into the next integration instead.
		body.velocity=body.get_real_velocity()
	if is_instance_valid(_vehicle) and _vehicle.level in [2,3]:
		_align_wheels(body,_vehicle)
		_vehicle.update_tracks(body,_delta,speed)
