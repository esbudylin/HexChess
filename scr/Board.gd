extends TileMap

var tile_colors = Dictionary()

var fifty_moves_counter = 0

onready var mapping = $Movement/Mapping

onready var promotion_tiles = $Movement.delete_duplicates(
	mapping.draw_diagonal_line(Vector2(0, -5), 5, 1, 1)
	+ mapping.draw_diagonal_line(Vector2(0, -5), 5, -1, 1)
	+ mapping.draw_diagonal_line(Vector2(0, 5), 5, 1, -1)
	+ mapping.draw_diagonal_line(Vector2(0, 5), 5, -1, -1)) 

onready var verticals_1 = mapping.draw_diagonal_line(Vector2(-5, -3), 5, 1, -1)
onready var verticals_2 = mapping.draw_diagonal_line(Vector2(5, -3), 4, -1, -1)

func draw_map():
	set_verticals(verticals_1)
	set_verticals(verticals_2)

func set_verticals(tile_array):
	var tilenumbers = [0, 1, 2]
	var index = 0
	for vertical in tile_array:
		var tile = vertical
		var i = 0
		var index_while = index
		
		while tile in $Movement.coord_tiles:
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
		$Movement.kings[piece.color] = piece
	
	$Movement.chessmen_list.append(piece)
	$Movement.chessmen_coords[tile_position] = piece

func place_type_of_pieces(type, tiles):
	for tile in tiles:
		var piece_copy = type.duplicate()
		add_piece(piece_copy, tile, type.name)

func place_pieces():
	var pieces_places = {
	$Piece/King: mapping.king_tiles,
	$Piece/Queen: mapping.queen_tiles,
	$Piece/Rook: mapping.rook_tiles,
	$Piece/Bishop: mapping.bishop_tiles,
	$Piece/Knight: mapping.knight_tiles,
	$Piece/Pawn: $Movement.initial_pawn_tiles_black + $Movement.initial_pawn_tiles_white
	}
	
	for type in pieces_places:
		place_type_of_pieces(type, pieces_places[type])
	
	if mapping.chess_type == 'McCooey': #these pawns aren't allowed to double-jump in McCooey version
		$Movement.initial_pawn_tiles_black.erase(Vector2(0, -2))
		$Movement.initial_pawn_tiles_white.erase(Vector2(0, 2))

func kill_piece(NPC):
	NPC.visible = false
	$Movement.chessmen_list.erase(NPC)
	$Movement.chessmen_coords.erase(NPC.tile_position)
	fifty_moves_counter = 0

func move_piece(piece, new_position):
	$Movement.chessmen_coords.erase(piece.tile_position)			
	piece.position = map_to_world(new_position)
	piece.tile_position = new_position
	$Movement.chessmen_coords[new_position] = piece

func promote_pawn(pawn, promotion):
	kill_piece(pawn)
	var new_piece = get_node("Piece/"+promotion).duplicate()
	add_piece(new_piece, pawn.tile_position, promotion, pawn.color)

func check_checkmate_stalemate(turn):
	for tile_piece in $Movement.chessmen_coords:
		if $Movement.chessmen_coords[tile_piece].color == turn\
		and $Movement.check_possible_moves($Movement.chessmen_coords[tile_piece]) != []:
			return false
	
	if if_king_checked(turn):
		return 'checkmated'
	else:
		return 'stalemated'

func if_able_to_checkmate(color):
	var pieces_dict = {'Knight': 0, 'Bishop': 0}
	var bishops = Array()
	
	for piece in $Movement.chessmen_list:
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

func if_king_checked(turn):
	var king = $Movement.kings[turn]

	for piece in $Movement.chessmen_list:
		if king.tile_position in $Movement.find_possible_moves(piece, piece.tile_position):
			return true
			
	return false
