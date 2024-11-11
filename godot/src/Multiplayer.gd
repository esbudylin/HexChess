extends Node

var new_game_request

onready var gs = $"../Game"

onready var peer = Config.peer

func multiplayer_configs():
	gs.rpc_config("game_over", 1)
	gs.rpc_config("handle_notation", 1)
	gs.rpc_config("make_move", 1)
	
	gs.rset_config("range_of_movement", 1)
	gs.rset_config("active_piece", 1)
	
	gs.rset_config('promotion_tiles', 1)
	gs.rset_config('current_color', 1)
	
	gs.tilemap.rpc_config("place_pieces", 1)
	gs.tilemap.rpc_config("draw_map", 1)
	gs.tilemap.rpc_config("draw_possible_moves", 1)
		
	gs.tilemap.rset_config("tile_colors", 1)
	
	rset_config("new_game_request", 1)

	rpc_config("draw_offer", 1)
	rpc_config("announcement", 1)
	rpc_config("reload_scene", 1)
	rpc_config("reload_client", 1)
	
	rpc_config("set_possible_moves_server", 1)
		
	$"../NotationOutput".rpc_config("update_notation", 1)
	
func prepare_game():
	multiplayer_configs()
	announcement('you will play as ' + gs.player_colors[0])
	
# warning-ignore:return_value_discarded
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
# warning-ignore:return_value_discarded
	get_tree().connect("server_disconnected", self, "_player_disconnected", ["_"])
		
	$'../Game/HUD/MenuBox'.visible = true
	$'../Game/HUD/NotationPanel/SaveLoad/LoadGame'.visible = false
	
	if get_tree().is_network_server():
		gs.prepare_game()
		
		gs.tilemap.rpc('place_pieces', gs.Board.get_current_position())
		gs.tilemap.rset('tile_colors', gs.tilemap.tile_colors)
		gs.tilemap.rpc('draw_map')
		
		gs.rset('promotion_tiles', gs.promotion_tiles)
		gs.rset('current_color', gs.current_color)
		
func set_possible_moves_server(cell):
	var piece = gs.Board.check_tile_for_chessman(cell)

	if piece:
		gs.rset('active_piece', piece)
		
		gs.rset('range_of_movement', gs.Board.find_possible_moves(piece.tile_position))
		
		gs.tilemap.rpc('draw_map')
		gs.tilemap.rpc('draw_possible_moves')
		
func _player_disconnected(_id):
	gs.game_over("opponent disconnected")
	gs.get_node('HUD/EndGame/TryAgain').visible = false

func reload_client():
	rpc('reload_scene')
	reload_scene()
		
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
		
func draw_offer():
	gs.clickable = false
	$'../Game/HUD/DrawOffer'.visible = true
	$'../Game/HUD/Announcement'.visible = true
	$'../Game/HUD/Announcement/Announcement'.text = 'a draw offered'

func swap_colors():
	if Config.master_color == 'white':
		Config.master_color = 'black'
		Config.puppet_color = 'white'
	else:
		Config.master_color = 'white'
		Config.puppet_color = 'black'

func reload_scene():
	swap_colors()
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()
	
func _on_Resign_pressed():
	gs.game_over(gs.player_colors[0] + ' resign', gs.player_colors[0])
	gs.rpc('game_over', gs.player_colors[0] + ' resign', gs.player_colors[0])

func _on_Draw_pressed():
	gs.clickable = false
	rpc('draw_offer')

func _on_Accept_pressed():
	$'../Game/HUD/DrawOffer'.visible = false
	gs.game_over('it is a draw', 'draw')
	gs.rpc('game_over', 'it is a draw', 'draw')

func _on_Decline_pressed():
	$'../Game/HUD/DrawOffer'.visible = false
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
