extends "res://scr/Mapping.gd"

var mapped_tiles = Dictionary()
var current_move

var piece_notation = {"Pawn": "", "Knight": "N", "Bishop": "B",
					"Rook": "R", "Queen": "Q", "King": "K"}

class Move:
	var old_position
	var new_position
	var moved_piece
	var capture
	var promotion
	var checkmated
	var ambiguity
	
	func _init(moved_piece, new_position):
		self.old_position = moved_piece.tile_position
		self.new_position = new_position
		self.moved_piece = moved_piece

func _ready():
	map_tiles()

func map_tiles():
	var letters = 'abcdefghijk'
	
	var verticals = draw_diagonal_line(Vector2(-5, 2), 4, 1, 1)\
	+ draw_diagonal_line(Vector2(0, 5), 5, 1, -1)
	
	var length = 6
	var peaked = false
	var i = 0
	
	for vertical in verticals:
		if length == 11: peaked = true
		var letter = letters[i]
		
		var i_vertical = 1
		for tile in draw_vertical_line(vertical, length, -1):
			mapped_tiles[tile] = letter + str(i_vertical)
			i_vertical += 1
		
		i+=1
		if peaked: length-=1
		else: length+=1

func notate():
	var result = piece_notation[current_move.moved_piece.type]
	
	match current_move.ambiguity:
		0: pass
		1: result += mapped_tiles[current_move.old_position][0]
		2: result += mapped_tiles[current_move.old_position][1]
		3: result += mapped_tiles[current_move.old_position]
	
	if current_move.capture:
		if current_move.moved_piece.type == 'Pawn':
			result = result.insert(1, 'x')
		else:
			result += 'x'
			
	result += mapped_tiles[current_move.new_position]

	if current_move.promotion:
		result += "=" + piece_notation[current_move.promotion]
		
	if current_move.checkmated:
		result += "#"
		return result
		
	if $"../Game".Board.if_king_checked(current_move.moved_piece):
		result += "+"
	
	return result

func check_ambiguity():
	if current_move.moved_piece.type == 'King':
		current_move.ambiguity = 0
		return
		
	if current_move.moved_piece.type == 'Pawn':
		if current_move.capture: current_move.ambiguity = 1
		else: current_move.ambiguity = 0
		return
	
	var same_letter
	var same_number
	var ambiguity
	
	for piece in $"../Game".Board.chessmen_by_color_by_type[current_move.moved_piece.color][current_move.moved_piece.type]:
		if piece != current_move.moved_piece:
			if current_move.new_position in $"../Game".Board.find_possible_moves(piece):
				ambiguity = true
				
				if not same_letter:
					same_letter = mapped_tiles[piece.tile_position][0] == mapped_tiles[current_move.old_position][0]
				if not same_number:
					same_number = mapped_tiles[piece.tile_position][1] == mapped_tiles[current_move.old_position][1]
				
				if same_letter and same_number:
					break
				
	if not ambiguity:
		current_move.ambiguity = 0		
	elif same_letter and same_number:
		current_move.ambiguity = 3		
	elif same_letter:
		current_move.ambiguity = 2
	else:
		current_move.ambiguity = 1
