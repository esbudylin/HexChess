extends TileMap

var npc_list = Array()

var jumped_over_tiles = Dictionary ()
var passable_tiles = Dictionary ()

onready var initial_pawn_tiles_white = delete_duplicates(\
$Mapping.draw_diagonal_line(Vector2(0, 1), 4, 1, 1)\
+$Mapping.draw_diagonal_line(Vector2(0, 1), 4, -1, 1))

onready var initial_pawn_tiles_black = delete_duplicates(\
$Mapping.draw_diagonal_line(Vector2(0, -1), 4, 1, -1)\
+$Mapping.draw_diagonal_line(Vector2(0, -1), 4, -1, -1))

onready var promotion_tiles = delete_duplicates(\
$Mapping.draw_diagonal_line(Vector2(0, -5), 5, 1, 1)\
+$Mapping.draw_diagonal_line(Vector2(0, -5), 5, -1, 1)\
+$Mapping.draw_diagonal_line(Vector2(0, 5), 5, 1, -1)\
+$Mapping.draw_diagonal_line(Vector2(0, 5), 5, -1, -1)) 

onready var coord_tiles = $Mapping.regular_hexagon(0, 0)

func _ready():
	set_cells (coord_tiles, 1)

func set_cells (set_tiles, tile_number):
	for tile in set_tiles:
		set_cell(tile[0], tile[1], tile_number)

func add_piece (piece, tile_position, color = null):
	add_child(piece)
		
	piece.tile_position = tile_position
	piece.position = map_to_world(piece.tile_position)
	piece.visible = true
	
	if color == 'black' or color == null and tile_position[1] < 0:
		piece.get_child(0).visible = true
		piece.color = 'black'
	elif color == 'white' or color == null and tile_position[1] > 0:
		piece.get_child(1).visible = true
		piece.color = 'white'
		
	npc_list.append(piece)

func place_type_of_pieces (type, tiles):
	for tile in tiles:
		var piece_copy = type.duplicate()
		add_piece (piece_copy, tile)

func place_pieces ():
	var pieces_places = {
	$Piece/King: $Mapping.king_tiles,\
	$Piece/Queen: $Mapping.queen_tiles,\
	$Piece/Rook: $Mapping.rook_tiles,\
	$Piece/Bishop: $Mapping.bishop_tiles,\
	$Piece/Knight: $Mapping.knight_tiles,\
	$Piece/Pawn: initial_pawn_tiles_black + initial_pawn_tiles_white
	}
	
	for type in pieces_places:
		place_type_of_pieces (type, pieces_places[type])
	
func npc_coord (npc_list_local = npc_list):
	var npc_coord_list = Dictionary ()
	
	for NPC in npc_list_local:
		npc_coord_list[NPC.tile_position] = NPC
		
	return npc_coord_list
	
func check_movement (new_position):
	if new_position in coord_tiles and not new_position in npc_coord(npc_list):
		return true
	else:
		return false

func check_array (tile_array, additional_check = true, piece = null):
	var coord_tiles_local = Array()
	
	for tile in tile_array:
		if check_movement(tile) or tile == tile_array[0] and additional_check:
			coord_tiles_local.append (tile)
			
		elif piece != null and tile in npc_coord() and piece.color != npc_coord()[tile].color:
			coord_tiles_local.append (tile)
			break
			
		else:
			break
			
	return coord_tiles_local

func npc_die (NPC):
	NPC.visible = false
	npc_list.erase(NPC)
	
func rook_movement (NPC, position, iterations = 12):
	var coord_tiles_local = []
	var diagonals = [[1, 1], [1, -1], [-1, 1], [-1, -1]]
	
	for diagonal in diagonals:
		coord_tiles_local+=check_array(\
		$Mapping.draw_diagonal_line (position, iterations-1, diagonal[0], diagonal[1]), true, NPC)
	
	coord_tiles_local+=check_array($Mapping.draw_vertical_line (position, iterations), true, NPC)
	coord_tiles_local+=check_array($Mapping.draw_vertical_line (position, iterations, -1), true, NPC)

	coord_tiles_local = delete_duplicates(coord_tiles_local)
	
	return coord_tiles_local

func bishop_movement (NPC, position, iterations = 5):
	var coord_tiles_local = []
	var horizontal1 = []
	var horizontal2 = []
	
	for iteration in iterations+1:
		horizontal1 += [Vector2(position[0]+iteration*2, position[1])]
		horizontal2 += [Vector2(position[0]-iteration*2, position[1])]
		
	coord_tiles_local += check_array(horizontal1, true, NPC)+check_array(horizontal2, true, NPC)
	
	var diagonals = [[2, 1, 1], [-1, -2, 1], [2, 1, -1], [-1, -2, -1]]
	
	for diagonal in diagonals:
		coord_tiles_local+=check_array(\
		$Mapping.bishop_diagonal(position, diagonal[0], diagonal[1], diagonal[2], iterations), false, NPC)
	
	coord_tiles_local = delete_duplicates(coord_tiles_local)
	return coord_tiles_local

func knight_movement (piece, position):
	var coord_tiles_local = [position]
	var moves = Array ()
	
	if int(position[0])%2==0:
		moves = [[-1, -2], [-2, -2], [1, -2], [2, -2], [3, 0], [3, 1],\
		 [2, 2], [1, 3], [-1, 3], [-2, 2], [-3, 1], [-3, 0]]
	else:
		moves = [[1, -3], [2, -2], [-1, -3], [-2, -2], [3, -1],\
		 [3, 0], [-3, -1], [-3, 0], [-2, 2], [-1, 2], [1, 2], [2, 2]]
		
	for move in moves:
		var tile = (Vector2(position[0]-move[0], position[1]-move[1]))
		if check_movement(tile) or tile in npc_coord() and npc_coord()[tile].color != piece.color:
			coord_tiles_local.append (tile)
	
	return coord_tiles_local

