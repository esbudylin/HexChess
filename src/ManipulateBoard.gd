extends Node

var Game

func copy_board(board):
	board.visible = false
	add_child(board)
	
	board.place_pieces()
	board.append_turn_history()

func make_move(board, piece, new_position, promotion = null):
	board.capture_on_position(piece, new_position)
		
	board.move_piece(piece, new_position)
	board.update_jumped_over_tiles(piece)
	
	if promotion:
		board.promote_pawn(piece, promotion)
	
	board.swap_turn()
	board.update_turn()
	
	board.fifty_moves_rule()

func swap_boards(board):
	board.visible = true
	
	var old_board = Game.Board
	old_board.queue_free()
	
	remove_child(board)
	Game.add_child(board)
	Game.Board = board
	Game.range_of_movement = []
