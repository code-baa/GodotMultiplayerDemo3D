extends CharacterBody3D

class_name Player

@onready var camera_3d: Camera3D = $Camera3D

const enums = preload("res://Game/enums.gd")
const PlayerStats = preload("res://Game/Player/player_stats.gd")
const PlayerInputProto = preload("res://Game/proto/player_input.gd")
const Projectile = preload("res://Game/Projectile/projectile.tscn")
const DeadTexture = preload("res://Textures/hit_playerpng.png")
const LiveTexture = preload("res://Textures/player_face.png")
const PlayerInput = preload("res://Game/Player/player_input.gd")

@onready var collision_shape_3d := $CollisionShape3D
@onready var _mesh := $mesh
@onready var respawn_timer := $RespawnTimer

##################################################################################################
# Tunable consts
##################################################################################################
const server_max_input_dict_size := 10000
const server_max_position_size := 1000
const server_min_position_size := 300
const jump_buffer_time := 0.1
const coyote_jump_time := 0.1
const clock_sync_delay := 3.0
const respawn_time := 2.0
const spawn_position_y := 5
const spawn_position_x_min := -5
const spawn_position_x_max := 5

##################################################################################################
# State sets
##################################################################################################
const can_jump_states := [enums.states.IDLE, enums.states.MOVE]
const is_in_air_states := [enums.states.JUMPING, enums.states.FALLING, enums.states.LANDING]

##################################################################################################
# Shared variables
##################################################################################################
# renders the state of the player as a label if true
var debug := true
var id: int
#TODO: optimize if needed
var input_dict := {}
@export var mouse_sensitivity = 0.1
var mouse_unlocked : bool = false
var state := enums.states.IDLE
var stats := PlayerStats.BaseChar.new()
var direction := enums.directions.RIGHT
var projectile_id := 0
var username := ""
@export var max_speed = 15.0
@export var sprint_speed = 12.0
@export var run_speed = 9.0
@export var move_acceleration = 4.0
@export var stop_drag = 0.9
var move_drag = 0.0
var move_dir : Vector3



signal health_updated(new_health: int)

var health := 0:
	set(value):
		if state == enums.states.DEAD:
			return
		health = value
		if health <= 0:
			die()
			health = 0
		health_updated.emit(value)

##################################################################################################
# Client variables
##################################################################################################
# true if this instance is the one the player is controlling
var this_player := false
# used for client/server reconciliation
var previous_inputs_and_positions := {}

signal add_projectile(projectile: Projectile)

##################################################################################################
# Server variables
##################################################################################################
# used for collision lag compensation
var previous_positions := {}








##################################################################################################
# Client functions
##################################################################################################
func process_client_inputs(tick: int) -> void: # captures real-time inputs and stores them per server tick
	var input := PlayerInput.new()
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	input.movement_x = input_dir.x
	input.movement_y = input_dir.y
	input.rotation_y = rotation.y
	
	if Input.is_action_pressed("jump"):
		input.jump = true
	else:
		input.jump = false
		
	if Input.is_action_just_pressed("attack"):
		input.attack = true
	else:
		input.attack = false
		
	input_dict[tick] = input
	
	if !MultiplayerManager.is_host:
		var input_proto: PlayerInputProto.InputDictProto = PlayerInputProto.InputDictProto.new()
		for key: int in input_dict.keys():
			var i: PlayerInputProto.InputDictProto.PlayerInputProto = input_proto.add_inputs(key)
			i.set_movement_x(input_dict[key].movement_x)
			i.set_movement_y(input_dict[key].movement_y)
			i.set_rotation_y(input_dict[key].rotation_y)
			i.set_attack(input_dict[key].attack)
			i.set_jump(input_dict[key].jump)
		MultiplayerManager.recieve_player_input.rpc_id(1, input_proto.to_bytes())
	
	
func set_move_dir(new_move_dir : Vector3):
	move_dir = new_move_dir
	move_dir.y = 0.0
	move_dir = move_dir.normalized()
	
	
