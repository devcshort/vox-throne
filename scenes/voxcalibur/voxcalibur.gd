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
	_spawn_character(new_peer_id, Vector3(0, 64, 0))

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
	
	var voxel_viewer := VoxelViewer.new()
	voxel_viewer.set_network_peer_id(peer_id)
	voxel_viewer.requires_data_block_notifications = true
	voxel_viewer.requires_visuals = false
	character.add_child(voxel_viewer, true)
	
	_characters_container.add_child(character)
	return character
