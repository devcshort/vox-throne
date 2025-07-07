extends Node3D

@export var sensitivity := 0.002
@export var max_pitch := deg_to_rad(85)

var pitch := 0.0

func rotate_pitch(mouse_y_delta: float) -> void:
	pitch = clamp(pitch - mouse_y_delta * sensitivity, -max_pitch, max_pitch)
	rotation.x = pitch