func prune_old_inputs(server_tick: int) -> void: # removes inputs and reconciliation data older than the servers current tick
	#TODO: optimize if needed
	for tick: int in input_dict.keys():
		if tick < server_tick:
			input_dict.erase(tick)
			previous_inputs_and_positions.erase(tick)


func reapply_inputs(server_tick: int, delta: float) -> void: # used for client-side prediction. 
	var client_tick := Clock.tick
	var t := server_tick
	while t < client_tick:
		apply_inputs(t) # applies stores inputs/movement from a specific server stick
		apply_physics(delta) 
		var p: Dictionary = previous_inputs_and_positions.get(t)
		if p == null:
			p = {}
		p["position"] = position
		previous_inputs_and_positions[t] = p
		t += 1
	
	
	
	
	
	
	
	
	
##################################################################################################
# Server functions
##################################################################################################
func update_input_dict(input_proto: PackedByteArray, _server_tick: int) -> void: # called on host when it receives inputs from client
	var i := PlayerInputProto.InputDictProto.new()
	var result := i.from_bytes(input_proto)
	if result != PlayerInputProto.PB_ERR.NO_ERRORS:
		return
	
	var proto_dict: Dictionary = i.get_inputs()
	for each_tick: int in proto_dict.keys():
		if input_dict.has(each_tick) or each_tick < Clock.tick:
			continue
		var p: PlayerInput = PlayerInput.new()
		p.movement_x = proto_dict[each_tick].get_movement_x()
		p.movement_y = proto_dict[each_tick].get_movement_y()
		p.rotation_y = proto_dict[each_tick].get_rotation_y()
		p.attack = proto_dict[each_tick].get_attack()
		p.jump = proto_dict[each_tick].get_jump()
		input_dict[each_tick] = p
	
	#TODO: optimize if needed
	if len(input_dict) > server_max_input_dict_size:
		for tick: int in input_dict.keys():
			if tick < Clock.tick:
				input_dict.erase(tick)

func prune_previous_positions() -> void: # ensures the rollback buffer 
	if previous_positions.size() > server_max_position_size:
		var min_key: int = previous_positions.keys().min()
		var i := 0
		while i < server_max_position_size - server_min_position_size:
			previous_positions.erase(min_key + i)
			i = i + 1













##################################################################################################
# Shared functions
##################################################################################################
func _ready() -> void:
	if MultiplayerManager.is_host:
		respawn()
	if this_player:
	#	var camera := Camera3D.new()
	#	add_child(camera)
		camera_3d.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		#camera.position_smoothing_enabled = true
		#camera.position_smoothing_speed = 5
		#camera.limit_bottom = 250
		health = stats.max_health


func set_id(id_: int) -> void:
	id = id_
	
func _input(event):
	if Input.is_action_just_pressed('exit'):
		get_tree().quit()
	if Input.is_action_just_pressed('unlock_mouse'):
		mouse_unlocked = !mouse_unlocked
		if mouse_unlocked:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if mouse_unlocked:
		return
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		camera_3d.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	
func set_username(username_: String) -> void:
	if username != username_:
		username = username_
		$Name.text = username_


func get_random_spawn_point() -> Vector3:
	return Vector3(randi_range(spawn_position_x_min, spawn_position_x_max), spawn_position_y, randi_range(spawn_position_x_min, spawn_position_x_max))


func _physics_process(delta: float) -> void:
	update_material()
	if debug:
		$DebugStatus.text = enums.states.keys()[state]
	if !this_player and !MultiplayerManager.is_host:
		return
	var current_tick := Clock.tick
	if this_player and !MultiplayerManager.is_server:
		process_client_inputs(current_tick)
	if position.y < -50:
		fell_off()
	
	var last_input: PlayerInput = apply_inputs(current_tick)
	
	apply_physics(delta)
	
	if last_input != null:
		if !MultiplayerManager.is_host:
			var input_and_position: Dictionary = {
				"input": last_input,
				"position": position
			}
			previous_inputs_and_positions[current_tick] = input_and_position
			
	if MultiplayerManager.is_host:
		previous_positions[current_tick] = position
		prune_previous_positions()

		
