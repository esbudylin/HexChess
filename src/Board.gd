extends "res://src/Movement.gd"

var tile_colors = Dictionary()
var chessmen_by_color_by_type = {'white' : {}, 'black' : {}}

var turn = "white"
var turn_history = {}
var current_turn_index = 0

var fifty_moves_counter = 0

onready var promotion_tiles = delete_duplicates(
	$Mapping.draw_diagonal_line(Vector2(0, -5), 5, 1, 1)
	+ $Mapping.draw_diagonal_line(Vector2(0, -5), 5, -1, 1)
	+ $Mapping.draw_diagonal_line(Vector2(0, 5), 5, 1, -1)
	+ $Mapping.draw_diagonal_line(Vector2(0, 5), 5, -1, -1)) 

onready var verticals_1 = $Mapping.draw_diagonal_line(Vector2(-5, -3), 5, 1, -1)
onready var verticals_2 = $Mapping.draw_diagonal_line(Vector2(5, -3), 4, -1, -1)

func _ready():
	self.Mapping = $Mapping
	draw_map()

func draw_map():
	set_verticals(verticals_1+verticals_2)
	
func set_verticals(tile_array):
	var tilenumbers = [0, 1, 2]
	var index = 0
	for vertical in tile_array:
		var tile = vertical
		var i = 0
		var index_while = index
		
		while tile in coord_tiles:
			set_cell(tile[0], tile[1], tilenumbers[index_while])
			tile_colors[tile] = tilenumbers[index_while]
			
			tile = Vector2(vertical[0], vertical[1]+i)
			i+=1
			
			index_while+=1
			if index_while == tilenumbers.size():
				index_while = 0
				
		index+=1
		if index == tilenumbers.size():
			index = 0
			
func set_cells(set_tiles, tile_number):
	for tile in set_tiles:
		set_cell(tile[0], tile[1], tile_number)

func add_piece(piece, tile_position, type, color = null):
	add_child(piece)
		
	piece.tile_position = tile_position
	piece.position = map_to_world(piece.tile_position)
	piece.type = type
	piece.visible = true
	
	if color == 'black' or color == null and tile_position[1] < 0:
		piece.get_child(0).visible = true
		piece.color = 'black'
	elif color == 'white' or color == null and tile_position[1] > 0:
		piece.get_child(1).visible = true
		piece.color = 'white'
	
	if piece.type == 'King':
		kings[piece.color] = piece
	
	chessmen_list.append(piece)
	chessmen_coords[tile_position] = piece
	
	if piece.type in chessmen_by_color_by_type[piece.color]:
		chessmen_by_color_by_type[piece.color][piece.type].append(piece)
	else:
		chessmen_by_color_by_type[piece.color][piece.type]=[piece]

func place_type_of_pieces(type, tiles):
	for tile in tiles:
		var piece_copy = type.duplicate()
		add_piece(piece_copy, tile, type.name)

func place_pieces():
	var pieces_places = {
	$Piece/King: $Mapping.king_tiles,
	$Piece/Queen: $Mapping.queen_tiles,
	$Piece/Rook: $Mapping.rook_tiles,
	$Piece/Bishop: $Mapping.bishop_tiles,
	$Piece/Knight: $Mapping.knight_tiles,
	$Piece/Pawn: initial_pawn_tiles_black + initial_pawn_tiles_white
	}
	
	for type in pieces_places:
		place_type_of_pieces(type, pieces_places[type])
	
	if $Mapping.chess_type == 'McCooey': #these pawns aren't allowed to double-jump in McCooey version
		initial_pawn_tiles_black.erase(Vector2(0, -2))
		initial_pawn_tiles_white.erase(Vector2(0, 2))

func kill_piece(NPC, notate = true):
	NPC.visible = false
	chessmen_list.erase(NPC)
	chessmen_coords.erase(NPC.tile_position)
	chessmen_by_color_by_type[NPC.color][NPC.type].erase(NPC)
	
	if notate:
		fifty_moves_counter = 0
		
func move_piece(piece, new_position):
	chessmen_coords.erase(piece.tile_position)			
	piece.position = map_to_world(new_position)
	piece.tile_position = new_position
	chessmen_coords[new_position] = piece
	
	if piece.type == 'Pawn':
		fifty_moves_counter = 0

