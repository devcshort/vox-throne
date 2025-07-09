extends Node

const PlayerScene = preload("res://scenes/player/player.tscn")

const NETWORK_MODE_SINGLEPLAYER = 0
const NETWORK_MODE_CLIENT = 1
const NETWORK_MODE_HOST = 2

const SERVER_PEER_ID = 1

@onready var _terrain : VoxelTerrain = $VoxelTerrain
@onready var _characters_container : Node = $Players

var _network_mode := NETWORK_MODE_SINGLEPLAYER
var _ip := ""
var _port := -1

func get_terrain() -> VoxelTerrain:
	return _terrain

func get_network_mode() -> int:
	return _network_mode

func set_network_mode(mode: int):
	_network_mode = mode

func set_ip(ip: String):
	_ip = ip

func set_port(port: int):
	_port = port

func _ready():
	if _network_mode == NETWORK_MODE_HOST:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(_port, 32, 0, 0, 0)
		if err != OK:
			push_error(str("Failed to create server peer, error: ", err))
		var mp := get_tree().get_multiplayer()
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
		mp.multiplayer_peer = peer
		
		var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
		_terrain.add_child(synchronizer)
	elif _network_mode == NETWORK_MODE_CLIENT:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(_ip, _port, 0, 0, 0, 0)
		if err != OK:
			push_error(str("Failed to create server peer, error: ", err))
		var mp := get_tree().get_multiplayer()
		mp.connected_to_server.connect(_on_connected_to_server)
		mp.connection_failed.connect(_on_connection_failed)
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
		mp.server_disconnected.connect(_on_server_disconnected)
		mp.multiplayer_peer = peer
		
		var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
		_terrain.add_child(synchronizer)
		_terrain.stream = null
	if _network_mode == NETWORK_MODE_HOST or _network_mode == NETWORK_MODE_SINGLEPLAYER:
		_spawn_character(SERVER_PEER_ID, Vector3(0, 64, 0))
	
func _on_peer_connected(new_peer_id: int):
	if _network_mode == NETWORK_MODE_HOST:
		var new_character =_spawn_character(new_peer_id, Vector3(0, 64, 0))
		print(str("Sending own character to ", new_peer_id))
		rpc_id(new_peer_id, &"receive_own_character", new_peer_id, new_character.position)
		
		# Send existing characters to the new peer
		for i in _characters_container.get_child_count():
			var character := _characters_container.get_child(i)
			if character != new_character:
				# TODO This sucks, find a better way to get peer ID from character
				var peer_id := character.name.to_int()
				print(str("Sending remote character ", peer_id, " to ", new_peer_id))
				rpc_id(new_peer_id, &"receive_remote_character", peer_id, character.position)
		
		# Send new character to other clients
		var peers := get_tree().get_multiplayer().get_peers()
		for peer_id in peers:
			if peer_id != new_peer_id:
				print(str("Sending remote character ", peer_id, " to other ", new_peer_id))
				rpc_id(peer_id, &"receive_remote_character", new_peer_id, new_character.position)

func _on_peer_disconnected(peer_id: int):
	print(str("Peer ", peer_id, " disconnected"))
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		var character = _characters_container.get_node(node_name)
		character.queue_free()
	else:
		print(str("Character ", peer_id, " not found"))
	
func _on_connected_to_server():
	print("Connected to server")
	
func _on_connection_failed():
	print("Connection failed")

func _on_server_disconnected():
	print("Server disconnected")

func _spawn_character(peer_id: int, pos: Vector3) -> Node3D:
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		push_error(str("Character ", peer_id, " already created"))
		return null

	var character : Node3D = PlayerScene.instantiate()
	character.name = node_name
	character.position = pos
	character.terrain = get_terrain().get_path()
	
	if _network_mode == NETWORK_MODE_HOST:
		var voxel_viewer := VoxelViewer.new()
		voxel_viewer.requires_data_block_notifications = true
		voxel_viewer.requires_visuals = false
		voxel_viewer.requires_collisions = false
		voxel_viewer.set_network_peer_id(peer_id)
		voxel_viewer.requires_data_block_notifications = true
		
		character.set_multiplayer_authority(peer_id)
		character.add_child(voxel_viewer)

	if multiplayer.get_unique_id() == peer_id:
		character.set_multiplayer_authority(peer_id)
	
	_characters_container.add_child(character)
	return character

@rpc("authority", "call_remote", "reliable", 0)
func receive_remote_character(peer_id: int, pos: Vector3):
	print(str("receive_remote_character ", peer_id, " at ", pos))
	_spawn_character(peer_id, pos)

@rpc("authority", "call_remote", "reliable", 0)
func receive_own_character(peer_id: int, pos: Vector3):
	print(str("receive_own_character ", peer_id, " at ", pos))
	_spawn_character(peer_id, pos)
