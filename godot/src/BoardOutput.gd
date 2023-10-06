extends TileMap

var reverse
var tile_colors

onready var piece_scr = preload('res://src/Piece.gd')

func place_pieces(placement = get_parent().Board.get_current_position()):
	for c in get_children(): c.queue_free()
	
	for position in placement:
		add_piece(position.chessman, position.coords, position.color)

func add_piece(type, position, color):
	var piece = get_node("../Chessmen/"+type).duplicate()
	piece.set_script(piece_scr)
	add_child(piece)
	
	piece.visible = true
	piece.tile_position = position
	
	if color == 'black':
		piece.get_child(0).visible = true
	elif color == 'white':
		piece.get_child(1).visible = true

func draw_map():	
	for color in tile_colors:
		for tile in tile_colors[color]:
			if reverse:
				var reversed_tile = mirror_tile(tile)
				set_cell(reversed_tile[0], reversed_tile[1], color)
			else:
				set_cell(tile[0], tile[1], color)

func mirror_tile(tile):
	if int(tile[0])%2:
		return Vector2(tile[0], -tile[1]-1)
	else:
		return Vector2(tile[0], -tile[1])

func world_to_map(position):
	if reverse:
		return mirror_tile(.world_to_map(position))
	else:
		return .world_to_map(position)

func set_cells(set_tiles, tile_number):
	for tile in set_tiles:
		set_cell(tile[0], tile[1], tile_number)

func draw_possible_moves():
	var range_of_movement = get_parent().range_of_movement
	
	if reverse:
		var reversed_range = Array()
		
		for tile in range_of_movement:
			reversed_range.append(mirror_tile(tile))
			
		set_cells(reversed_range, 4)
		
	else:
		set_cells(range_of_movement, 4)