func capture_on_position(piece, new_position):
	var result = {'captured': false, 'en_passant': false}
	
	if new_position in chessmen_coords:
		kill_piece(chessmen_coords[new_position])
		
		result.captured = true
				
	elif 'Pawn' == piece.type and new_position in jumped_over_tiles\
	and new_position in pawn_attack(piece, piece.tile_position, false):
		kill_piece(jumped_over_tiles[new_position])
		
		result.captured = true
		result.en_passant = true
		
	return result

func promote_pawn(pawn, promotion):
	kill_piece(pawn, false)
	var new_piece = get_node("Piece/"+promotion).duplicate()
	add_piece(new_piece, pawn.tile_position, promotion, pawn.color)

func check_checkmate_stalemate(moved_piece):
	for tile_piece in chessmen_coords.duplicate():
		if chessmen_coords[tile_piece].color == turn\
		and check_possible_moves(chessmen_coords[tile_piece]) != []:
			return false
	
	if if_king_checked(moved_piece):
		return 'checkmated'
	else:
		return 'stalemated'

func if_able_to_checkmate(color):
	var pieces_dict = {'Knight': 0, 'Bishop': 0}
	var bishops = Array()
	
	for piece in chessmen_list:
		if piece.color == color:
			
			if 'Pawn' == piece.type or 'Queen' == piece.type or 'Rook' == piece.type:
				return true
				
			elif 'Knight' == piece.type:
				pieces_dict.Knight += 1
				
			elif 'Bishop' == piece.type:
				pieces_dict.Bishop += 1
				bishops.append(piece)
	
	if pieces_dict.Knight >= 2:
		return true
	
	elif pieces_dict.Knight <= 1 and pieces_dict.Bishop <=1:
		return false
		
	elif pieces_dict.Knight == 0 and pieces_dict.Bishop == 2:
		return false
		
	elif pieces_dict.Knight >= 3 and pieces_dict.Bishop == 0:
		var colors = Array()
		
		for bishop in bishops:
			if not tile_colors[bishop.tile_position] in colors:
				colors.append(tile_colors[bishop.tile_position])
		
		if colors.size() == 3:
			return true
		
		else:
			return false
	
	else:
		return true

func if_king_checked(moved_piece):
	var king = kings[turn]

	if king.tile_position in find_possible_moves(moved_piece):
		return true
		
	else:
		for piece in chessmen_list:
			if piece != moved_piece and piece.type != "King":
				if king.tile_position in find_possible_moves(piece):
					return true
			
	return false

func clean_up_jumped_over(color):
	for tile in jumped_over_tiles.keys():
		if jumped_over_tiles[tile].color == color:
			jumped_over_tiles.erase(tile)

func update_jumped_over_tiles(moved_piece):
	if moved_piece.type == "Pawn":
		for tile in passable_tiles:
			if passable_tiles[tile] == moved_piece:
				jumped_over_tiles[tile] = moved_piece

	passable_tiles = {}

func fifty_moves_rule(amount_of_moves = 50):
	if turn == 'white':
		if fifty_moves_counter == amount_of_moves:
			return true
		else:
			fifty_moves_counter += 1
			return false

func threefold_rule(amount_of_moves = 3):
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

func append_turn_history():
	var coord_dictionary = {}
	var jumped_over_copy = {}
	
	for piece in chessmen_list.duplicate():
		coord_dictionary[piece.tile_position]=[piece.type, piece.color]
	
	for tile in jumped_over_tiles:
		jumped_over_copy[tile] = jumped_over_tiles[tile].tile_position
	
	turn_history[current_turn_index] = [turn, coord_dictionary, jumped_over_copy, fifty_moves_counter]

func adjust_turn_history():
	var to_clean = turn_history.keys().slice(current_turn_index+1, -1)
	
	for key in to_clean:
		turn_history.erase(key)
		
func swap_turn():
	if turn == 'white':
		turn = 'black'
	else:
		turn = 'white'

func update_turn():
	clean_up_jumped_over(turn)
	current_turn_index += 1
	append_turn_history()
	adjust_turn_history()