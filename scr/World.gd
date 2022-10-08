extends Node2D

var range_of_movement = Array()
var turn = "white"

var clickable = true

var player_colors

var active_piece
var active_piece_path

var new_game_request

onready var peer = get_node('/root/PlayersData').peer

func _ready():
	$TileMap.visible = true
	
	$Camera2D.camera_following($TileMap)
	
	for button in $HUD/PromotionBox.get_children ():
		button.connect ('pressed', self, '_on_Promotion_pressed', [button.text])
	
	get_player_colors()
	multiplayer_configs ()
	announcement ('you will play as ' + player_colors[0])
	
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("server_disconnected", self, "end_game")
	
	if get_tree().has_network_peer ():
		$HUD/MenuBox.visible = true
		
		if get_tree().is_network_server():
			$TileMap.place_pieces ()
			var name_list = Array()
			
			for piece in $TileMap.npc_list:
				name_list.append (piece.name)
				piece.name = name_list[-1]

			rpc ('sync_pieces', name_list)
		
	else:
		$TileMap.place_pieces ()
	
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
				
				sync_multiplayer(clicked_cell)
				
			elif clicked_cell in $TileMap.npc_coord():
				var piece = $TileMap.npc_coord()[clicked_cell]
				if piece.tile_position == clicked_cell and piece.color == turn:
					$TileMap.draw_map ()
					active_piece = piece
					set_possible_moves (str(active_piece.get_path()), clicked_cell)
						
func _on_TryAgain_pressed():
	
	if new_game_request == true:
		if get_tree().is_network_server():
			rpc ('reload_scene')
			reload_scene()
			
		else:
			reload_scene()
			rpc ('reload_scene')
			
	else:
		$HUD/Announcement/Announcement.text = 'request sent'
		rset ('new_game_request', true)

func reload_scene():
	swap_colors ()
	get_tree().reload_current_scene()
	
func _on_Promotion_pressed(piece):
	$TileMap.promote_pawn(active_piece, piece)
	clickable = true
	$HUD/PromotionBox.visible = false
	
	if get_tree().has_network_peer ():
		$HUD/MenuBox.visible = true
		rpc("sync_promotion", piece)
	
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
	else:
		$TileMap.clean_up_jumped_over (turn)
	
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
	$HUD/Announcement/Announcement.text = message
	$HUD/Announcement.visible = true
	$HUD/EndGame.visible = true

func end_game ():
	if get_tree().has_network_peer ():
		peer.close_connection()
		get_tree().set_network_peer(null)
		
	get_tree().change_scene("res://menu.tscn")

func _player_disconnected (_id):
	get_tree().set_network_peer(null)
	get_tree().change_scene("res://menu.tscn")

func draw_offer():
	clickable = false
	$HUD/MenuBox.visible = false
	$HUD/DrawOffer.visible = true
	$HUD/Announcement.visible = true
	$HUD/Announcement/Announcement.text = 'a draw offered'
