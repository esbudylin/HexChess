extends Node2D

var range_of_movement = Array()

var clickable = true setget set_clickable

var active_piece

var player_colors

var game_type_node

var is_multiplayer
var is_server

signal promotion_done

onready var Board = $TileMap

func _ready():
	if get_tree().has_network_peer():
		game_type_node = $"../Multiplayer"
		is_multiplayer = true
		
		if get_tree().is_network_server():
			is_server = true
			
	else:
		game_type_node = $"../Singleplayer"
	
	set_player_colors()
	game_type_node.prepare_game()
	
# warning-ignore:return_value_discarded
	$'../Game/HUD/EndGame/TryAgain'.connect('pressed', game_type_node, '_on_TryAgain_pressed')
# warning-ignore:return_value_discarded
	$'../Game/HUD/EndGame/Exit'.connect('pressed', game_type_node, '_on_Exit_pressed')
	
	for button in $HUD/PromotionBox.get_children():
		button.connect('pressed', self, '_on_Promotion_pressed', [button.text])

func set_player_colors():
	if is_multiplayer:
		if is_server:
			player_colors = [get_node('/root/PlayersData').master_color]
		else:
			player_colors = [get_node('/root/PlayersData').puppet_color]
	else:	
		player_colors = get_node('/root/PlayersData').colors
	
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and clickable and Board.turn in player_colors:
			var clicked_cell = Board.world_to_map(get_global_mouse_position())
			
			if clicked_cell in range_of_movement:
				range_of_movement = []
					
				player_turn(clicked_cell)
				
				var promotion_piece
				if 'Pawn' == active_piece.type and clicked_cell in Board.promotion_tiles:
					$HUD/PromotionBox.visible = true
					$HUD/PromotionBox/Queen.grab_focus()
					self.clickable = false
					promotion_piece = yield(self, "promotion_done")
					
				change_turns()
				
				if is_multiplayer:
					game_type_node.sync_multiplayer(clicked_cell)
					
					if promotion_piece:
						game_type_node.rpc("sync_promotion", promotion_piece)
				
				check_for_game_over()
				
				handle_notation()
				Board.update_fifty_moves_counter()
				
			elif clicked_cell in Board.chessmen_coords:
				var piece = Board.chessmen_coords[clicked_cell]
				if piece.tile_position == clicked_cell and piece.color == Board.turn:
					Board.draw_map()
					active_piece = piece
					set_possible_moves()

func player_turn(clicked_cell, sync_mult = false):
	if sync_mult:
		active_piece = get_node(game_type_node.active_piece_path)
	
	$"../Notation".current_move = $"../Notation".Move.new(active_piece, clicked_cell)
	
	var capture = Board.capture_on_position(active_piece, clicked_cell)
	
	if capture.captured:
		$"../Notation".current_move.capture = true
		
	if is_server and capture.en_passant:
		var dead_npc_path = str(Board.jumped_over_tiles[clicked_cell].get_path())
		game_type_node.rpc("sync_kill_piece", dead_npc_path)
	
	if not is_multiplayer or is_server:
		$"../Notation".check_ambiguity()
		
	Board.move_piece(active_piece, clicked_cell)
	Board.draw_map()
	Board.update_jumped_over_tiles(active_piece)
	
func _on_Promotion_pressed(piece):
	promote_pawn(piece)
	self.clickable = true
	$HUD/PromotionBox.visible = false
		
	emit_signal("promotion_done", piece)

func promote_pawn(promotion):
	$"../Notation".current_move.promotion = promotion
	Board.promote_pawn(active_piece, promotion)

func check_for_game_over():
	var checkmate_stalemate = Board.check_checkmate_stalemate(active_piece)
	
	if checkmate_stalemate:
		var message = Board.turn + ' is ' + checkmate_stalemate
		
		if checkmate_stalemate == 'checkmated':
			game_over(message, Board.turn)
			$"../Notation".current_move.checkmated = true
		else:
			game_over(message, 'draw')
	
	elif not Board.if_able_to_checkmate('white') and not Board.if_able_to_checkmate('black')\
	or Board.check_fifty_moves_counter() or threefold_rule():
		game_over('it is a draw', 'draw')

func threefold_rule():
	if not is_multiplayer or is_server:
		Board.threefold_rule()
	
	else:
		rpc('threefold_rule')

func change_turns():
	if is_multiplayer:
		game_type_node.change_turns()
	else:
		Board.swap_turn()
		Board.update_turn()
		game_type_node.set_Undo_button()
		game_type_node.set_Redo_button()

func set_possible_moves():
	if is_multiplayer:
		game_type_node.set_possible_moves(str(active_piece.get_path()))
			
	else:
		range_of_movement = Board.check_possible_moves(active_piece)
		draw_possible_moves()

func handle_notation():
	var notation_output = $"../NotationOutput"
	
	if not is_multiplayer:
		notation_output.adjust_notation()
		notation_output.update_notation(Board.current_turn_index-1)
		notation_output.highlight_current_move(Board.current_turn_index-1)

	elif is_server:
		notation_output.update_notation(Board.current_turn_index-1)
		notation_output.rpc("update_notation", Board.current_turn_index-1, $"../Notation".notate())
	
	else:
		rpc("handle_notation")
	
	if notation_output.game_result != '*': notation_output.display_game_result()

func set_clickable(value):
	clickable = value
	$HUD/NotationPanel/SaveLoad.visible = clickable
	
	if is_multiplayer:
		$HUD/MenuBox.visible = clickable
	else:
		$HUD/RewindBox.visible = clickable
		$HUD/BackPanel.visible = clickable
		
func draw_possible_moves():
	Board.set_cells(range_of_movement, 4)

func game_over(message, result = null, double_call = false):
	self.clickable = false
	$"../NotationOutput".game_result = result
	$HUD/Announcement/Announcement.text = message
	$HUD/Announcement.visible = true
	$HUD/EndGame.visible = true
	
	if is_multiplayer and not double_call:
		rpc('game_over', message, result, true)
