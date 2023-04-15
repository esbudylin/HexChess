extends "res://src/ManipulateBoard.gd"

onready var LoadFile = preload("res://src/LoadFile.cs")
onready var LoadGame = preload("res://src/LoadGame.cs")

onready var Board = $'../Game/TileMap'.duplicate()

onready var coords_to_notation = $'../Notation'.mapped_tiles
onready var notation_to_coords = swap_dictionary(coords_to_notation)

func _ready():
	Game = $'../Game'

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
		get_node('/root/PlayersData').chess_type = loaded_game.Variant
	else:
		loading_error('Unknown game variant')
		return
			
	var board = Board.duplicate()
	
	copy_board(board)
	
	if load_turns(loaded_game.movesData, board):
		swap_boards(board)
		
		set_notation(loaded_game.GameNotation)
		$'../NotationOutput'.highlight_current_move(board.current_turn_index-1)
				
		$'../Singleplayer'.set_Undo_button()
		$'../Singleplayer'.set_Redo_button()
			
func load_turns(moves_data, board):
	for move in moves_data:
		var piece_type = move[0]
		var target_square = move[3]
		var promotion = move[4]
		
		var move_made

		for piece in board.chessmen_by_color_by_type[board.turn][piece_type]:
			if check_origin_square(coords_to_notation[piece.tile_position], move[1], move[2]) and\
			notation_to_coords[target_square] in board.check_possible_moves(piece):
				make_move(board, piece, notation_to_coords[target_square], promotion)
				move_made = true
				break
		
		if not move_made:
			board.queue_free()
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
		
func swap_dictionary(dict):
	var new_dict = Dictionary()
	for key in dict: new_dict[dict[key]] = key
	return new_dict

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
