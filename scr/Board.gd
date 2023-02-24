extends TileMap

var chessmen_list = Array()
var chessmen_coords = Dictionary()

var jumped_over_tiles = Dictionary()
var passable_tiles = Dictionary()

var tile_colors = Dictionary()

var fifty_moves_counter = 0

onready var initial_pawn_tiles_white = delete_duplicates($Mapping.black_pawn_tiles)

onready var initial_pawn_tiles_black = delete_duplicates($Mapping.white_pawn_tiles)

onready var promotion_tiles = delete_duplicates(
	$Mapping.draw_diagonal_line(Vector2(0, -5), 5, 1, 1)
	+ $Mapping.draw_diagonal_line(Vector2(0, -5), 5, -1, 1)
	+ $Mapping.draw_diagonal_line(Vector2(0, 5), 5, 1, -1)
	+ $Mapping.draw_diagonal_line(Vector2(0, 5), 5, -1, -1)) 

onready var coord_tiles = $Mapping.regular_hexagon(0, 0)

onready var verticals_1 = $Mapping.draw_diagonal_line(Vector2(-5, -3), 5, 1, -1)
onready var verticals_2 = $Mapping.draw_diagonal_line(Vector2(5, -3), 4, -1, -1)

func draw_map():
	set_verticals(verticals_1)
	set_verticals(verticals_2)

func set_verticals(tile_array):
	var tilenumbers = [0, 1, 2]
	var index = 0
	for vertical in tile_array:
		var tile = vertical
		var iteration = 0
		var index_while = index
		
		while tile in coord_tiles:
			set_cell(tile[0], tile[1], tilenumbers[index_while])
			tile_colors[tile] = tilenumbers[index_while]
			
			tile = Vector2(vertical[0], vertical[1]+iteration)
			iteration+=1
			
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
		
	chessmen_list.append(piece)
	chessmen_coords[tile_position] = piece

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
	
func check_movement(new_position):
	if new_position in coord_tiles and not new_position in chessmen_coords:
		return true
	else:
		return false

func check_array(tile_array, additional_check = true, piece = null):
	var coord_tiles_local = Array()
	
	for tile in tile_array:
		if check_movement(tile) or tile == tile_array[0] and additional_check:
			coord_tiles_local.append(tile)
			
		elif piece and tile in chessmen_coords and piece.color != chessmen_coords[tile].color:
			coord_tiles_local.append(tile)
			break
			
		else:
			break
			
	return coord_tiles_local

func kill_piece(NPC):
	NPC.visible = false
	chessmen_list.erase(NPC)
	chessmen_coords.erase(NPC.tile_position)
	fifty_moves_counter = 0
	
func rook_movement(NPC, position, iterations = 12, check = true):
	var coord_tiles_local = []
	var diagonals = [[1, 1], [1, -1], [-1, 1], [-1, -1]]
	
	for diagonal in diagonals:
		if check:
			coord_tiles_local.append_array(
				check_array($Mapping.draw_diagonal_line(position, iterations-1, diagonal[0], diagonal[1]), true, NPC))
		else:
			coord_tiles_local.append_array(
				$Mapping.draw_diagonal_line(position, iterations-1, diagonal[0], diagonal[1]))
			
	if check:
		coord_tiles_local.append_array(
			check_array($Mapping.draw_vertical_line(position, iterations), true, NPC))
		coord_tiles_local.append_array(
			check_array($Mapping.draw_vertical_line(position, iterations, -1), true, NPC))
	else:
		coord_tiles_local.append_array($Mapping.draw_vertical_line(position, iterations))
		coord_tiles_local.append_array($Mapping.draw_vertical_line(position, iterations, -1))
		
	coord_tiles_local = delete_duplicates(coord_tiles_local)
	
	return coord_tiles_local

func bishop_movement(NPC, position, iterations = 5, check = true):
	var coord_tiles_local = []
	var horizontal1 = []
	var horizontal2 = []
	
	for iteration in iterations+1:
		horizontal1.append(Vector2(position[0]+iteration*2, position[1]))
		horizontal2.append(Vector2(position[0]-iteration*2, position[1]))
	
	if check:
		coord_tiles_local.append_array(
			check_array(horizontal1, true, NPC)+check_array(horizontal2, true, NPC))
	else:
		coord_tiles_local.append_array(horizontal1 + horizontal2)
		
	var diagonals = [[2, 1, 1], [-1, -2, 1], [2, 1, -1], [-1, -2, -1]]
	
	for diagonal in diagonals:
		if check:
			coord_tiles_local.append_array(check_array(
				$Mapping.bishop_diagonal(position, diagonal[0], diagonal[1], diagonal[2], iterations), false, NPC))
		else:
			coord_tiles_local.append_array(
				$Mapping.bishop_diagonal(position, diagonal[0], diagonal[1], diagonal[2], iterations))
			
	coord_tiles_local = delete_duplicates(coord_tiles_local)
	return coord_tiles_local

