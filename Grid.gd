extends TileMap

var coord_tiles

var white_turn = true
var npc_list = Array()

func _ready():
	coord_tiles = $Mapping.regular_hexagon(0, 0)
	coord_tiles = delete_duplicates(coord_tiles)
	set_cells (coord_tiles, 1)

func set_cells (set_tiles, tile_number):
	for tile in set_tiles:
		set_cell(tile[0], tile[1], tile_number)

func add_piece (piece, tile_position):
	add_child(piece)
		
	piece.tile_position = tile_position
	piece.position = map_to_world(piece.tile_position)
	piece.visible = true
	
	if tile_position[1] < 0:
		piece.get_child(0).visible = true
		piece.color = 'black'
	else:
		piece.get_child(1).visible = true
		piece.color = 'white'
		
	npc_list.append(piece)
	
func place_bishops ():
	var tiles = [-5, -4, -3, 3, 4, 5]
	
	for tile in tiles:
		var piece_copy = $Piece/Bishop.duplicate()
		add_piece (piece_copy, Vector2 (0, tile))
		
func place_knights ():
	var tiles = [Vector2 (-2, -4), Vector2 (2, -4), Vector2 (-2, 4), Vector2 (2, 4)]
	
	for tile in tiles:
		var piece_copy = $Piece/Knight.duplicate()
		add_piece (piece_copy, tile)
		
func place_rooks ():
	var tiles = [Vector2 (-3, -4), Vector2 (3, -4), Vector2 (-3, 3), Vector2 (3, 3)]
	
	for tile in tiles:
		var piece_copy = $Piece/Rook.duplicate()
		add_piece (piece_copy, tile)

func place_pawns ():
	var tiles = delete_duplicates($Mapping.draw_diagonal_line(Vector2(0, 1), 4, 1, 1)+$Mapping.draw_diagonal_line(Vector2(0, 1), 4, -1, 1))
	tiles += delete_duplicates($Mapping.draw_diagonal_line(Vector2(0, -1), 4, 1, -1)+$Mapping.draw_diagonal_line(Vector2(0, -1), 4, -1, -1))
	
	for tile in tiles:
		var piece_copy = $Piece/Pawn.duplicate()
		add_piece (piece_copy, tile)

func place_pieces ():
	place_bishops()
	place_knights()
	place_rooks()
	place_pawns ()
	
func npc_coord (npc_list_local = npc_list):
	var npc_coord_list = Array ()
	
	for NPC in npc_list_local:
		npc_coord_list.append(NPC.tile_position)
		
	return npc_coord_list
	
func check_movement (new_position):
	if new_position in coord_tiles and not new_position in npc_coord(npc_list):
		return true
	else:
		return false

func check_array (tile_array, additional_check = true):
	var coord_tiles_local = Array()
	
	for tile in tile_array:
		if check_movement(tile) or tile == tile_array[0] and additional_check:
			coord_tiles_local.append (tile)
		else:
			break
			
	return coord_tiles_local

func npc_die (NPC):
	NPC.visible = false
	npc_list.erase(NPC)
	
func rook_movement (position):
	var coord_tiles_local = []
	var diagonals = [[1, 1], [1, -1], [-1, 1], [-1, -1]]
	
	for diagonal in diagonals:
		coord_tiles_local+=check_array($Mapping.draw_diagonal_line (position, 11, diagonal[0], diagonal[1]))
	
	coord_tiles_local+=check_array($Mapping.draw_vertical_line (position, 12))
	coord_tiles_local+=check_array($Mapping.draw_vertical_line (position, 12, -1))

	coord_tiles_local = delete_duplicates(coord_tiles_local)
	
	return coord_tiles_local

func bishop_diagonal (position, x, y, z = 1):
	var coord_tiles_local = []
	var current_tile = position
	
	for iteration in 5:
		if int(current_tile[0])%2!=0:
			current_tile[1] +=x
		else:
			current_tile[1] +=y
			
		current_tile[0] += z
		coord_tiles_local+= [current_tile]
	
	return coord_tiles_local

func bishop_movement (position):
	var coord_tiles_local = []
	var horizontal1 = []
	var horizontal2 = []
	
	for iteration in 5:
		horizontal1 += [Vector2(position[0]+iteration*2, position[1])]
		horizontal2 += [Vector2(position[0]-iteration*2, position[1])]
		
	coord_tiles_local += check_array(horizontal1)+check_array(horizontal2)
	
	var diagonals = [[2, 1, 1], [-1, -2, 1], [2, 1, -1], [-1, -2, -1]]
	
	for diagonal in diagonals:
		coord_tiles_local+=check_array(bishop_diagonal(position, diagonal[0], diagonal[1], diagonal[2]), false)
	
	coord_tiles_local = delete_duplicates(coord_tiles_local)
	return coord_tiles_local

func knight_movement (position):
	var coord_tiles_local = [position]
	var moves = Array ()
	
	if int(position[0])%2==0:
		moves = [[-1, -2], [-2, -2], [1, -2], [2, -2], [3, 0], [3, 1], [2, 2], [1, 3], [-1, 3], [-2, 2], [-3, 1], [-3, 0]]
	else:
		moves = [[1, -3], [2, -2], [-1, -3], [-2, -2], [3, -1], [3, 0], [-3, -1], [-3, 0], [-2, 2], [-1, 2], [1, 2], [2, 2]]
		
	for move in moves:
		var tile = (Vector2(position[0]-move[0], position[1]-move[1]))
		if check_movement(tile):
			coord_tiles_local.append (tile)
	
	return coord_tiles_local

func pawn_movement (position):
	var coord_tiles_local = []
	
	for tile in $Mapping.find_closest_tiles(position):
		if check_movement(tile):
			coord_tiles_local.append (tile)
			
	return coord_tiles_local
	
func delete_duplicates (array):
	var elements = []
	for element in array:
		
		if element in elements:
			array.erase(element)
			continue
			
		elements.append (element)
		
	return array

func find_possible_moves (NPC, position):
	var range_of_movement = Array ()
	
	if "Pawn" in NPC.name:
		range_of_movement = pawn_movement(position)
		
	elif "Knight" in NPC.name:
		range_of_movement = knight_movement(position)
		
	elif "Bishop" in NPC.name:
		range_of_movement = bishop_movement(position)
	
	elif "Rook" in NPC.name:
		range_of_movement = rook_movement(position)
	
	return range_of_movement

