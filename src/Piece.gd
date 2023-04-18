extends Node2D

var tile_position := Vector2() setget set_position

var color
var type

onready var board = get_parent()

func set_position(value):
	tile_position = value
	
	if board.reverse:
		position = board.map_to_world(board.mirror_tile(value))
	else:
		position = board.map_to_world(value)
