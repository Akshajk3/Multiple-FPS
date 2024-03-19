extends Node3D

@export var ADS_SPEED = 20

@export var default_position : Vector3
@export var ads_position : Vector3

# Called when the node enters the scene tree for the first time.
func _ready():
	transform.origin = default_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_pressed("ads"):
		transform.origin = transform.origin.lerp(ads_position, ADS_SPEED * delta)
	else:
		transform.origin = transform.origin.lerp(default_position, ADS_SPEED * delta)
