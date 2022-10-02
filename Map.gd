extends Node2D

func _ready():
	$TileMap.place_pieces ()
	$TileMap.visible = true
	
	$Camera2D.camera_following($TileMap)
	
func _unhandled_input(event):
				
	if event is InputEventMouseButton:
		if event.pressed:
			var clicked_cell = $TileMap.world_to_map(get_global_mouse_position())
			print (clicked_cell)
			if clicked_cell in $TileMap.npc_coord():
				for piece in $TileMap.npc_list:
					if piece.tile_position == clicked_cell:
						piece.range_of_movement = $TileMap.find_possible_moves(piece, clicked_cell)
						$TileMap.set_cells ($TileMap.coord_tiles, 1)
						$TileMap.set_cells (piece.range_of_movement, 10)
						break
		
func _on_TryAgain_pressed():
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()