func apply_physics(delta: float) -> void:
	if state == enums.states.DEAD:
		return
	if not is_on_floor():
		velocity.y -= _get_gravity() * delta
		
		if velocity.y > stats.terminal_velocity:
			velocity.y = stats.terminal_velocity
		if state != enums.states.JUMPING and state != enums.states.LANDING:
			if state == enums.states.MOVE:
				$CoyoteJumpTimer.start(coyote_jump_time)
			state = enums.states.FALLING

	
	if state == enums.states.FALLING and $FloorDetector.is_colliding():
		state = enums.states.LANDING
	if ((velocity.z + velocity.x) == 0) and is_on_floor():
		state = enums.states.IDLE
	if is_on_floor() and ((velocity.z != 0) or (velocity.x != 0)):
		state = enums.states.MOVE
	move_and_slide()
	
	
func apply_inputs(tick: int) -> PlayerInput:
	var input: PlayerInput = input_dict.get(tick)
	if input == null:
		return null

	rotation.y = input.rotation_y
	move_dir = (transform.basis * Vector3(input.movement_x, 0, input.movement_y))
	move_drag = float(move_acceleration) / max_speed
	var drag = move_drag
	if move_dir.is_zero_approx():
		drag = stop_drag
			
	var flat_velocity = velocity
	flat_velocity.y = 0.0
	velocity += move_acceleration * move_dir - flat_velocity * drag
	
	if input.jump:
		jump()
		
	if input.attack:
		attack()
		
	return input
		
		
func update_material() -> void:
	if state == enums.states.DEAD:
		var mat = _mesh.get_active_material(0)
		mat.albedo_color = Color(1.0, 0.0, 0.0)
		return
	var mat = _mesh.get_active_material(0)
	mat.albedo_color = Color(0.0, 0.0, 0.0)


func jump() -> void:
	if state == enums.states.DEAD:
		return
	if state == enums.states.JUMPING:
		return
	_jump()


func _jump() -> void:
	#velocity.y = +stats.jump_speed
	velocity.y = stats.jump_force
	state = enums.states.JUMPING


func attack() -> void:
	if state == enums.states.DEAD:
		return
	if !$AttackCooldown.is_stopped():
		return
	$AttackCooldown.start(stats.attack_recharge_time)
	var new_projectile := Projectile.instantiate()
	new_projectile.owner_id = id
	projectile_id += 1
	new_projectile.id = projectile_id
	new_projectile.damage = stats.projectile_damage
	new_projectile.position = position
	new_projectile.owned_by_this_player = this_player
	if direction == enums.directions.RIGHT:
		new_projectile.velocity = stats.projectile_speed * Vector2(1.0, 0)
	else:
		new_projectile.velocity = stats.projectile_speed * Vector2(-1.0, 0)
	new_projectile.time_to_live = stats.projectile_time
	if !MultiplayerManager.is_host:
		add_projectile.emit(new_projectile)
	if MultiplayerManager.is_host:
		MultiplayerManager.add_projectile(new_projectile)


func _get_gravity() -> int:
	if state == enums.states.FALLING:
		return stats.fall_gravity
	else:
		return stats.jump_gravity
		
		
func _on_jump_timer_timeout() -> void:
	if state == enums.states.DEAD:
		return
	if is_on_floor():
		state = enums.states.IDLE
	else:
		state = enums.states.FALLING


func fell_off() -> void:
	die()
	
	
func die() -> void:
	state = enums.states.DEAD
	respawn_timer.start(respawn_time)
	
	
func respawn() -> void:
	velocity = Vector3.ZERO
	state = enums.states.IDLE
	health = stats.max_health
	if MultiplayerManager.is_host:
		MultiplayerManager.hard_reset_position(id, get_random_spawn_point())


func can_jump() -> bool:
	return can_jump_states.has(state)


func take_damage(amount: int) -> void:
	if MultiplayerManager.is_host:
		health = health - amount


func _on_respawn_timer_timeout() -> void:
	respawn()
