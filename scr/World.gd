extends Node2D

var range_of_movement = Array()

var turn = "white"
var turn_history = {}
var current_turn_index = 0

var clickable = true

var player_colors

var active_piece
var active_piece_path

var new_game_request

onready var peer = get_node('/root/PlayersData').peer

func _ready():
	$TileMap.draw_map ()
	$TileMap.visible = true
	
	$Camera2D.camera_following($TileMap)
	
	for button in $HUD/PromotionBox.get_children ():
		button.connect ('pressed', self, '_on_Promotion_pressed', [button.text])
	
# warning-ignore:return_value_discarded
	$HUD/RewindBox/Undo.connect ('pressed', self, '_on_Rewind_pressed', [-1])
# warning-ignore:return_value_discarded
	$HUD/RewindBox/Redo.connect ('pressed', self, '_on_Rewind_pressed', [1])
	
	get_player_colors()
	multiplayer_configs ()
	announcement ('you will play as ' + player_colors[0])
	
# warning-ignore:return_value_discarded
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
# warning-ignore:return_value_discarded
	get_tree().connect("server_disconnected", self, "announcement", ["opponent disconnected"])
	
	if get_tree().has_network_peer ():
		$HUD/MenuBox.visible = true
		
		if get_tree().is_network_server():
			server_place_pieces()
			append_turn_history()
		
	else:
		$TileMap.place_pieces ()
		$HUD/BackPanel.visible = true
		$HUD/RewindBox.visible = true
		append_turn_history()
		
func _player_disconnected(_id):
	announcement ("opponent disconnected")
	$HUD/EndGame/TryAgain.set_disabled(true)
	
func _unhandled_input(event):
	
	if event is InputEventMouseButton:
		if event.pressed and clickable and turn in player_colors:
			var clicked_cell = $TileMap.world_to_map(get_global_mouse_position())
			
			if clicked_cell in range_of_movement:
				range_of_movement = []
				
				player_turn (clicked_cell)
				
				if 'Pawn' in active_piece.name and clicked_cell in $TileMap.promotion_tiles:
					$HUD/PromotionBox.visible = true
					$HUD/PromotionBox/Queen.grab_focus()
					clickable = false
					$HUD/MenuBox.visible = false
					
				change_turns()
				
				if $TileMap.check_checkmate_stalemate(turn):
					game_over(turn + ' is ' + $TileMap.check_checkmate_stalemate(turn))
					
					if get_tree().has_network_peer ():
						rpc ('game_over', turn + ' is ' + $TileMap.check_checkmate_stalemate(turn))
				
				if not $TileMap.if_able_to_checkmate('white') and not $TileMap.if_able_to_checkmate('black')\
				or fify_moves_rule() or threefold_rule ():
					game_over('it is a draw')
					
					if get_tree().has_network_peer ():
						rpc ('game_over', 'it is  a draw')
				
				sync_multiplayer(clicked_cell)
				
			elif clicked_cell in $TileMap.npc_coord():
				var piece = $TileMap.npc_coord()[clicked_cell]
				if piece.tile_position == clicked_cell and piece.color == turn:
					$TileMap.draw_map ()
					active_piece = piece
					set_possible_moves (str(active_piece.get_path()), clicked_cell)
						
func _on_TryAgain_pressed():
	if get_tree().has_network_peer ():
		if new_game_request:
			if get_tree().is_network_server():
				rpc ('reload_client')

			elif not get_tree().is_network_server():
				rpc ('reload_scene')
				reload_scene()

		else:
			$HUD/Announcement/Announcement.text = 'request sent'
			rset ('new_game_request', true)
	else:
# warning-ignore:return_value_discarded
		get_tree().reload_current_scene()
	
func _on_Exit_pressed():
	end_game()

func _on_Surrender_pressed():
	game_over(player_colors[0] + ' surrender')
	rpc ('game_over', player_colors[0] + ' surrender')

func _on_Draw_pressed():
	clickable = false
	$HUD/MenuBox.visible = false
	rpc ('draw_offer')

func _on_Accept_pressed():
	$HUD/DrawOffer.visible = false
	game_over('it is a draw')
	rpc ('game_over', 'it is a draw')

func _on_Decline_pressed():
	$HUD/DrawOffer.visible = false
	$HUD/MenuBox.visible = true
	$HUD/Announcement.visible = false
	clickable = true
	rpc ('announcement', 'offer declined')

func _on_BackPanel_pressed():
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://menu.tscn")

