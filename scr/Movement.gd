extends TileMap

var chessmen_list = Array()
var chessmen_coords = Dictionary()

var jumped_over_tiles = Dictionary()
var passable_tiles = Dictionary()

var kings = Dictionary()

var Mapping setget setMapping

var initial_pawn_tiles_white
var initial_pawn_tiles_black

var coord_tiles

func setMapping(mapping_node):
	Mapping = mapping_node
	initial_pawn_tiles_white = delete_duplicates(Mapping.black_pawn_tiles)
	initial_pawn_tiles_black = delete_duplicates(Mapping.white_pawn_tiles)

	coord_tiles = Mapping.regular_hexagon(0, 0)

func check_possible_moves(NPC):
	var initial_position = NPC.tile_position
	var king = kings[NPC.color]
	var chessmen_coords_copy = chessmen_coords.duplicate()
	
	var range_of_movement = find_possible_moves(NPC, NPC.tile_position)
			
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

func find_chessmen_coords(chessmen_list_local = chessmen_list):
	var coords_dict = Dictionary()
	
	for NPC in chessmen_list_local:
		coords_dict[NPC.tile_position] = NPC
		
	return coords_dict

func find_possible_moves(NPC, position):
	var range_of_movement = Array()
	
	if "Pawn" == NPC.type:
		range_of_movement = pawn_movement(NPC, position)
		
	elif "Knight" == NPC.type:
		range_of_movement = knight_movement(NPC, position)
		
	elif "Bishop" == NPC.type:
		range_of_movement = bishop_movement(NPC, position)
	
	elif "Rook" == NPC.type:
		range_of_movement = rook_movement(NPC, position)
		
	elif "Queen" == NPC.type:
		range_of_movement = delete_duplicates(
			bishop_movement(NPC, position) + rook_movement(NPC, position))
	
	elif "King" == NPC.type:
		range_of_movement = king_movement(NPC, position)
	
	range_of_movement.erase(position)
	return range_of_movement

func rook_movement(NPC, position, iterations = 12, check = true):
	var coord_tiles_local = []
	var diagonals = [[1, 1], [1, -1], [-1, 1], [-1, -1]]
	
	for diagonal in diagonals:
		if check:
			coord_tiles_local.append_array(
				check_array(Mapping.draw_diagonal_line(position, iterations-1, diagonal[0], diagonal[1]), true, NPC))
		else:
			coord_tiles_local.append_array(
				Mapping.draw_diagonal_line(position, iterations-1, diagonal[0], diagonal[1]))
			
	if check:
		coord_tiles_local.append_array(
			check_array(Mapping.draw_vertical_line(position, iterations), true, NPC))
		coord_tiles_local.append_array(
			check_array(Mapping.draw_vertical_line(position, iterations, -1), true, NPC))
	else:
		coord_tiles_local.append_array(Mapping.draw_vertical_line(position, iterations))
		coord_tiles_local.append_array(Mapping.draw_vertical_line(position, iterations, -1))
		
	coord_tiles_local = delete_duplicates(coord_tiles_local)
	
	return coord_tiles_local

func bishop_movement(NPC, position, iterations = 5, check = true):
	var coord_tiles_local = []
	var horizontal1 = []
	var horizontal2 = []
	
	for i in iterations+1:
		horizontal1.append(Vector2(position[0]+i*2, position[1]))
		horizontal2.append(Vector2(position[0]-i*2, position[1]))
	
	if check:
		coord_tiles_local.append_array(
			check_array(horizontal1, true, NPC)+check_array(horizontal2, true, NPC))
	else:
		coord_tiles_local.append_array(horizontal1 + horizontal2)
		
	var diagonals = [[2, 1, 1], [-1, -2, 1], [2, 1, -1], [-1, -2, -1]]
	
	for diagonal in diagonals:
		if check:
			coord_tiles_local.append_array(check_array(
				Mapping.bishop_diagonal(position, diagonal[0], diagonal[1], diagonal[2], iterations), false, NPC))
		else:
			coord_tiles_local.append_array(
				Mapping.bishop_diagonal(position, diagonal[0], diagonal[1], diagonal[2], iterations))
			
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
		coord_tiles_local.append_array(check_array(Mapping.draw_vertical_line(position, 3)))
	
	elif pawn.color == 'black':
		coord_tiles_local.append_array(check_array(Mapping.draw_vertical_line(position, 2)))
	
	elif pawn.color == 'white' and position in initial_pawn_tiles_white:
		coord_tiles_local.append_array(check_array(Mapping.draw_vertical_line(position, 3, -1)))
	
	else:
		coord_tiles_local.append_array(check_array(Mapping.draw_vertical_line(position, 2, -1)))
	
	if delete_duplicates(coord_tiles_local).size() == 3:
		passable_tiles[delete_duplicates(coord_tiles_local)[1]] = pawn
	
	return delete_duplicates(coord_tiles_local) + pawn_attack(pawn, position)

func pawn_attack(pawn, position, check = true):
	var coord_tiles_local = []
	var closest_tiles = Mapping.find_closest_tiles(position)
	var attack_tiles = []
	
	if pawn.color == 'white' and Mapping.chess_type == 'Glinski':
		if int(position[0])%2!=0:
			attack_tiles.append_array([closest_tiles[3], closest_tiles[1]])
		else:
			attack_tiles.append_array([closest_tiles[0], closest_tiles[4]])
	
	elif pawn.color == 'black' and Mapping.chess_type == 'Glinski':
		if int(position[0])%2!=0:
			attack_tiles.append_array([closest_tiles[0], closest_tiles[4]])
		else:
			attack_tiles.append_array([closest_tiles[3], closest_tiles[1]])
	
	elif pawn.color == 'black':
		attack_tiles.append_array(
			Mapping.bishop_diagonal(position, 2, 1, 1, 1) + Mapping.bishop_diagonal(position, 2, 1, -1, 1))
	
	elif pawn.color == 'white':
		attack_tiles.append_array(
			Mapping.bishop_diagonal(position, -1, -2, 1, 1) + Mapping.bishop_diagonal(position, -1, -2, -1, 1))
	
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
			
			if piece.color != king.color:
				if not 'Pawn' in piece.name and not 'King' in piece.name:
					if tile in find_possible_moves(piece, piece.tile_position):
						coord_tiles_local.erase(tile)
					
				elif 'King' in piece.name:
					if tile in delete_duplicates(
						rook_movement(piece, piece.tile_position, 2, false) 
						+ bishop_movement(piece, piece.tile_position, 1, false)):
						coord_tiles_local.erase(tile)
						
				elif 'Pawn' in piece.name:
					if tile in pawn_attack(piece, piece.tile_position, false):
						coord_tiles_local.erase(tile)
	
	chessmen_list.append(king)
	return coord_tiles_local
	
func delete_duplicates(array):
	var unique_elements = []
	for element in array:
		if not element in unique_elements:
			unique_elements.append(element)
		
	return unique_elements	

func check_array(tile_array, additional_check = true, piece = null):
	var coord_tiles_local = Array()
	
	for tile in tile_array:
		if tile == tile_array[0] and additional_check or check_movement(tile):
			coord_tiles_local.append(tile)
			
		elif piece and tile in chessmen_coords and piece.color != chessmen_coords[tile].color:
			coord_tiles_local.append(tile)
			break
			
		else:
			break
			
	return coord_tiles_local
	
func check_movement(new_position):
	if new_position in coord_tiles and not new_position in chessmen_coords:
		return true
	else:
		return false
