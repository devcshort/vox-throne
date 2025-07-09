extends CharacterBody3D

const Util = preload("res://common/util.gd")
const COLLISION_LAYER_AVATAR = 2

var freeze_movement: bool = true

@export var move_speed := 5.0
@export var jump_velocity := 6.0
@export var gravity := 20.0
@export var mouse_sensitivity := 0.002
@export var cursor_material : Material
@export var max_place_distance := 3.0  # or whatever distance you want
@export var sensitivity := 0.002
@export var max_pitch := deg_to_rad(85)
@export var terrain : NodePath

@onready var camera = $Camera
var _head = null

var _terrain_tool = null
var _cursor = null
var _action_place := false
var _action_remove := false
var _terrain_node: VoxelTerrain

var pitch := 0.0

func _enter_tree() -> void:
	
	
	if multiplayer.is_server():
		set_multiplayer_authority(str(name).to_int())
	
	var voxel_viewer := VoxelViewer.new()
	add_child(voxel_viewer)

func _ready():
	if not is_multiplayer_authority(): return
	
	_head = camera
	camera.current = true
	
	var mesh = Util.create_wirecube_mesh(Color(0,0,0))
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if cursor_material != null:
		mesh_instance.material_override = cursor_material
	mesh_instance.set_scale(Vector3(1,1,1)*1.01)
	_cursor = mesh_instance
	
	if has_node(terrain):
		_terrain_node = get_node(terrain)
		_terrain_node.add_child(_cursor)
		_terrain_tool = _terrain_node.get_voxel_tool()
		
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func get_pointed_voxel() -> VoxelRaycastResult:
	var origin = _head.get_global_transform().origin
	var forward = -_head.get_global_transform().basis.z.normalized()
	var hit = _terrain_tool.raycast(origin, forward, 3)
	return hit

func _unhandled_input(event: InputEvent):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_action_remove = true
				MOUSE_BUTTON_RIGHT:
					_action_place = true
					
	if event is InputEventMouseMotion:
		# Yaw (horizontal)
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Pitch (vertical)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))
		camera.rotation.x = pitch

func _physics_process(delta: float):
	if not is_multiplayer_authority(): return
	
	if _terrain_node == null:
		push_error("No terrain node")
		return
		
	var hit := get_pointed_voxel()
	if hit != null:
		_cursor.show()
		_cursor.set_position(hit.position)
	else:
		_cursor.hide()
	
	if hit != null:
		if _action_place:
			var pos = hit.previous_position
			if can_place_voxel_at(pos):
				place(pos)
		
		elif _action_remove:
			dig(hit.position)

	_action_place = false
	_action_remove = false
	
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

func can_place_voxel_at(pos: Vector3i) -> bool:
	var space_state = get_viewport().get_world_3d().get_direct_space_state()
	var params = PhysicsShapeQueryParameters3D.new()
	params.collision_mask = COLLISION_LAYER_AVATAR
	params.transform = Transform3D(Basis(), Vector3(pos + Vector3i(1,1,1)) * 0.5)
	var shape = BoxShape3D.new()
	var ex = 0.5
	shape.extents = Vector3(ex, ex, ex)
	params.set_shape(shape)
	var hits = space_state.intersect_shape(params)
	return hits.size() == 0

func place(center: Vector3i):
	_terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.value = 1
	_terrain_tool.do_point(center)

func dig(center: Vector3i):
	_terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.value = 0
	_terrain_tool.do_point(center)
