extends Node2D

var range_of_movement := Array()

var clickable = true setget set_clickable

var active_piece

var player_colors setget set_player_colors

var is_multiplayer
var is_server
var is_client

signal promotion_done

var promotion_tiles
var current_color

onready var Board = $ChessEngine
onready var tilemap = $TileMap

onready var chess_type = get_node('/root/PlayersData').chess_type

func _ready():
	var game_type_node

	if get_tree().has_network_peer():
		game_type_node = $"../Multiplayer"
		is_multiplayer = true
		
		if get_tree().is_network_server():
			is_server = true
		else:
			is_client = true
			
	else:
		game_type_node = $"../Singleplayer"
	
	handle_player_colors()
	game_type_node.prepare_game()

# warning-ignore:return_value_discarded
	$'../Game/HUD/EndGame/TryAgain'.connect('pressed', game_type_node, '_on_TryAgain_pressed')
# warning-ignore:return_value_discarded
	$'../Game/HUD/EndGame/Exit'.connect('pressed', game_type_node, '_on_Exit_pressed')
	
	for button in $HUD/PromotionBox.get_children():
		button.connect('pressed', self, '_on_Promotion_pressed', [button.text])
	
func handle_player_colors():
	if is_multiplayer:
		if is_server:
			self.player_colors = [get_node('/root/PlayersData').master_color]
		else:
			self.player_colors = [get_node('/root/PlayersData').puppet_color]
	else:	
		self.player_colors = ['white', 'black']

func prepare_game():
	Board.set_board(chess_type)
	
	tilemap.tile_colors = Board.get_tile_colors()
	
	tilemap.place_pieces()
	tilemap.draw_map()
	
	$"../Notation".map_tiles()
	
	promotion_tiles = Board.get_promotion_tiles()
	current_color = Board.get_current_color()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and clickable and current_color in player_colors:
			var clicked_cell = tilemap.world_to_map(get_global_mouse_position())
			
			if clicked_cell in range_of_movement:
				range_of_movement = []
				
				var promotion
				
				if check_for_promotion(clicked_cell):
					promotion = yield(self, "promotion_done")

				make_move(clicked_cell, promotion)
				
			else:
				set_possible_moves(clicked_cell)

func make_move(new_position, promotion, piece = active_piece):
	if not is_client:
		Board.make_move(piece.tile_position, new_position, promotion)
		update_game(new_position, promotion, piece)

	if is_server:
		tilemap.rpc('place_pieces', Board.get_current_position())
		tilemap.rpc('draw_map')

		rset('current_color', current_color)
		
	if is_client:
		rpc('make_move', new_position, promotion, active_piece)
	
	if not is_multiplayer:
		set_rewind_buttons()
		
		if current_color in $AI_utils.get_computer_colors():
			$AI_utils.start_computer_move()
	
func update_game(new_position, promotion, piece):
	$"../Notation".current_move = $"../Notation".Move.new(
		piece, new_position, promotion, Board.is_captured())
	$"../Notation".check_ambiguity()
	
	current_color = Board.get_current_color()
	
	check_for_game_over()
	
	handle_notation()
	
	tilemap.place_pieces()
	tilemap.draw_map()

func _on_Promotion_pressed(piece):
	self.clickable = true
	$HUD/PromotionBox.visible = false
		
	emit_signal("promotion_done", piece)

func check_for_promotion(clicked_cell):
	if 'Pawn' == active_piece.ctype and clicked_cell in promotion_tiles[current_color]:
		$HUD/PromotionBox.visible = true
		$HUD/PromotionBox/Queen.grab_focus()
		self.clickable = false
		return true
	else:
		return false

func check_for_game_over():
	var game_over = Board.check_for_game_over()
	
	if game_over:
		if game_over == 'Draw':
			game_over('it is a draw', 'draw')
			
		elif game_over == 'Checkmate':
			$"../Notation".current_move.checkmated = true
			game_over(current_color + ' is checkmated', current_color)
			
		elif game_over == 'Stalemate':
			game_over(current_color + ' is stalemated', 'draw')
				
func set_possible_moves(clicked_cell):
	if not is_client:
		var piece = Board.check_tile_for_chessman(clicked_cell)
		
		if piece:
			tilemap.draw_map()
			active_piece = piece
			
			range_of_movement = Board.find_possible_moves(active_piece.tile_position)
			tilemap.draw_possible_moves()
			
	else:
		$"../Multiplayer".rpc('set_possible_moves_server', clicked_cell)

func handle_notation():
	var notation_output = $"../NotationOutput"
	var turn_index = Board.get_current_turn_index() - 1
	
	if not is_multiplayer:
		notation_output.adjust_notation()
		notation_output.update_notation(turn_index)
		notation_output.highlight_current_move(turn_index)

	elif is_server:
		notation_output.update_notation(turn_index)
		notation_output.rpc("update_notation", turn_index, $"../Notation".notate())
	
	else:
		rpc("handle_notation")

func set_clickable(value):
	clickable = value
	$HUD/NotationPanel/SaveLoad.visible = clickable
	
	if is_multiplayer:
		$HUD/MenuBox.visible = clickable
	else:
		$HUD/RewindBox.visible = clickable
		$HUD/BackPanel.visible = clickable

func set_player_colors(value):
	player_colors = value
	
	if value == ['black']: tilemap.reverse = true
	
func set_rewind_buttons():
	$"../Singleplayer".set_Undo_button()
	$"../Singleplayer".set_Redo_button()
	
func game_over(message, result = null):
	self.clickable = false
	$"../NotationOutput".game_result = result
	$HUD/Announcement/Announcement.text = message
	$HUD/Announcement.visible = true
	$HUD/EndGame.visible = true
	
	if is_server:
		rpc('game_over', message, result)
