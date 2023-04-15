extends Node

onready var scroll_container = $"../Game/HUD/NotationPanel/ScrollContainer"
onready var scrollbar = scroll_container.get_v_scrollbar()

onready var output_container = $"../Game/HUD/NotationPanel/ScrollContainer/VBoxContainer"
onready var turn_output = $"../Game/HUD/NotationPanel/ScrollContainer/VBoxContainer/TurnContainer"
onready var initial_output = turn_output.duplicate()

var current_output

var game_notation = Dictionary()

var record_nodes = Dictionary()
var highlighted_node_idx

var scroll_locked

func _ready():
	turn_output.queue_free()
	scrollbar.connect("changed", self, "_on_Scroll_changed")

func update_notation(half_turn, new_record = null):
	var child_idx
	
	if not new_record:
		new_record = $"../Notation".notate()

	if not half_turn%2:
		current_output = initial_output.duplicate()
		output_container.add_child(current_output)
		current_output.get_child(0).text = str(half_turn/2+1)
		child_idx = 1
		scroll_locked = true
		
	else:
		child_idx = 2
		scroll_container.scroll_vertical  = scrollbar.max_value
	
	var record_node = current_output.get_child(child_idx)
	record_node.bbcode_text = new_record
	
	if not $"../Game".is_multiplayer:
		record_node.connect('gui_input', self, '_on_Turn_gui_input', [half_turn+1])
		record_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		record_nodes[half_turn] = record_node
		
	game_notation[half_turn] = new_record

func highlight_current_move(move_idx):
	if move_idx != -1:
		var record_node = record_nodes[move_idx]
		record_node.bbcode_text = "[u]%s[/u]" % record_node.bbcode_text

	if highlighted_node_idx in record_nodes and highlighted_node_idx != move_idx:
		record_nodes[highlighted_node_idx].bbcode_text = game_notation[highlighted_node_idx]
		
	highlighted_node_idx = move_idx
	
func clean_output(): 
	for i in output_container.get_children(): i.queue_free()

func adjust_notation():
	var half_turn = $'../Game'.Board.current_turn_index - 1
	var clean_up = len(game_notation)-half_turn

	if not clean_up: return
	
	clean_output()
	
	for key in game_notation.keys().slice(half_turn, -1):
		game_notation.erase(key)
	
	for key in game_notation.duplicate():
		update_notation(key, game_notation[key])

func _on_Turn_gui_input(event, half_turn):
	if event is InputEventMouseButton and event.pressed\
	and event.button_index == 1 and $"../Game".clickable:
		$"../Singleplayer".rewind_game(half_turn)

func _on_Scroll_changed():
	if scroll_locked:
		scroll_container.scroll_vertical  = scrollbar.max_value
		scroll_locked = false
