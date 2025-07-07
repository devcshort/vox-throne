extends Node3D

@onready var player = $Player
@onready var terrain = $VoxelTerrain
@onready var blackout = $UI/Blackout

func _ready():
	$UI/Blackout.visible = true
	
	# Freeze player
	player.freeze_movement = true
	player.visible = false
	blackout.visible = true

	await get_tree().process_frame
	await get_tree().process_frame  # Give terrain time to generate

	position_player_on_ground()

	player.freeze_movement = false
	player.visible = true
	blackout.visible = false
	
	
func position_player_on_ground():
	var from = Vector3(0, 50, 0)
	var to = from + Vector3.DOWN * 100

	var space = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.exclude = [player]  # Optional

	var result = space.intersect_ray(query)

	if result:
		player.global_position = result.position + Vector3.UP * 1.0
	else:
		print("Warning: No ground detected under spawn point.")