func _on_Rewind_pressed(index):
	current_turn_index +=index
	
	for piece in $TileMap.npc_list.duplicate():
		piece.visible = false
		$TileMap.npc_list.erase(piece)
		
	var turn_data = turn_history[current_turn_index]
	
	turn = turn_data[0]
	
	for tile in turn_data[1]:
		var piece_copy = get_node('TileMap/Piece/'+turn_data[1][tile][0]).duplicate()
		$TileMap.add_piece(piece_copy, tile, turn_data[1][tile][1])	
	
	$TileMap.jumped_over_tiles = {}
	
	for tile in turn_data[2]:
		$TileMap.jumped_over_tiles[tile]=$TileMap.npc_coord()[turn_data[2][tile]]
	
	$TileMap.fifty_moves_counter = turn_data[3]

	$TileMap.draw_map ()
	
	set_Redo_button()
	set_Undo_button()

func _on_Promotion_pressed(piece):
	$TileMap.promote_pawn(active_piece, piece)
	clickable = true
	$HUD/PromotionBox.visible = false
	
	if get_tree().has_network_peer ():
		$HUD/MenuBox.visible = true
		rpc("sync_promotion", piece)

func announcement(text):
	if get_tree().has_network_peer ():
		var timer = Timer.new()
		$HUD/Announcement.visible = true
		$HUD/Announcement/Announcement.text = text
		clickable = false
		timer.connect("timeout",self,"anouncment_hide")
		timer.wait_time = 2
		timer.one_shot = true
		add_child(timer)
		timer.start()

func anouncment_hide ():
	$HUD/Announcement.visible = false
	clickable = true
	
	if $HUD/Announcement/Announcement.text == 'offer declined':
		$HUD/MenuBox.visible = true
	
	if $HUD/Announcement/Announcement.text == 'opponent disconnected':
		get_tree().set_network_peer(null)
# warning-ignore:return_value_discarded
		get_tree().change_scene("res://menu.tscn")
		
func multiplayer_configs ():
	rpc_config("player_turn", 1)
	rpc_config("change_turns", 1)
	rpc_config("set_possible_moves", 1)
	rpc_config("draw_possible_moves", 1)
	rpc_config("sync_npc_die", 1)
	rpc_config("sync_promotion", 1)
	rpc_config("sync_pieces", 1)
	rpc_config("game_over", 1)
	rpc_config("renew_colors", 1)
	rpc_config("draw_offer", 1)
	rpc_config("announcement", 1)
	rpc_config("reload_scene", 1)
	rpc_config("server_place_pieces", 1)
	rpc_config("reload_client", 1)
	rpc_config ('threefold_rule', 1)
	
	rset_config("active_piece_path", 1)
	rset_config("clickable", 1)
	rset_config("range_of_movement", 1)
	rset_config("new_game_request", 1)

func get_player_colors():
	if get_tree().has_network_peer ():
		if get_tree().is_network_server():
			player_colors = [get_node('/root/PlayersData').master_color]
		else:
			player_colors = [get_node('/root/PlayersData').puppet_color]
			
	else:
		player_colors = get_node('/root/PlayersData').colors

func swap_colors ():
	if get_node('/root/PlayersData').master_color == 'white':
		get_node('/root/PlayersData').master_color = 'black'
		get_node('/root/PlayersData').puppet_color = 'white'
	else:
		get_node('/root/PlayersData').master_color = 'white'
		get_node('/root/PlayersData').puppet_color = 'black'

func player_turn (clicked_cell, sync_mult = false):
	if sync_mult:
		active_piece = get_node(active_piece_path)
		
	if clicked_cell in $TileMap.npc_coord():
		for piece in $TileMap.npc_list:
			if piece.tile_position == clicked_cell and piece !=active_piece:
				$TileMap.npc_die(piece)
	
	for tile in $TileMap.jumped_over_tiles:
		if clicked_cell == tile and 'Pawn' in active_piece.name:
			$TileMap.npc_die($TileMap.jumped_over_tiles[clicked_cell])
			
			if get_tree().has_network_peer () and get_tree().is_network_server ():
				var dead_npc_path
				dead_npc_path = str($TileMap.jumped_over_tiles[clicked_cell].get_path())
				rpc("sync_npc_die", dead_npc_path)
			
	active_piece.position = $TileMap.map_to_world(clicked_cell)
	active_piece.tile_position = clicked_cell
	$TileMap.draw_map ()
	
	for tile in $TileMap.passable_tiles:
		if $TileMap.passable_tiles[tile] == active_piece:
			$TileMap.jumped_over_tiles[tile] = active_piece

	$TileMap.passable_tiles = {}

func change_turns ():
	if turn == 'white':
		turn = 'black'
	else:
		turn = 'white'
	
	if get_tree().has_network_peer ():
		if get_tree().is_network_server():
			$TileMap.clean_up_jumped_over (turn)
			current_turn_index += 1
			append_turn_history()
			adjust_turn_history()
			
	else:
		$TileMap.clean_up_jumped_over (turn)
		current_turn_index += 1
		append_turn_history()
		adjust_turn_history()
		set_Undo_button ()
		set_Redo_button()

	range_of_movement = []
	
