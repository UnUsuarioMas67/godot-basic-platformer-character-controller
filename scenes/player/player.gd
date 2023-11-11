extends CharacterBody2D

@export_group("Run")
@export var run_speed := 100.0
@export var acceleration := 1800.0
@export_range(0.0, 2.0) var air_accel_mult := .65

@export_group("Fall")
@export var ascend_gravity := 1000.0
@export var fall_gravity := 1100.0
@export var max_fall_speed := 600.0

@export_group("Jump")
@export var jump_speed := 300.0
@export_range(1.0, 5.0) var jump_release_grav_mult := 2.0
@export_subgroup("Apex Point")
@export var apex_vel := 100.0
@export_range(0.0, 1.0) var apex_mult := 0.5

@export_subgroup("Input Handling")
@export_range(0.0, 0.5) var coyote_time := 0.1
@export_range(0.0, 0.5) var jump_buffer_time := 0.1

@export_group("Corner Correction")
@export var enable_corner_correction := true
@export var max_corner_correction := 6
@export var corner_correction_precision := 2.0


var coyote_timer: Timer 
var jump_buffer_timer: Timer 
var jump_released := false


func _ready():
	if coyote_time > 0.0:
		coyote_timer = Timer.new()
		coyote_timer.one_shot = true
		coyote_timer.wait_time = coyote_time
		add_child(coyote_timer)
	
	if jump_buffer_time > 0.0:
		jump_buffer_timer = Timer.new()
		jump_buffer_timer.one_shot = true
		jump_buffer_timer.wait_time = jump_buffer_time
		add_child(jump_buffer_timer)


func _physics_process(delta):
	accelerate()
	fall()

	var can_jump = is_on_floor() or coyote_time_active()
	if can_jump && jump_buffered():
		jump()
	if !Input.is_action_pressed("jump"):
		jump_released = true
	
	if velocity.y < 0 and enable_corner_correction:
		apply_corner_correction()
	
	var was_on_floor = is_on_floor()
	move_and_slide()
	var just_left_ground = was_on_floor and !is_on_floor()
	
	if just_left_ground and velocity.y >= 0:
		start_coyote_time()
	


func _unhandled_input(event):
	if event.is_action_pressed("jump"):
		start_jump_buffer()


func get_input_vector():
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func start_jump_buffer():
	if !jump_buffer_timer:
		return
	jump_buffer_timer.start()


func jump_buffered() -> bool:
	if !jump_buffer_timer:
		return false
	return !jump_buffer_timer.is_stopped()


func end_jump_buffer():
	if !jump_buffer_timer:
		return
	jump_buffer_timer.stop()


func start_coyote_time():
	if !coyote_timer:
		return
	coyote_timer.start()


func coyote_time_active() -> bool:
	if !coyote_timer:
		return false
	return !coyote_timer.is_stopped()


func end_coyote_time():
	if !coyote_timer:
		return
	coyote_timer.stop()


func accelerate():
	var delta = get_physics_process_delta_time()
	var run_mult = 1.0 if is_on_floor() else air_accel_mult
	var input_x = sign(get_input_vector().x)
	
	velocity.x = move_toward(velocity.x, run_speed * input_x, acceleration * run_mult * delta)


func fall():
	var delta = get_physics_process_delta_time()
	var gravity = fall_gravity if velocity.y >= 0 else ascend_gravity
	var grav_mult = jump_release_grav_mult if velocity.y < 0 and jump_released else 1.0
	
	if abs(velocity.y) <= apex_vel and !jump_released:
		grav_mult *= apex_mult
	
	velocity.y = move_toward(velocity.y, max_fall_speed, gravity * grav_mult * delta)


func jump():
	end_coyote_time()
	end_jump_buffer()
	
	jump_released = false
	velocity.y = -jump_speed


func apply_corner_correction() -> void:
	var delta := get_physics_process_delta_time()
	var rel_vec := Vector2(0, velocity.y * delta)
	
	if test_move(global_transform, rel_vec):
		var rounded_transform := global_transform
		rounded_transform.origin.x = ceil(rounded_transform.origin.x)
		
		for i in range(1, max_corner_correction * corner_correction_precision + 1):
			for j in [-1, 1]:
				var translated_transform := rounded_transform.translated(Vector2(
					i / corner_correction_precision * j,
					0
				))
				if correct_transform(translated_transform, rel_vec):
					return


func correct_transform(corrected_transform: Transform2D, rel_vec: Vector2) -> bool:
	if test_move(corrected_transform, rel_vec):
		return false

	var translation := corrected_transform.origin - global_transform.origin
	global_transform = corrected_transform
#	velocity.x = max(0, velocity.x * translation.x)
	return true
