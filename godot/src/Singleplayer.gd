extends Node

onready var gs = $"../Game"

onready var chessmen_values = get_node('/root/PlayersData').get_chessmen_values()

func prepare_game():
	$'../Game/HUD/BackPanel'.visible = true
	$'../Game/HUD/RewindBox'.visible = true
	$'../Game/HUD/AIPanel'.visible = true
	
# warning-ignore:return_value_discarded
	$'../Game/HUD/RewindBox/Undo'.connect('pressed', self, '_on_Rewind_pressed', [-1])
# warning-ignore:return_value_discarded
	$'../Game/HUD/RewindBox/Redo'.connect('pressed', self, '_on_Rewind_pressed', [1])
	
	gs.prepare_game()
	gs.Board.set_negamax(chessmen_values)

func _on_TryAgain_pressed():
# warning-ignore:return_value_discarded	
	get_tree().reload_current_scene()

func _on_Exit_pressed():
# warning-ignore:return_value_discarded	
	get_tree().change_scene("res://scenes/menu.tscn")
	
func _on_BackPanel_pressed():
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://scenes/menu.tscn")

func _on_Rewind_pressed(index):
	rewind_game(gs.Board.get_current_turn_index() + index)

func rewind_game(turn_index):
	gs.range_of_movement = []
	
	gs.Board.set_current_turn_index(turn_index)
	
	gs.tilemap.place_pieces()
	gs.tilemap.draw_map()
	
	set_Redo_button()
	set_Undo_button()
	
	$'../NotationOutput'.highlight_current_move(turn_index-1)
	
func set_Undo_button():
	if gs.Board.get_current_turn_index()!=0:
		$'../Game/HUD/RewindBox/Undo'.set_disabled(false)
	else:
		$'../Game/HUD/RewindBox/Undo'.set_disabled(true)

func set_Redo_button():
	if gs.Board.get_current_turn_index()!=gs.Board.history_length()-1:
		$'../Game/HUD/RewindBox/Redo'.set_disabled(false)
	else:
		$'../Game/HUD/RewindBox/Redo'.set_disabled(true)
