extends Node

func save_game():
	var game_notation = notation_to_string()
		
	var date = Time.get_date_string_from_system()
	var time = Time.get_time_string_from_system()
# warning-ignore:return_value_discarded
	var dir = Directory.new()
	var path = OS.get_executable_path().get_base_dir().plus_file("saves")

	dir.make_dir(path)

	var save_path = path + '/' + date + "_" + time.replace(":", "-") + ".pgn"
	
	var save_string = String()
	save_string += make_tag("Variant", $'../Game'.Board.Mapping.chess_type) 
	save_string += "\n" + game_notation

	var file = File.new()
	file.open(save_path, File.WRITE)
	file.store_string(save_string)
	file.close()

func notation_to_string():
	var result = String()
	var game_notation = $'../NotationOutput'.game_notation
	
	for half_turn_number in game_notation.keys():
		if not half_turn_number % 2:
			result += str(half_turn_number / 2 + 1)
			result += ". "
			
		result += game_notation[half_turn_number]
		result += " "
	
	return result
	
func make_tag(name, value):
	return "[" + name + ' "' + value + '"]' + "\n"

func _on_SaveGame_pressed():
	save_game()
	
	var button_nodes = [$'../Game/HUD/EndGame/SaveGame', 
					$'../Game/HUD/NotationPanel/SaveLoad/SaveGame']
					
	for button in button_nodes:
		if button.visible:
			var timer = Timer.new()
			timer.connect("timeout",self,"scratch_anouncement", [button, button.text])
			timer.wait_time = 1
			timer.one_shot = true
			add_child(timer)

			button.disabled = true
			button.text = 'game saved!'
			timer.start()
			
func scratch_anouncement(button, text):
	button.text = text
	button.disabled = false