func knight_movement(piece, position):
	var coord_tiles_local = [position]
	var moves = Array()
	
	if int(position[0])%2==0:
		moves = [[-1, -2], [-2, -2], [1, -2], [2, -2], [3, 0], [3, 1],
		[2, 2], [1, 3], [-1, 3], [-2, 2], [-3, 1], [-3, 0]]
	else:
		moves = [[1, -3], [2, -2], [-1, -3], [-2, -2], [3, -1],
		[3, 0], [-3, -1], [-3, 0], [-2, 2], [-1, 2], [1, 2], [2, 2]]
		
	for move in moves:
		var tile =(Vector2(position[0]-move[0], position[1]-move[1]))
		if check_movement(tile) or tile in chessmen_coords and chessmen_coords[tile].color != piece.color:
			coord_tiles_local.append(tile)
	
	return coord_tiles_local

func pawn_movement(pawn, position):
	var coord_tiles_local = []
	
	if pawn.color == 'black' and position in initial_pawn_tiles_black:
		coord_tiles_local.append_array(check_array($Mapping.draw_vertical_line(position, 3)))
	
	elif pawn.color == 'black':
		coord_tiles_local.append_array(check_array($Mapping.draw_vertical_line(position, 2)))
	
	elif pawn.color == 'white' and position in initial_pawn_tiles_white:
		coord_tiles_local.append_array(check_array($Mapping.draw_vertical_line(position, 3, -1)))
	
	else:
		coord_tiles_local.append_array(check_array($Mapping.draw_vertical_line(position, 2, -1)))
	
	if delete_duplicates(coord_tiles_local).size() == 3:
		passable_tiles[delete_duplicates(coord_tiles_local)[1]] = pawn
	
	return delete_duplicates(coord_tiles_local) + pawn_attack(pawn, position)

func pawn_attack(pawn, position, check = true):
	var coord_tiles_local = []
	var closest_tiles = $Mapping.find_closest_tiles(position)
	var attack_tiles = []
	
	if pawn.color == 'white' and $Mapping.chess_type == 'Glinski':
		if int(position[0])%2!=0:
			attack_tiles.append_array([closest_tiles[3], closest_tiles[1]])
		else:
			attack_tiles.append_array([closest_tiles[0], closest_tiles[4]])
	
	elif pawn.color == 'black' and $Mapping.chess_type == 'Glinski':
		if int(position[0])%2!=0:
			attack_tiles.append_array([closest_tiles[0], closest_tiles[4]])
		else:
			attack_tiles.append_array([closest_tiles[3], closest_tiles[1]])
	
	elif pawn.color == 'black':
		attack_tiles.append_array(
			$Mapping.bishop_diagonal(position, 2, 1, 1, 1) + $Mapping.bishop_diagonal(position, 2, 1, -1, 1))
	
	elif pawn.color == 'white':
		attack_tiles.append_array(
			$Mapping.bishop_diagonal(position, -1, -2, 1, 1) + $Mapping.bishop_diagonal(position, -1, -2, -1, 1))
	
	if check == true:
		for tile in attack_tiles:
			if tile in chessmen_coords:
				var piece = chessmen_coords[tile]
				if piece.color != pawn.color:
					coord_tiles_local.append(tile)
					
			elif tile in jumped_over_tiles and jumped_over_tiles[tile].color != pawn.color:
				coord_tiles_local.append(tile)
	else:
		coord_tiles_local = attack_tiles

	return coord_tiles_local
	
func king_movement(king, position):
	var initial = delete_duplicates(
		rook_movement(king, position, 2) + bishop_movement(king, position, 1))
	
	var coord_tiles_local = initial.duplicate()
	chessmen_list.erase(king)
	
	for tile in initial:
		for piece in chessmen_list:
			
			if piece.color != king.color and not 'Pawn' in piece.name and not 'King' in piece.name:
				if tile in find_possible_moves(piece, piece.tile_position):
					coord_tiles_local.erase(tile)
					
			elif piece.color != king.color and 'King' in piece.name:
				if tile in delete_duplicates(
					rook_movement(piece, piece.tile_position, 2, false) 
					+ bishop_movement(piece, piece.tile_position, 1, false)):
					coord_tiles_local.erase(tile)
					
			elif piece.color != king.color and 'Pawn' in piece.name:
				if tile in pawn_attack(piece, piece.tile_position, false):
					coord_tiles_local.erase(tile)
	
	chessmen_list.append(king)
	return coord_tiles_local

