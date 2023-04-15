extends Node

var Game

func copy_board(board):
	board.visible = false
	add_child(board)
	
	board.place_pieces()
	board.append_turn_history()

func make_turn(board, piece, new_position, promotion = null):
	if new_position in board.chessmen_coords:
		board.kill_piece(board.chessmen_coords[new_position])
				
	elif 'Pawn' == piece.type and new_position in board.jumped_over_tiles\
	and new_position in board.pawn_attack(piece, piece.tile_position, false):
		board.kill_piece(board.jumped_over_tiles[new_position])
		
	board.move_piece(piece, new_position)
	board.update_jumped_over_tiles(piece)
	
	if promotion:
		board.promote_pawn(piece, promotion)
		
	board.swap_turn()
	board.update_turn()

func swap_boards(board):
	board.visible = true
	
	var old_board = Game.Board
	old_board.queue_free()
	
	remove_child(board)
	Game.add_child(board)
	Game.Board = board
	Game.range_of_movement = []
