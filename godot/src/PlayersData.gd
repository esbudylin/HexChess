extends Node

const colors = ['white', 'black']

const chessmen_values = {'Queen': 9, 'Rook': 5, 'Knight': 3, 
						'Bishop': 4, 'Pawn': 1, 'King': 10}


var master_color 
var puppet_color 

var peer

var chess_type setget , get_chess_type

func get_chess_type():
	if chess_type: return chess_type
	else: return call_config().get_value('options', 'chess_type')

func get_chessmen_values():
	var config = call_config()
	var values = {}

	for chessman in chessmen_values:
		values[chessman] = config.get_value('AI_chessmen_values', chessman, chessmen_values[chessman])
	
	return values

func call_config():
	var config = ConfigFile.new()
	
	var err = config.load("res://config.cfg")

	if err != OK:
		config.set_value('options', 'chess_type', 'Glinski')

		for chessman in chessmen_values:
			config.set_value('AI_chessmen_values', chessman, chessmen_values[chessman])
		
		config.save("user://config.cfg")

	return config
