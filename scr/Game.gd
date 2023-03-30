extends Node2D

var range_of_movement = Array()

var turn = "white"
var turn_history = {}
var current_turn_index = 0

var clickable = true

var active_piece

var player_colors

var game_type_node
var is_multiplayer

signal promotion_done

func _ready():
	$TileMap.draw_map()
	$TileMap.visible = true
	
	$Camera2D.set_global_position(Vector2(50, 0))
	
	if get_tree().has_network_peer ():
		game_type_node = $"../Multiplayer"
		is_multiplayer = true
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

func append_turn_history():
	var coord_dictionary = {}
	var jumped_over_copy = {}
	
	for piece in $TileMap.chessmen_list.duplicate():
		coord_dictionary[piece.tile_position]=[piece.type, piece.color]
	
	for tile in $TileMap.jumped_over_tiles:
		jumped_over_copy[tile] = $TileMap.jumped_over_tiles[tile].tile_position
		
	turn_history[current_turn_index] = [turn, coord_dictionary, jumped_over_copy, $TileMap.fifty_moves_counter]

func adjust_turn_history():
	var to_clean = turn_history.keys().slice(current_turn_index+1, -1)
	
	for key in to_clean:
		turn_history.erase(key)

func set_player_colors():
	if is_multiplayer:
		if get_tree().is_network_server():
			player_colors = [get_node('/root/PlayersData').master_color]
		else:
			player_colors = [get_node('/root/PlayersData').puppet_color]
	else:	
		player_colors = get_node('/root/PlayersData').colors
	
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and clickable and turn in player_colors:
			var clicked_cell = $TileMap.world_to_map(get_global_mouse_position())
			
			if clicked_cell in range_of_movement:
				range_of_movement = []
				
				player_turn(clicked_cell)
				
				var promotion_piece
				if 'Pawn' == active_piece.type and clicked_cell in $TileMap.promotion_tiles:
					$HUD/PromotionBox.visible = true
					$HUD/PromotionBox/Queen.grab_focus()
					clickable = false
					$HUD/MenuBox.visible = false
					promotion_piece = yield(self, "promotion_done")
					
				change_turns()
				
				if is_multiplayer:
					game_type_node.sync_multiplayer(clicked_cell)
					
					if promotion_piece:
						game_type_node.rpc("sync_promotion", promotion_piece)
				
				check_for_game_over()
				
			elif clicked_cell in $TileMap.chessmen_coords:
				var piece = $TileMap.chessmen_coords[clicked_cell]
				if piece.tile_position == clicked_cell and piece.color == turn:
					$TileMap.draw_map()
					active_piece = piece
					set_possible_moves()

func player_turn(clicked_cell, sync_mult = false):
	if sync_mult:
		active_piece = get_node(game_type_node.active_piece_path)
		
	if clicked_cell in $TileMap.chessmen_coords:
		$TileMap.kill_piece($TileMap.chessmen_coords[clicked_cell])
				
	elif 'Pawn' == active_piece.type and clicked_cell in $TileMap.jumped_over_tiles\
	and clicked_cell in $TileMap.pawn_attack(active_piece, active_piece.tile_position, false):
		$TileMap.kill_piece($TileMap.jumped_over_tiles[clicked_cell])
		
		if get_tree().is_network_server():
			var dead_npc_path = str($TileMap.jumped_over_tiles[clicked_cell].get_path())
			game_type_node.rpc("sync_kill_piece", dead_npc_path)

	$TileMap.move_piece(active_piece, clicked_cell)
	$TileMap.draw_map()
	$TileMap.update_jumped_over_tiles(active_piece)
	
func _on_Promotion_pressed(piece):
	$TileMap.promote_pawn(active_piece, piece)
	clickable = true
	$HUD/PromotionBox.visible = false
	
	if is_multiplayer:
		$HUD/MenuBox.visible = true
		
	emit_signal("promotion_done", piece)

func check_for_game_over():
	var checkmate_stalemate = $TileMap.check_checkmate_stalemate(turn)
	
	if checkmate_stalemate:
		game_over(turn + ' is ' + checkmate_stalemate)
	
	elif not $TileMap.if_able_to_checkmate('white') and not $TileMap.if_able_to_checkmate('black')\
	or fify_moves_rule() or threefold_rule():
		game_over('it is a draw')

func fify_moves_rule(amount_of_moves = 50):
	if 'Pawn' == active_piece.type:
		$TileMap.fifty_moves_counter = 0
		return false
	
	if turn == 'white':
		if $TileMap.fifty_moves_counter == amount_of_moves:
			return true
		else:
			$TileMap.fifty_moves_counter += 1
			return false

func threefold_rule(amount_of_moves = 3):
	if not get_tree().has_network_peer() or get_tree().is_network_server():
		var repeated_positions = 0
		var breaked
		var breaked_pawns
		
		for turn_step in turn_history.values():
			if turn == turn_step[0]:
				for key in turn_step[1].keys():
					
					breaked = false
					if turn_history[current_turn_index][1].has(key):
						if turn_step[1][key] != turn_history[current_turn_index][1][key]:
							breaked = true
							break
					else:
						breaked = true
						break
				
				if not breaked\
				and turn_step[2].size() == turn_history[current_turn_index][2].size():
					
					breaked_pawns = false
					
					for pawn_attack_tile in turn_step[2]:
						if not pawn_attack_tile in turn_history[current_turn_index][2]:
							breaked_pawns = true
							break
					
					if not breaked_pawns:
						repeated_positions += 1
					
		if repeated_positions >= amount_of_moves:
			return true
	
	else:
		rpc('threefold_rule')

func swap_turn():
	if turn == 'white':
		turn = 'black'
	else:
		turn = 'white'

func update_turn():
	$TileMap.clean_up_jumped_over(turn)
	current_turn_index += 1
	append_turn_history()
	adjust_turn_history()

func change_turns():
	if is_multiplayer:
		game_type_node.change_turns()
	else:
		swap_turn()
		update_turn()
		game_type_node.set_Undo_button()
		game_type_node.set_Redo_button()

func set_possible_moves():
	if is_multiplayer:
		game_type_node.set_possible_moves(str(active_piece.get_path()))
			
	else:
		range_of_movement = $TileMap.check_possible_moves(active_piece)
		draw_possible_moves()
		
func draw_possible_moves():
	$TileMap.set_cells(range_of_movement, 4)

func game_over(message, double_call = false):
	clickable = false
	$HUD/MenuBox.visible = false
	$HUD/RewindBox.visible = false
	$HUD/BackPanel.visible = false
	$HUD/Announcement/Announcement.text = message
	$HUD/Announcement.visible = true
	$HUD/EndGame.visible = true
	
	if is_multiplayer and not double_call:
		rpc('game_over', message, true)
