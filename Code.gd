# By BatataAgiota125
# Code made with help of AI
# Licensed under MIT License

extends CharacterBody3D

@onready var camera = $Camera3D

var sens = 0.00025
var speed = 4.0
var turn_speed = 10.0
var gravity = 15
var max_grab_time = 1.5
var jump_force = 7.5
var jumps_left = 2
var max_jumps = 2
var dive_force = 150.0
var cam_tilt = 0.0
var normal_fov = 75.0
var dive_fov = 100.0
var dive_down_force = -1.0
var slam_force = 30.0
var hold_time = 0.0
var grab_time = 0.0
var slow_grab_time = 2
var slow_slide_speed = 0.2
var fast_slide_speed = 3.0
var wall_jump_push = 15.0
var regrab_lock_time = 3
var regrab_lock_timer = 0.0
var hold_required = 0.2
var bounce_force = 12.0
var cam_rot_x = 0.0
var wall_normal = Vector3.ZERO
var grab_position = Vector3.ZERO
var last_wall_jump_normal = Vector3.ZERO
var is_holding_shift = false
var just_slammed = false
var was_in_air = false
var shift_pressed = false
var slam_locked_until_release = false
var did_slam = false
var is_diving = false
var is_grabbing = false
var can_dive = true

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_max_angle = deg_to_rad(45.0)
	floor_stop_on_slope = false

func _physics_process(delta):
	if regrab_lock_timer > 0.0:
		regrab_lock_timer -= delta
	
	if is_grabbing:
		grab_time += delta

		var slide_speed = slow_slide_speed
		if grab_time >= slow_grab_time:
			slide_speed = fast_slide_speed

		grab_position.y -= slide_speed * delta
		global_position = grab_position
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var dir = Vector3.ZERO
	var target_fov = normal_fov
	var target_tilt = 0.0

	if is_diving:
		velocity.x *= 0.98
		velocity.z *= 0.98

	if is_diving:
		target_fov = dive_fov

	camera.fov = lerp(camera.fov, target_fov, 0.1)

	if is_diving:
		target_tilt = -0.2   # inclina pra frente

	cam_tilt = lerp(cam_tilt, target_tilt, 0.1)
	
	if not is_on_floor() and not is_grabbing and velocity.y < 0:
		if $FrontRay.is_colliding() and not $TopRay.is_colliding():
			var current_wall_normal = $FrontRay.get_collision_normal()

			var same_wall = current_wall_normal.dot(last_wall_jump_normal) > 0.9

			if regrab_lock_timer <= 0.0 or not same_wall:
				start_grab()


	# movimento WASD
	if Input.is_action_pressed("w"):
		dir -= transform.basis.z
	if Input.is_action_pressed("s"):
		dir += transform.basis.z
	if Input.is_action_pressed("a"):
		dir -= transform.basis.x
	if Input.is_action_pressed("d"):
		dir += transform.basis.x

	dir = dir.normalized()

	# movimento suave
	velocity.x = lerp(velocity.x, dir.x * speed, 0.15)
	velocity.z = lerp(velocity.z, dir.z * speed, 0.15)

	# gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta
		var floor_normal = get_floor_normal()
		if floor_normal != Vector3.ZERO:
			var slope_dir = Vector3.DOWN.slide(floor_normal)
			velocity += slope_dir * 5.0 * delta
	else:
		jumps_left = max_jumps
		is_diving = false
		can_dive = true
		
	# detectar impacto no chão
	if was_in_air and is_on_floor():
		if did_slam:
			if is_holding_shift:
				velocity.y = bounce_force
				just_slammed = true
				slam_locked_until_release = true
			
			did_slam = false
			hold_time = 0.0
		
		can_dive = true


	was_in_air = not is_on_floor()
		
	# contando tempo segurando
	if is_holding_shift and not is_on_floor() and not slam_locked_until_release:
		hold_time += delta
		
		if hold_time >= hold_required and not did_slam:
			is_diving = false
			did_slam = true

			velocity.x = 0
			velocity.z = 0
			velocity.y = -slam_force

			# DETECTA O QUE ESTÁ EM BAIXO
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 2)
			var result = space_state.intersect_ray(query)

			if result:
				var body = result["collider"]
				if body and body.is_in_group("trunks"):
					body.sink()

	# pulo (duplo)
	if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
		velocity.y = jump_force
		jumps_left -= 1
		can_dive = true
		just_slammed = false

	move_and_slide()

func start_grab():
	if is_grabbing:
		return

	is_grabbing = true
	is_diving = false
	did_slam = false
	velocity = Vector3.ZERO
	grab_time = 0.0

	var wall_point = $FrontRay.get_collision_point()
	wall_normal = $FrontRay.get_collision_normal()

	grab_position = wall_point + wall_normal * 0.45
	grab_position.y -= 0.8

func _input(event):
	if event is InputEventKey:
		if event.is_action_pressed("shift"):
			shift_pressed = true
			is_holding_shift = true
			hold_time = 0.0
		
		if event.is_action_released("shift"):
			if hold_time < hold_required and not is_on_floor() and can_dive and not just_slammed and not did_slam:
				is_diving = true
				can_dive = false
				
				var forward = -transform.basis.z
				velocity.x = lerp(velocity.x, forward.x * dive_force, 0.5)
				velocity.z = lerp(velocity.z, forward.z * dive_force, 0.5)
				velocity.y = -dive_down_force
			
			shift_pressed = false
			is_holding_shift = false
			slam_locked_until_release = false
			hold_time = 0.0
			just_slammed = false

	
	if event is InputEventMouseMotion:
		# gira o corpo (esquerda/direita)
		rotate_y(-event.relative.x * sens * turn_speed)

		cam_rot_x -= event.relative.y * sens * turn_speed
		cam_rot_x = clamp(cam_rot_x, -1.5, 1.5)

		camera.rotation.x = cam_rot_x + cam_tilt
	
	if is_grabbing:
		if event.is_action_pressed("ui_accept"):
			is_grabbing = false
			regrab_lock_timer = regrab_lock_time
			last_wall_jump_normal = wall_normal

			var jump_dir = wall_normal
			jump_dir.y = 0.0
			jump_dir = jump_dir.normalized()

			velocity = jump_dir * wall_jump_push
			velocity.y = jump_force

		if event.is_action_pressed("s"):
			is_grabbing = false
			regrab_lock_timer = regrab_lock_time
			velocity.y = -2.0