func pawn_movement (pawn, position):
	var coord_tiles_local = []
	
	if pawn.color == 'black' and position in initial_pawn_tiles_black:
		coord_tiles_local += check_array($Mapping.draw_vertical_line(position, 3))
	
	elif pawn.color == 'black':
		coord_tiles_local += check_array($Mapping.draw_vertical_line(position, 2))
	
	elif pawn.color == 'white' and position in initial_pawn_tiles_white:
		coord_tiles_local += check_array($Mapping.draw_vertical_line(position, 3, -1))
	
	else:
		coord_tiles_local += check_array($Mapping.draw_vertical_line(position, 2, -1))
	
	if delete_duplicates(coord_tiles_local).size () == 3:
		passable_tiles[delete_duplicates(coord_tiles_local)[1]] = pawn
	
	return delete_duplicates(coord_tiles_local) + pawn_attack(pawn, position)

func pawn_attack (pawn, position, check = true):
	var coord_tiles_local = []
	var closest_tiles = $Mapping.find_closest_tiles(position)
	var attack_tiles = []
	
	if pawn.color == 'white':
		if int(position[0])%2!=0:
			attack_tiles += [closest_tiles[3], closest_tiles[1]]
		else:
			attack_tiles += [closest_tiles[0], closest_tiles[4]]
	
	else:
		if int(position[0])%2!=0:
			attack_tiles += [closest_tiles[0], closest_tiles[4]]
		else:
			attack_tiles += [closest_tiles[3], closest_tiles[1]]
	
	if check == true:
		for tile in attack_tiles:
			if tile in npc_coord():
				var piece = npc_coord()[tile]
				if piece.color != pawn.color:
					coord_tiles_local.append (tile)
					
			elif tile in jumped_over_tiles and jumped_over_tiles[tile].color != pawn.color:
				coord_tiles_local.append (tile)
	else:
		coord_tiles_local = attack_tiles

	return coord_tiles_local
	
func king_movement (king, position):
	var initial = delete_duplicates(\
	rook_movement(king, position, 2) + bishop_movement(king, position, 1))
	
	var coord_tiles_local = initial.duplicate()
	npc_list.erase(king)
	
	for tile in initial:
		for piece in npc_list:
			
			if piece.color != king.color and not 'Pawn' in piece.name and not 'King' in piece.name:
				if tile in find_possible_moves(piece, piece.tile_position):
					coord_tiles_local.erase (tile)
					
			elif piece.color != king.color and 'King' in piece.name:
				if tile in delete_duplicates(rook_movement(piece, piece.tile_position, 2)\
				 + bishop_movement(piece, piece.tile_position, 1)):
					coord_tiles_local.erase (tile)
					
			elif piece.color != king.color and 'Pawn' in piece.name:
				if tile in pawn_attack(piece, piece.tile_position, false):
					coord_tiles_local.erase (tile)
	
	npc_list.append(king)
	return coord_tiles_local

func promote_pawn (pawn, promotion):
	npc_die(pawn)
	var new_piece = get_node("Piece/"+promotion).duplicate()
	add_piece(new_piece, pawn.tile_position, pawn.color)
	
func delete_duplicates (array):
	var unique_elements = []
	for element in array:
		if not element in unique_elements:
			unique_elements.append(element)
		
	return unique_elements

func clean_up_jumped_over (color):
	for tile in jumped_over_tiles.keys():
		if jumped_over_tiles[tile].color == color:
			jumped_over_tiles.erase(tile)

func check_checkmate_stalemate (turn):
	var iteration = 0
	
	for tile_piece in npc_coord():
		if npc_coord()[tile_piece].color == turn\
		and check_check(npc_coord()[tile_piece]) != []:
			break
		iteration +=1
	
	if iteration == npc_coord().size():
		if if_king_checked (turn):
			return 'checkmated'
		else:
			return 'stalemated'
	else:
		return false

func find_king (color):
	for piece in npc_list:
		if 'King' in piece.name and piece.color == color:
			return piece

func if_king_checked (turn):
	var king = find_king (turn)
	var checked = false
	for piece in npc_list:
		if king.tile_position in find_possible_moves (piece, piece.tile_position):
			checked = true
			break
	return checked

func check_check (NPC, range_of_movement = null):
	var initial_position = NPC.tile_position
	var king = find_king (NPC.color)
	
	if range_of_movement == null:
		range_of_movement = find_possible_moves(NPC, NPC.tile_position)
			
	for tile in range_of_movement.duplicate():
		NPC.tile_position = tile
		for tile_piece in npc_coord():
			if npc_coord()[tile_piece].color != NPC.color\
			and king.tile_position in find_possible_moves(npc_coord()[tile_piece], tile_piece):
				range_of_movement.erase (tile)
	
	NPC.tile_position = initial_position
	
	return range_of_movement
	
func find_possible_moves (NPC, position):
	var range_of_movement = Array ()
	
	if "Pawn" in NPC.name:
		range_of_movement = pawn_movement(NPC, position)
		
	elif "Knight" in NPC.name:
		range_of_movement = knight_movement(NPC, position)
		
	elif "Bishop" in NPC.name:
		range_of_movement = bishop_movement(NPC, position)
	
	elif "Rook" in NPC.name:
		range_of_movement = rook_movement(NPC, position)
		
	elif "Queen" in NPC.name:
		range_of_movement = delete_duplicates(bishop_movement(NPC, position)\
		+rook_movement(NPC, position))
	
	elif "King" in NPC.name:
		range_of_movement = king_movement(NPC, position)
	
	range_of_movement.erase (position)
	return range_of_movement

