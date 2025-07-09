extends Node3D

const Voxcalibur = preload("res://scenes/voxcalibur/voxcalibur.gd")
const VoxcaliburScene = preload("res://scenes/voxcalibur/voxcalibur.tscn")
const Player = preload("res://scenes/player/player.tscn")

@onready var _main_menu = $MainMenu
@onready var _ui = $UI
@onready var _single_player_button = $MainMenu/PanelContainer/MarginContainer/VBoxContainer/StartSinglePlayer
@onready var _host_game_button = $MainMenu/PanelContainer/MarginContainer/VBoxContainer/HostGame
@onready var _join_game_button = $MainMenu/PanelContainer/MarginContainer/VBoxContainer/JoinGame

@export var port: int = 8090

var _game: Voxcalibur

func set_viewport_name(new_name: String) -> void:
	get_viewport().get_window().title = str("Voxcalibur ", new_name)

func _ready() -> void:
	_ui.hide()
	
	_single_player_button.pressed.connect(_on_single_player_button_pressed)
	_host_game_button.pressed.connect(_on_host_game_button_pressed)
	_join_game_button.pressed.connect(_on_join_game_button_pressed)

func _on_single_player_button_pressed() -> void:
	_game = VoxcaliburScene.instantiate()
	_game.set_network_mode(Voxcalibur.NETWORK_MODE_SINGLEPLAYER)
	add_child(_game)

	_main_menu.hide()
	_ui.show()
	
func _on_host_game_button_pressed() -> void:
	_game = VoxcaliburScene.instantiate()
	_game.set_port(port)
	_game.set_network_mode(Voxcalibur.NETWORK_MODE_HOST)
	add_child(_game)

	_main_menu.hide()
	_ui.show()
	set_viewport_name("Server")

func _on_join_game_button_pressed() -> void:
	_game = VoxcaliburScene.instantiate()
	_game.set_ip("127.0.0.1")
	_game.set_port(port)
	_game.set_network_mode(Voxcalibur.NETWORK_MODE_CLIENT)
	add_child(_game)

	_main_menu.hide()
	_ui.show()
	set_viewport_name("Client")
