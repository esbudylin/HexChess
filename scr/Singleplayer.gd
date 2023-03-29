extends Node

onready var gs = $"../Game"
onready var tilemap = $"../Game/TileMap"

func prepare_game():
	tilemap.place_pieces()
	$'../Game/HUD/BackPanel'.visible = true
	$'../Game/HUD/RewindBox'.visible = true
	
# warning-ignore:return_value_discarded
	$'../Game/HUD/RewindBox/Undo'.connect('pressed', self, '_on_Rewind_pressed', [-1])
# warning-ignore:return_value_discarded
	$'../Game/HUD/RewindBox/Redo'.connect('pressed', self, '_on_Rewind_pressed', [1])
		
	gs.append_turn_history()

func _on_TryAgain_pressed():
# warning-ignore:return_value_discarded	
	get_tree().reload_current_scene()

func _on_Exit_pressed():
# warning-ignore:return_value_discarded	
	get_tree().change_scene("res://scenes/menu.tscn")
	
func _on_BackPanel_pressed():
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://scenes/menu.tscn")

func _on_Rewind_pressed(index):
	gs.current_turn_index +=index
	gs.range_of_movement = []
	
	for piece in tilemap.chessmen_list.duplicate():
		piece.visible = false
		tilemap.chessmen_list.erase(piece)
		tilemap.chessmen_coords.erase(piece.tile_position)
		
	var turn_data = gs.turn_history[gs.current_turn_index]
	
	gs.turn = turn_data[0]
	
	for tile in turn_data[1]:
		var piece_copy = get_parent().get_node('Game/TileMap/Piece/'+turn_data[1][tile][0]).duplicate()
		tilemap.add_piece(piece_copy, tile, turn_data[1][tile][0], turn_data[1][tile][1])	
	
	tilemap.jumped_over_tiles = {}
	
	for tile in turn_data[2]:
		tilemap.jumped_over_tiles[tile]=tilemap.chessmen_coords[turn_data[2][tile]]
	
	tilemap.fifty_moves_counter = turn_data[3]

	tilemap.draw_map()
	
	set_Redo_button()
	set_Undo_button()
	
func set_Undo_button():
	if gs.current_turn_index!=0:
		$'../Game/HUD/RewindBox/Undo'.set_disabled(false)
	else:
		$'../Game/HUD/RewindBox/Undo'.set_disabled(true)

func set_Redo_button():
	if gs.current_turn_index!=gs.turn_history.size()-1:
		$'../Game/HUD/RewindBox/Redo'.set_disabled(false)
	else:
		$'../Game/HUD/RewindBox/Redo'.set_disabled(true)
