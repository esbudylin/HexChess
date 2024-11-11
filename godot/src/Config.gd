extends Node

const colors = ['white', 'black']

var chessmen_values = {'Queen': 9, 'Rook': 5, 'Knight': 3, 
						'Bishop': 4, 'Pawn': 1, 'King': 10}

var master_color 
var puppet_color 

var peer

var chess_type setget , get_chess_type

var config_path = "res://config.cfg"

func get_chess_type() -> String:
	if not chess_type: 
		chess_type = call_config().get_value('options', 'chess_type', 'Glinski')
	
	return chess_type

func get_chessmen_values() -> Dictionary:
	var config = call_config()
	var values = {}

	for chessman in chessmen_values:
		values[chessman] = config.get_value('AI_chessmen_values', chessman, chessmen_values[chessman])
	
	return values

func call_config() -> ConfigFile:
	var config = ConfigFile.new()
	
	var err = config.load(config_path)

	if err != OK:
		config.set_value('options', 'chess_type', 'Glinski')

		for chessman in chessmen_values:
			config.set_value('AI_chessmen_values', chessman, chessmen_values[chessman])
		
		config.save(config_path)

	return config
