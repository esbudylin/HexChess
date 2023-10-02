extends Node

var coords_to_notation := Dictionary()
var notation_to_coords := Dictionary()

var current_move

const piece_notation = {"Pawn": "", "Knight": "N", "Bishop": "B",
					"Rook": "R", "Queen": "Q", "King": "K"}

class Move:
	var old_position
	var new_position
	var moved_piece
	var capture
	var promotion
	var checkmated
	var ambiguity
	
	func _init(moved_piece, new_position, promotion, capture):
		self.old_position = moved_piece.tile_position
		self.new_position = new_position
		self.moved_piece = moved_piece
		self.promotion = promotion
		self.capture = capture

func map_tiles():
	for tile in $"../Game".Board.get_notation_map():
		coords_to_notation[tile.coords] = tile.notation
		notation_to_coords[tile.notation] = tile.coords

func notate():
	var result = piece_notation[current_move.moved_piece.ctype]

	match current_move.ambiguity:
		0: pass
		1: result += coords_to_notation[current_move.old_position][0]
		2: result += coords_to_notation[current_move.old_position][1]
		3: result += coords_to_notation[current_move.old_position]
	
	if current_move.capture:
		if current_move.moved_piece.ctype == 'Pawn':
			result = result.insert(1, 'x')
		else:
			result += 'x'
			
	result += coords_to_notation[current_move.new_position]

	if current_move.promotion:
		result += "=" + piece_notation[current_move.promotion]
		
	if current_move.checkmated:
		result += "#"
		return result
		
	if $"../Game".Board.is_king_checked():
		result += "+"
	
	return result

func check_ambiguity():
	if current_move.moved_piece.ctype == 'King':
		current_move.ambiguity = 0
		return
		
	if current_move.moved_piece.ctype == 'Pawn':
		if current_move.capture: current_move.ambiguity = 1
		else: current_move.ambiguity = 0
		return
	
	var same_letter
	var same_number
	var ambiguity
	
	for piece in $"../Game".Board.check_ambiguity_util():
		ambiguity = true
		
		if not same_letter:
			same_letter = coords_to_notation[piece][0] == coords_to_notation[current_move.old_position][0]
		if not same_number:
			same_number = coords_to_notation[piece][1] == coords_to_notation[current_move.old_position][1]
		
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