func promote_pawn(pawn, promotion):
	kill_piece(pawn)
	var new_piece = get_node("Piece/"+promotion).duplicate()
	add_piece(new_piece, pawn.tile_position, promotion, pawn.color)
	
func delete_duplicates(array):
	var unique_elements = []
	for element in array:
		if not element in unique_elements:
			unique_elements.append(element)
		
	return unique_elements

func clean_up_jumped_over(color):
	for tile in jumped_over_tiles.keys():
		if jumped_over_tiles[tile].color == color:
			jumped_over_tiles.erase(tile)

func check_checkmate_stalemate(turn):
	for tile_piece in chessmen_coords:
		if chessmen_coords[tile_piece].color == turn\
		and check_possible_moves(chessmen_coords[tile_piece]) != []:
			return false
	
	if if_king_checked(turn):
		return 'checkmated'
	else:
		return 'stalemated'

func if_able_to_checkmate(color):
	var pieces_dict = {'Knight': 0, 'Bishop': 0}
	var bishops = Array()
	
	for piece in chessmen_list:
		if piece.color == color:
			
			if 'Pawn' in piece.name or 'Queen' in piece.name or 'Rook' in piece.name:
				return true
				
			elif 'Knight' in piece.name:
				pieces_dict['Knight'] += 1
				
			elif 'Bishop' in piece.name:
				pieces_dict['Bishop'] += 1
				bishops.append(piece)
	
	if pieces_dict['Knight'] >= 2:
		return true
	
	elif pieces_dict['Knight'] <= 1 and pieces_dict['Bishop'] <=1:
		return false
		
	elif pieces_dict['Knight'] == 0 and pieces_dict['Bishop'] == 2:
		return false
		
	elif pieces_dict['Bishop'] >= 3 and pieces_dict['Knight'] == 0:
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
	
func find_king(color):
	for piece in chessmen_list:
		if 'King' in piece.name and piece.color == color:
			return piece

func if_king_checked(turn):
	var king = find_king(turn)

	for piece in chessmen_list:
		if king.tile_position in find_possible_moves(piece, piece.tile_position):
			return true
			
	return false

func find_chessmen_coords(chessmen_list_local = chessmen_list):
	var coords_dict = Dictionary()
	
	for NPC in chessmen_list_local:
		coords_dict[NPC.tile_position] = NPC
		
	return coords_dict

func check_possible_moves(NPC, range_of_movement = null):
	var initial_position = NPC.tile_position
	var king = find_king(NPC.color)
	var chessmen_coords_copy = chessmen_coords.duplicate()
	
	if range_of_movement == null:
		range_of_movement = find_possible_moves(NPC, NPC.tile_position)
			
	for tile in range_of_movement.duplicate():
		var chessmen_list_copy = chessmen_list.duplicate()

		if tile in chessmen_coords:
			chessmen_list_copy.erase(chessmen_coords[tile])
		
		NPC.tile_position = tile
		chessmen_coords = find_chessmen_coords(chessmen_list_copy)
		
		for tile_piece in chessmen_coords:
			if chessmen_coords[tile_piece].color != NPC.color\
			and king.tile_position in find_possible_moves(chessmen_coords[tile_piece], tile_piece):
				range_of_movement.erase(tile)
				
	chessmen_coords = chessmen_coords_copy		
	NPC.tile_position = initial_position
	
	return range_of_movement
	
func find_possible_moves(NPC, position):
	var range_of_movement = Array()
	
	if "Pawn" in NPC.name:
		range_of_movement = pawn_movement(NPC, position)
		
	elif "Knight" in NPC.name:
		range_of_movement = knight_movement(NPC, position)
		
	elif "Bishop" in NPC.name:
		range_of_movement = bishop_movement(NPC, position)
	
	elif "Rook" in NPC.name:
		range_of_movement = rook_movement(NPC, position)
		
	elif "Queen" in NPC.name:
		range_of_movement = delete_duplicates(
			bishop_movement(NPC, position) + rook_movement(NPC, position))
	
	elif "King" in NPC.name:
		range_of_movement = king_movement(NPC, position)
	
	range_of_movement.erase(position)
	return range_of_movement