func sync_multiplayer (clicked_cell):
	if get_tree().has_network_peer ():
		rset ("active_piece_path", str(active_piece.get_path()))
		
		rpc("player_turn", clicked_cell, true)
		
		rpc("change_turns")
		rset ("clickable", clickable)

func sync_promotion (piece):
	active_piece_path = str(active_piece.get_path())
	active_piece = get_node(active_piece_path)
	$TileMap.promote_pawn(active_piece, piece)
	clickable = true

func sync_npc_die (piece_path):
	var piece
	piece = get_node(piece_path)
	
	$TileMap.npc_die (piece)

func sync_pieces (name_list):
	$TileMap.place_pieces ()
	var iteration = 0
	for piece in $TileMap.npc_list:
		piece.name = name_list[iteration]
		iteration+=1

func server_place_pieces ():
	$TileMap.place_pieces ()
	var name_list = Array()
			
	for piece in $TileMap.npc_list:
		name_list.append (piece.name)
		piece.name = name_list[-1]
	
	rpc ('sync_pieces', name_list)

func set_possible_moves (piece_path, clicked_cell, double_call = false):
	var piece
	piece = get_node(piece_path)
	
	if get_tree().has_network_peer ():
		if get_tree().is_network_server ():
			range_of_movement = $TileMap.check_possible_moves(piece, $TileMap.find_possible_moves(piece, clicked_cell))
			
			if double_call:
				rset ("range_of_movement", range_of_movement)
				rpc("draw_possible_moves")
			else:
				draw_possible_moves ()
			
		else:
			rpc("set_possible_moves", piece_path, clicked_cell, true)
			
	else:
		range_of_movement = $TileMap.check_possible_moves(piece, $TileMap.find_possible_moves(piece, clicked_cell))
		draw_possible_moves ()

func draw_possible_moves ():
	$TileMap.set_cells (range_of_movement, 4)
	
func game_over (message):
	clickable = false
	$HUD/MenuBox.visible = false
	$HUD/RewindBox.visible = false
	$HUD/BackPanel.visible = false
	$HUD/Announcement/Announcement.text = message
	$HUD/Announcement.visible = true
	$HUD/EndGame.visible = true

func end_game ():
	if get_tree().has_network_peer ():
		peer.close_connection()
		get_tree().set_network_peer(null)
		
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://menu.tscn")

func draw_offer():
	clickable = false
	$HUD/MenuBox.visible = false
	$HUD/DrawOffer.visible = true
	$HUD/Announcement.visible = true
	$HUD/Announcement/Announcement.text = 'a draw offered'

func reload_scene():
	swap_colors ()
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()

func reload_client():
	rpc ('reload_scene')
	reload_scene()

func fify_moves_rule(amount_of_moves = 50):
	if 'Pawn' in active_piece.name:
		$TileMap.fifty_moves_counter = 0
		return false
	
	if turn == 'white':
		if $TileMap.fifty_moves_counter == amount_of_moves:
			return true
		else:
			$TileMap.fifty_moves_counter += 1
			return false

func threefold_rule(amount_of_moves = 3):
	if not get_tree().has_network_peer () or get_tree().is_network_server ():
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
		rpc ('threefold_rule')
				
func regex_alphabet (string):
	var regex = RegEx.new()
	var previous_result
	regex.compile("[^a-zA-Z]")
	
	while string != previous_result:
		previous_result = string
		string = regex.sub(previous_result, '')
	
	return string
	
func append_turn_history ():
	var coord_dictionary = {}
	var jumped_over_copy = {}
	
	for piece in $TileMap.npc_list.duplicate():
		coord_dictionary[piece.tile_position]=[regex_alphabet(piece.name), piece.color]
	
	for tile in $TileMap.jumped_over_tiles:
		jumped_over_copy[tile] = $TileMap.jumped_over_tiles[tile].tile_position
		
	turn_history[current_turn_index] = [turn, coord_dictionary, jumped_over_copy, $TileMap.fifty_moves_counter]
	
func set_Undo_button():
	if current_turn_index!=0:
		$HUD/RewindBox/Undo.set_disabled(false)
	else:
		$HUD/RewindBox/Undo.set_disabled(true)

func set_Redo_button():
	if current_turn_index!=turn_history.size()-1:
		$HUD/RewindBox/Redo.set_disabled(false)
	else:
		$HUD/RewindBox/Redo.set_disabled(true)

func adjust_turn_history():
	var to_clean = turn_history.keys().slice(current_turn_index+1, -1)
	
	for key in to_clean:
		turn_history.erase(key)
