extends Node2D

var range_of_movement = Array()
var active_piece
var turn = "white"

var clickable = true
var player_colors

var active_piece_path

func _ready():
	$TileMap.place_pieces ()
	$TileMap.visible = true
	
	$Camera2D.camera_following($TileMap)
	
	for button in $HUD/PromotionBox.get_children ():
		button.connect ('pressed', self, '_on_Promotion_pressed', [button.text])
	
	get_player_colors()
	
	rpc_config("player_turn", 1)
	rpc_config("change_turns", 1)
	rset_config("active_piece_path", 1)
	rset_config("clickable", 1)
#	rset_config("clicked_cell", 1)
	
func _unhandled_input(event):
	
	if event is InputEventMouseButton:
		if event.pressed and clickable and turn in player_colors:
			var clicked_cell = $TileMap.world_to_map(get_global_mouse_position())
			
			if clicked_cell in range_of_movement:
				range_of_movement = []
				
				player_turn (clicked_cell)
				
				if 'Pawn' in active_piece.name and clicked_cell in $TileMap.promotion_tiles:
					$HUD/PromotionBox.visible = true
					clickable = false
					
				change_turns()
				
				if $TileMap.check_checkmate_stalemate(turn):
					clickable = false
					$HUD/GameOver.text = turn + ' is ' + $TileMap.check_checkmate_stalemate(turn)
					$HUD/GameOver.visible = true
					$HUD/EndGame.visible = true
				
				sync_multiplayer(clicked_cell)
				
			elif clicked_cell in $TileMap.npc_coord():
				var piece = $TileMap.npc_coord()[clicked_cell]
				if piece.tile_position == clicked_cell and piece.color == turn:
					$TileMap.draw_map ()
					range_of_movement = $TileMap.check_possible_moves(piece, $TileMap.find_possible_moves(piece, clicked_cell))
					active_piece = piece
					$TileMap.set_cells (range_of_movement, 4)
						
func _on_TryAgain_pressed():
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()

func _on_Promotion_pressed(piece):
	$TileMap.promote_pawn(active_piece, piece)
	clickable = true
	$HUD/PromotionBox.visible = false
	
	sync_promotion(piece)
	
func _on_Exit_pressed():
	get_tree().change_scene("res://menu.tscn")

func get_player_colors():
	if get_tree().has_network_peer ():
		if get_tree().is_network_server():
			player_colors = [get_node('/root/PlayersData').master_color]
		else:
			player_colors = [get_node('/root/PlayersData').puppet_color]
			
	else:
		player_colors = get_node('/root/PlayersData').colors

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
	
	$TileMap.clean_up_jumped_over (turn)

func sync_multiplayer (clicked_cell):
	if get_tree().has_network_peer ():
		rset ("active_piece_path", str(active_piece.get_path()))
			
		rpc("player_turn", clicked_cell, true)
		rpc("change_turns")
		rset ("clickable", clickable)

func sync_promotion (piece):	
	if get_tree().has_network_peer ():
		rset ("clickable", clickable)
