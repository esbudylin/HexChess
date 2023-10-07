extends Node

onready var LoadFile = preload("res://src/LoadFile.cs")
onready var LoadGame = preload("res://src/LoadGame.cs")

onready var Game = $'../Game'
onready var Notation = $'../Notation'

onready var board_scr = preload("res://hex_chess.gdns")

func load_game(save_path):
	var loaded_file = LoadFile.new(save_path)
	var loaded_game
	
	if loaded_file.GamesAmount == -1:
		loading_error('Invalid file format')
		return
		
	else: 
		loaded_game = LoadGame.new(loaded_file, 0)
		#todo: add GUI for choosing a game record if a file includes more than one
			
	if loaded_game.Variant:
		Game.chess_type = loaded_game.Variant
	else:
		loading_error('Unknown game variant')
		return
	
	var board = board_scr.new()
	
	board.set_board(Game.chess_type, get_node('/root/Config').get_chessmen_values())
	
	if load_turns(loaded_game.movesData, board):
		swap_boards(board)
		
		set_notation(loaded_game.GameNotation)
		
		if loaded_game.Result != '*':
			$'../NotationOutput'.display_game_result(loaded_game.Result)
			
		$'../NotationOutput'.highlight_current_move(board.get_current_turn_index()-1)
				
		$'../Singleplayer'.set_Undo_button()
		$'../Singleplayer'.set_Redo_button()
			
func load_turns(moves_data, board):
	for move in moves_data:
		var piece_type = move[0]
		var target_tile = move[3]
		var promotion
		
		if move[4]: promotion = move[4]
		else: promotion = null
		
		var move_made

		for piece in board.get_current_position():
			
			if piece_type == piece.chessman and board.get_current_color() == piece.color and\
			check_origin_square(Notation.coords_to_notation[piece.coords], move[1], move[2]) and\
			Notation.notation_to_coords[target_tile] in board.find_possible_moves(piece.coords):
				
				board.make_move(piece.coords, Notation.notation_to_coords[target_tile], promotion)
				move_made = true
				break
		
		if not move_made:
			loading_error('Illegal move detected')
			return false
			
	return true
	
func check_origin_square(origin_position, file, rank):
	return (not file or file.to_lower() == origin_position[0])\
	and (not rank or rank == origin_position.right(1))

func loading_error(message):
	var errormessage = Game.get_node('HUD/LoadError')
	errormessage.popup()
	errormessage.dialog_text = message

func set_notation(game_notation):
	$'../NotationOutput'.clean_output()
	
	var i = 0
	for half_turn in game_notation:
		$'../NotationOutput'.game_notation[i] = half_turn
		$'../NotationOutput'.update_notation(i, half_turn)
		i+=1

func swap_boards(board):
	var old_board = Game.Board
	old_board.queue_free()
		
	Game.add_child(board)
	Game.Board = board
	Game.promotion_tiles = board.get_promotion_tiles()
	Game.range_of_movement = []
	
	Game.tilemap.draw_map()
	Game.tilemap.place_pieces()

func _on_LoadGame_pressed():
	var filedialog = Game.get_node('HUD/FileDialog')
	filedialog.popup()
	
	var dir = Directory.new()
	var path = OS.get_executable_path().get_base_dir().plus_file("saves")
	
	if dir.dir_exists(path):
		filedialog.set_current_dir(path)
		
	filedialog.set_filters(PoolStringArray(["*.pgn ; Portable Game Notation"]))

func _on_FileDialog_file_selected(path):
	load_game(path)
