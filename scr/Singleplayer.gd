extends Node

onready var gs = $"../Game"

func prepare_game():
	gs.Board.place_pieces()
	$'../Game/HUD/BackPanel'.visible = true
	$'../Game/HUD/RewindBox'.visible = true
	
# warning-ignore:return_value_discarded
	$'../Game/HUD/RewindBox/Undo'.connect('pressed', self, '_on_Rewind_pressed', [-1])
# warning-ignore:return_value_discarded
	$'../Game/HUD/RewindBox/Redo'.connect('pressed', self, '_on_Rewind_pressed', [1])
		
	gs.Board.append_turn_history()

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
	rewind_game(gs.Board.current_turn_index + index)

func rewind_game(turn_index):
	gs.Board.current_turn_index = turn_index	
	gs.range_of_movement = []
	
	for piece in gs.Board.chessmen_list.duplicate():
		gs.Board.kill_piece(piece, false)
		
	var turn_data = gs.Board.turn_history[gs.Board.current_turn_index]
	
	gs.Board.turn = turn_data[0]
	
	for tile in turn_data[1]:
		var piece_copy = gs.Board.get_node('Piece/'+turn_data[1][tile][0]).duplicate()
		gs.Board.add_piece(piece_copy, tile, turn_data[1][tile][0], turn_data[1][tile][1])	
	
	gs.Board.jumped_over_tiles = {}
	
	for tile in turn_data[2]:
		gs.Board.jumped_over_tiles[tile]=gs.Board.chessmen_coords[turn_data[2][tile]]
	
	gs.Board.fifty_moves_counter = turn_data[3]

	gs.Board.draw_map()
	
	set_Redo_button()
	set_Undo_button()
	
	$'../NotationOutput'.highlight_current_move(turn_index-1)
	
func set_Undo_button():
	if gs.Board.current_turn_index!=0:
		$'../Game/HUD/RewindBox/Undo'.set_disabled(false)
	else:
		$'../Game/HUD/RewindBox/Undo'.set_disabled(true)

func set_Redo_button():
	if gs.Board.current_turn_index!=gs.Board.turn_history.size()-1:
		$'../Game/HUD/RewindBox/Redo'.set_disabled(false)
	else:
		$'../Game/HUD/RewindBox/Redo'.set_disabled(true)
