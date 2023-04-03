extends Node

var new_game_request
var active_piece_path

onready var gs = $"../Game"
onready var peer = get_node('/root/PlayersData').peer
onready var tilemap = $"../Game/TileMap"

func multiplayer_configs():
	gs.rpc_config("player_turn", 1)
	gs.rpc_config("draw_possible_moves", 1)
	gs.rpc_config('threefold_rule', 1)
	gs.rpc_config("game_over", 1)
	gs.rpc_config("handle_notation", 1)
	
	gs.rset_config("clickable", 1)
	gs.rset_config("range_of_movement", 1)
	
	$"../NotationOutput".rpc_config("update_notation", 1)
	
	rset_config("new_game_request", 1)
	rset_config("active_piece_path", 1)
	
	rpc_config("sync_kill_piece", 1)
	rpc_config("sync_promotion", 1)
	rpc_config("sync_pieces", 1)
	rpc_config("draw_offer", 1)
	rpc_config("announcement", 1)
	rpc_config("reload_scene", 1)
	rpc_config("reload_client", 1)
	rpc_config("set_possible_moves", 1)
	rpc_config("change_turns", 1)
	
func prepare_game():
	multiplayer_configs()
	announcement('you will play as ' + gs.player_colors[0])
	
# warning-ignore:return_value_discarded
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
# warning-ignore:return_value_discarded
	get_tree().connect("server_disconnected", self, "announcement", ["opponent disconnected"])
		
	$'../Game/HUD/MenuBox'.visible = true
		
	if get_tree().is_network_server():
		server_place_pieces()
		gs.append_turn_history()
		
func set_possible_moves(piece_path, double_call = false):
	var piece = get_node(piece_path)
	
	if get_tree().is_network_server():
		gs.range_of_movement = tilemap.check_possible_moves(piece)
			
		if double_call:
			gs.rset("range_of_movement", gs.range_of_movement)
			gs.rpc("draw_possible_moves")
		else:
			gs.draw_possible_moves()
			
	else:
		rpc("set_possible_moves", piece_path, true)

func change_turns():
	gs.swap_turn()
		
	if get_tree().is_network_server():
		gs.update_turn()
					
func _player_disconnected(_id):
	announcement("opponent disconnected")
	$'../Game/HUD/EndGame/TryAgain'.set_disabled(true)

func reload_client():
	rpc('reload_scene')
	reload_scene()

func server_place_pieces():
	tilemap.place_pieces()
	var name_list = Array()
			
	for piece in tilemap.chessmen_list:
		name_list.append(piece.name)
		piece.name = name_list[-1]
	
	rpc('sync_pieces', name_list)
	
func sync_multiplayer(clicked_cell):
	rset("active_piece_path", str(gs.active_piece.get_path()))
	
	gs.rpc("player_turn", clicked_cell, true)
	
	rpc("change_turns")
	
	gs.rset("clickable", gs.clickable)
	gs.rset("range_of_movement", [])

func sync_promotion(piece):
	gs.active_piece = get_node(active_piece_path)
	tilemap.promote_pawn(gs.active_piece, piece)
	gs.clickable = true

func sync_kill_piece(piece_path):
	var piece = get_node(piece_path)
	
	tilemap.kill_piece(piece)

func sync_pieces(name_list):
	tilemap.place_pieces()
	var iteration = 0
	for piece in tilemap.chessmen_list:
		piece.name = name_list[iteration]
		iteration+=1
		
func announcement(text):
	var timer = Timer.new()
	$'../Game/HUD/Announcement'.visible = true
	$'../Game/HUD/Announcement/Announcement'.text = text
	gs.clickable = false
	timer.connect("timeout",self,"anouncment_hide")
	timer.wait_time = 2
	timer.one_shot = true
	add_child(timer)
	timer.start()

func anouncment_hide():
	$'../Game/HUD/Announcement'.visible = false
	gs.clickable = true
	
	if $'../Game/HUD/Announcement/Announcement'.text == 'offer declined':
		$'../Game/HUD/MenuBox'.visible = true
	
	if $'../Game/HUD/Announcement/Announcement'.text == 'opponent disconnected':
		get_tree().set_network_peer(null)
# warning-ignore:return_value_discarded
		get_tree().change_scene("res://scenes/menu.tscn")
		
func draw_offer():
	gs.clickable = false
	$'../Game/HUD/MenuBox'.visible = false
	$'../Game/HUD/DrawOffer'.visible = true
	$'../Game/HUD/Announcement'.visible = true
	$'../Game/HUD/Announcement/Announcement'.text = 'a draw offered'

func swap_colors():
	if get_node('/root/PlayersData').master_color == 'white':
		get_node('/root/PlayersData').master_color = 'black'
		get_node('/root/PlayersData').puppet_color = 'white'
	else:
		get_node('/root/PlayersData').master_color = 'white'
		get_node('/root/PlayersData').puppet_color = 'black'

func reload_scene():
	swap_colors()
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()
	
func _on_Surrender_pressed():
	gs.game_over(gs.player_colors[0] + ' surrender')
	gs.rpc('game_over', gs.player_colors[0] + ' surrender')

func _on_Draw_pressed():
	gs.clickable = false
	$'../Game/HUD/MenuBox'.visible = false
	rpc('draw_offer')

func _on_Accept_pressed():
	$'../Game/HUD/DrawOffer'.visible = false
	gs.game_over('it is a draw')
	gs.rpc('game_over', 'it is a draw')

func _on_Decline_pressed():
	$'../Game/HUD/DrawOffer'.visible = false
	$'../Game/HUD/MenuBox'.visible = true
	$'../Game/HUD/Announcement'.visible = false
	gs.clickable = true
	rpc('announcement', 'offer declined')

func _on_TryAgain_pressed():
	if new_game_request:
		if get_tree().is_network_server():
			rpc('reload_client')

		else:
			rpc('reload_scene')
			reload_scene()

	else:
		$'../Game/HUD/Announcement/Announcement'.text = 'request sent'
		rset('new_game_request', true)

func _on_Exit_pressed():
	peer.close_connection()
	get_tree().set_network_peer(null)
		
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://scenes/menu.tscn")
