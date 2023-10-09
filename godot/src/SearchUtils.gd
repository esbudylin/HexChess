extends Node

onready var white = $"../HUD/AIPanel/VBoxContainer/Colors/White"
onready var black = $"../HUD/AIPanel/VBoxContainer/Colors/Black"
onready var search_depth = $"../HUD/AIPanel/VBoxContainer/Depth/SearchDepth"
onready var status = $"../HUD/AIPanel/Status"

var computer_move_thread = Thread.new()

func _ready():
	white.connect("pressed", self, "_color_update")
	black.connect("pressed", self, "_color_update")

func get_computer_colors():
	var computer_colors = []
	
	if white.pressed:
		computer_colors.append('white')
	if black.pressed:
		computer_colors.append('black')
	
	return computer_colors

func start_computer_move():
	get_parent().clickable = false
	computer_move_thread = Thread.new()
	status.text = 'Opponent is thinking'
	computer_move_thread.start(self, "_make_computer_move", search_depth.value)

func _make_computer_move(depth):
	var new_move = get_parent().Board.make_computer_move(depth)
		
	call_deferred("_computer_move_done", new_move)
	
func _computer_move_done(new_move):
	computer_move_thread.wait_to_finish()
	
	get_parent().set_rewind_buttons()
	
	if new_move:
		get_parent().update_game(new_move[0], new_move[1], new_move[2])
	
		if get_parent().current_color in get_computer_colors() \
		and not get_parent().Board.check_for_game_over():
			start_computer_move()

		else:
			status.text = 'Opponent is ready'
			get_parent().clickable = true

func _color_update():
	var tilemap = get_parent().tilemap
	
	if not computer_move_thread.is_alive() and get_parent().current_color in get_computer_colors():
		start_computer_move()
		
	if get_computer_colors() == ['white']:
		tilemap.reverse = true
	else:
		tilemap.reverse = false
	
	tilemap.draw_map()
	tilemap.place_pieces()
