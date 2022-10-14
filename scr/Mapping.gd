extends Node

var knight_tiles = Array()
var rook_tiles = Array()
var king_tiles = Array()
var queen_tiles = Array()
var bishop_tiles = Array()

var black_pawn_tiles = Array ()
var white_pawn_tiles = Array ()
 
onready var chess_type = get_node('/root/PlayersData').chess_type

func _ready():
	place_chessmen ()

func regular_hexagon(center_position_x, center_position_y):
	var coord_tiles = find_tiles_in_range (Vector2(center_position_x, center_position_y), 5)
				
	return coord_tiles

func find_closest_tiles (position):
	var closest_tiles = Array()
	
	if int(position[0])%2!=0:
		closest_tiles += [Vector2(position[0]+1, position[1]+1), \
		Vector2(position[0]+1, position[1]), \
		Vector2(position[0], position[1]-1), \
		Vector2(position[0]-1, position[1]), \
		Vector2(position[0]-1, position[1]+1), \
		Vector2(position[0], position[1]+1)]

	else:
		closest_tiles += [Vector2(position[0]+1, position[1]-1), \
		Vector2(position[0]+1, position[1]), \
		Vector2(position[0], position[1]-1), \
		Vector2(position[0]-1, position[1]), \
		Vector2(position[0]-1, position[1]-1), \
		Vector2(position[0], position[1]+1)]	
	
	return closest_tiles

func in_range_utility (position, tiles_in_range):
	for tile in find_closest_tiles (position):
		
		if not tile in tiles_in_range:
			tiles_in_range.append(tile)
			
	return tiles_in_range

func find_tiles_in_range (position, in_range):
	var tiles_in_range = Array()
	
	tiles_in_range = in_range_utility(position, tiles_in_range) 
	
	for _i in range (in_range-1):
		for tile in tiles_in_range.duplicate():
			tiles_in_range = in_range_utility(tile, tiles_in_range) 
	
	return tiles_in_range
	
func draw_vertical_line (position, length, updown = 1):
	var coord_tiles = Array ()
	coord_tiles.append (position)
	
	for iteration in length:
		coord_tiles.append(Vector2 (position[0],position[1]+iteration*updown))

	return coord_tiles
	
func draw_diagonal_line (position, length, mod, updown):
	var coord_tiles = Array ()
	var current_tile = position
	coord_tiles.append(position)
	
#	mod - left/right direction
#	updown - up/down direction

	for iteration in length:
		if int(current_tile[0])%2!=0:
			current_tile = Vector2 (current_tile[0]+mod,current_tile[1])
			if updown == 1:
				current_tile[1]+=updown
		else:
			current_tile = Vector2 (current_tile[0]+mod,current_tile[1])
			if updown == -1:
				current_tile[1]+=updown
				
		coord_tiles.append(current_tile)

	return coord_tiles

func bishop_diagonal (position, x, y, z = 1, iterations = 5):
	var coord_tiles_local = []
	var current_tile = position
	
	for iteration in iterations:
		if int(current_tile[0])%2!=0:
			current_tile[1] +=x
		else:
			current_tile[1] +=y
			
		current_tile[0] += z
		coord_tiles_local+= [current_tile]
	
	return coord_tiles_local

func place_chessmen ():
	if chess_type == 'Glinski' or chess_type == 'McCooey':
		var tiles = [-5, -4, -3, 3, 4, 5]
		
		for tile in tiles:
			bishop_tiles.append(Vector2 (0, tile))
			
		queen_tiles = [Vector2 (-1, -5), Vector2 (-1, 4)]
		king_tiles = [Vector2 (1, 4), Vector2 (1, -5)]
		
	if chess_type == 'Glinski':
		rook_tiles = [Vector2 (-3, -4), Vector2 (3, -4), Vector2 (-3, 3), Vector2 (3, 3)]
		knight_tiles = [Vector2 (-2, -4), Vector2 (2, -4), Vector2 (-2, 4), Vector2 (2, 4)]
		
		black_pawn_tiles = draw_diagonal_line(Vector2(0, 1), 4, 1, 1)\
		+draw_diagonal_line(Vector2(0, 1), 4, -1, 1)
		
		white_pawn_tiles = draw_diagonal_line(Vector2(0, -1), 4, 1, -1)\
		+draw_diagonal_line(Vector2(0, -1), 4, -1, -1)
		
	elif chess_type == 'McCooey':
		rook_tiles = [Vector2 (-2, -4), Vector2 (2, -4), Vector2 (-2, 4), Vector2 (2, 4)]
		knight_tiles = [Vector2 (-1, -4), Vector2 (1, -4), Vector2 (-1, 3), Vector2 (1, 3)]
		
		black_pawn_tiles = draw_diagonal_line(Vector2(0, 2), 3, 1, 1)\
		+draw_diagonal_line(Vector2(0, 2), 3, -1, 1)
		
		white_pawn_tiles = draw_diagonal_line(Vector2(0, -2), 3, 1, -1)\
		+draw_diagonal_line(Vector2(0, -2), 3, -1, -1)
	
	elif chess_type == 'Hexofen':
		var horizontal_4_black = []
		var horizontal_4_white = []
		
		for iteration in 6:
			black_pawn_tiles += [Vector2(-5+iteration*2, 2)]
			white_pawn_tiles += [Vector2(-5+iteration*2, -3)]
			
		for iteration in 5:
			black_pawn_tiles += [Vector2(-4+iteration*2, 3)]
			white_pawn_tiles += [Vector2(-4+iteration*2, -3)]
			
		for iteration in 4:
			horizontal_4_white += [Vector2(-3+iteration*2, 3)]
			horizontal_4_black += [Vector2(-3+iteration*2, -4)]
		
		knight_tiles = horizontal_4_white.slice(0, 2) + horizontal_4_black.slice(1, 3)
		bishop_tiles = [horizontal_4_white[3], horizontal_4_black[0]]
		
		for iteration in 3:
			var tiles = [Vector2(-2+iteration*2, 4), Vector2(-2+iteration*2, -4)]
			if iteration == 1:
				bishop_tiles.append_array(tiles)
			else:
				rook_tiles.append_array(tiles)
				
		bishop_tiles.append_array([Vector2(1, -5), Vector2(-1, 4)])
		
		queen_tiles = [Vector2(-1, -5), Vector2(1, 4)]
		king_tiles = [Vector2 (0, 5), Vector2 (0, -5)]
