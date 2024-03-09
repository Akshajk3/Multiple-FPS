extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var rifle_flash = $Camera3D/rifle/MuzzleFlash
@onready var pistol_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var mesh = $MeshInstance3D
@onready var rifle = $Camera3D/rifle
@onready var pistol = $Camera3D/Pistol

@export var health = 100

@onready var muzzel_flash = pistol_flash

const SPEED = 10.0
const JUMP_VELOCITY = 9

var current_weapon = "pistol"

@export var MOUSE_SENS = 0.003

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

var paused = false

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	get_parent().sens_changed.connect(update_sens)
	get_parent().color_changed.connect(update_color)
	get_parent().game_paused.connect(pause)

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	if paused:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		

func _process(delta):
	if not is_multiplayer_authority():
		return
	if paused:
		return
	if Input.is_action_pressed("shoot") and anim_player.current_animation != current_weapon + "_shoot":
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

	
	if Input.is_action_just_pressed("1"):
		current_weapon = "pistol"
		rifle.hide()
		pistol.show()
		muzzel_flash = pistol_flash
	if Input.is_action_just_pressed("2"):
		current_weapon = "rifle"
		pistol.hide()
		rifle.show()
		muzzel_flash = rifle_flash

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	if anim_player.current_animation == current_weapon + "_shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play(current_weapon + "_move")
	else:
		anim_player.play(current_weapon + "_idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play(current_weapon + "_shoot")
	muzzel_flash.restart()
	muzzel_flash.emitting = true

@rpc("any_peer")
func receive_damage():
	health -= 10
	if health <= 0:
		health = 100
		position = Vector3.ZERO
	health_changed.emit(health)

@rpc("call_local")
func set_player_remote_color(color):
	mesh.material_override.albedo_color = color

func _on_animation_player_animation_finished(anim_name):
	if anim_name == current_weapon + "_shoot":
		anim_player.play(current_weapon + "_idle")
		
func update_sens(sens):
	MOUSE_SENS = sens / 10000

func change_color(color):
	update_color(color)

@rpc("call_remote")
func update_color(color):
	var new_material = StandardMaterial3D.new()
	new_material.albedo_color = color
	mesh.material_override = new_material

func pause(state):
	paused = state
