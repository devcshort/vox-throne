extends CharacterBody3D

var freeze_movement: bool = true

@export var move_speed := 5.0
@export var jump_velocity := 6.0
@export var gravity := 20.0
@export var mouse_sensitivity := 0.002

@onready var camera_pivot = $CameraPivot

var pitch := 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		# Yaw (horizontal)
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Pitch (vertical)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))
		camera_pivot.rotation.x = pitch

func _physics_process(delta: float):
	if freeze_movement:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("ui_up"):    # W
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down"):  # S
		input_dir.z += 1
	if Input.is_action_pressed("ui_left"):  # A
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right"): # D
		input_dir.x += 1
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	input_dir = input_dir.normalized()

	# Move relative to the player’s current rotation (yaw only)
	var direction = (transform.basis * input_dir).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Jump
		if Input.is_action_just_pressed("ui_accept"):
			velocity.y = jump_velocity

	move_and_slide()
