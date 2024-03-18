extends CharacterBody3D

signal health_changed(health_value)
signal ammo_changed(ammo_value)
signal hitmarker()

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var rifle_flash = $Camera3D/rifle/MuzzleFlash
@onready var pistol_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var mesh = $MeshInstance3D
@onready var rifle = $Camera3D/rifle
@onready var pistol = $Camera3D/Pistol
@onready var username_label = $Username
@onready var dash_cooldown = $DashCooldown
@onready var dash_timer = $DashTimer
@onready var death_timer = $DeathTimer
@onready var rifle_player = $"Camera3D/Hand/FPS Rifle/Rifle Player"

@export var health = 100
@onready var player_color = mesh.material_override.albedo_color

@onready var muzzel_flash = pistol_flash

const JUMP_VELOCITY = 9

@export var walk_speed = 10.0
@export var sprint_speed = 15.0
@export var ads_speed = 5.0

var SPEED = walk_speed

@export var base_fov = 75.0
@export var fov_change = 1.5

var rifle_ammo = 30
var pistol_ammo = 8

var ammo = rifle_ammo

var rifle_damage = 10
var pistol_damage = 25

var current_damage = rifle_damage

var current_weapon = "rifle"


@export var MOUSE_SENS = 0.003

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

var paused = false
var sprinting = false
var reloading = false
var aiming = false
var direction = Vector3()

@export var dash_speed = 50
var can_dash = true

var dead = false

var color = Color(1.0, 1.0, 1.0)

var hit_player

var score = 0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	get_parent().sens_changed.connect(update_sens)
	get_parent().color_changed.connect(change_color)
	get_parent().game_paused.connect(pause)
	get_parent().username_changed.connect(update_username)
	color = mesh.material_override.albedo_color

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	if paused:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		

func dash():
	if Input.is_action_pressed("dash") and can_dash and not aiming:
		SPEED = dash_speed
		await get_tree().create_timer(0.1).timeout
		can_dash = false
		dash_cooldown.start()

func _process(delta):
	if not is_multiplayer_authority():
		return
	if paused:
		return
	if Input.is_action_pressed("shoot") and rifle_player.current_animation != "Rig|AK_Shot" and rifle_player.current_animation != "Rig|AK_Reload" and ammo > 0:
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			hit_player = raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			hitmarker.emit()
	
	if Input.is_action_just_pressed("reload") and rifle_player.current_animation != "Rig|AK_Reload":
		if current_weapon == "rifle" and ammo >= 30:
			pass
		elif current_weapon == "pistol" and ammo >= 8:
			pass
		else:
			play_reload_effects.rpc()
	
	#if Input.is_action_just_pressed("2") and anim_player.current_animation != current_weapon + "_reload" and current_weapon != "pistol":
		#current_weapon = "pistol"
		#rifle.hide()
		#pistol.show()
		#muzzel_flash = pistol_flash
		#rifle_ammo = ammo
		#ammo = pistol_ammo
		#ammo_changed.emit(ammo)
		#current_damage = pistol_damage
	#if Input.is_action_just_pressed("1") and anim_player.current_animation != current_weapon + "_reload" and current_weapon != "rifle":
		#current_weapon = "rifle"
		#pistol.hide()
		#rifle.show()
		#muzzel_flash = rifle_flash
		#pistol_ammo = ammo
		#ammo = rifle_ammo
		#ammo_changed.emit(ammo)
		#current_damage = rifle_damage
	
	if Input.is_action_pressed("ads"):
		aiming = true
		camera.fov = lerp(camera.fov, 20.0, delta * 5.0)
	else:
		aiming = false
		camera.fov = lerp(camera.fov, base_fov, delta * 5.0)
	
	if Input.is_action_pressed("sprint") and not aiming:
		SPEED = sprint_speed
		sprinting = true
	elif aiming:
		SPEED = ads_speed
		sprinting = false
	else:
		SPEED = 10.0
		sprinting = false
	
	dash()

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	
	# Handle jump.
	if Input.is_action_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = lerp(velocity.x, direction.x * SPEED, delta * 10.0)
			velocity.z = lerp(velocity.z, direction.z * SPEED, delta * 10.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * SPEED, delta * 7.0)
		velocity.z = lerp(velocity.z, direction.z * SPEED, delta * 7.0)
	
	if rifle_player.current_animation == "Rig|AK_Reload":
		pass
	elif rifle_player.current_animation == "Rig|AK_Shot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		rifle_player.play("Rig|AK_Walk")
	else:
		rifle_player.play("Rig|AK_Idle")
	
	
	if sprinting:
		var velocity_clamped = clamp(velocity.length(), 0.5, sprint_speed * 2)
		var target_fov = base_fov + fov_change * velocity_clamped
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	else:
		camera.fov = lerp(camera.fov, 75.0, delta * 8.0)

	move_and_slide()
	update_username.rpc()
	update_color.rpc(color)

func is_dead():
	return dead

@rpc("call_local")
func play_shoot_effects():
	rifle_player.stop()
	rifle_player.play("Rig|AK_Shot")
	muzzel_flash.restart()
	muzzel_flash.emitting = true
	ammo -= 1
	ammo = max(ammo, 0)
	ammo_changed.emit(ammo)

@rpc("call_local")
func play_reload_effects():
	muzzel_flash.emitting = false
	rifle_player.stop()
	rifle_player.play("Rig|AK_Reload")
	if current_weapon == "rifle":
		rifle_ammo = 30
		ammo = rifle_ammo
	else:
		pistol_ammo = 8
		ammo = pistol_ammo
	ammo_changed.emit(ammo)

func change_name(username):
	name = username

@rpc("call_local")
func update_username():
	var name = get_name()
	if name == str(1):
		username_label.text = "Clearcash"
	else:
		username_label.text = name

@rpc("any_peer")
func receive_damage():
	health -= 10
	if health <= 0:
		health = 100
		position = Vector3.ZERO
		if current_weapon == "rifle":
			rifle_ammo = 30
			ammo = rifle_ammo
		else:
			pistol_ammo = 8
			ammo = pistol_ammo
	ammo_changed.emit(ammo)
	health_changed.emit(health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "Rig|AK_Shoot":
		rifle_player.play("Rig|AK_Idle")

func update_sens(sens):
	MOUSE_SENS = sens / 10000

func change_color(cooler):
	color = cooler

@rpc("call_local")
func update_color(color):
	var new_material = StandardMaterial3D.new()
	new_material.albedo_color = color
	mesh.material_override = new_material

func pause(state):
	paused = state

func _on_dash_cooldown_timeout():
	can_dash = true


func _on_death_timer_timeout():
	dead = false
