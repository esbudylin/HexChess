extends Node

var colors = ['white', 'black']

var master_color 
var puppet_color 

var peer

var chess_type setget , get_chess_type

func get_chess_type():
	if chess_type: return chess_type
	else: return call_config().get_value('options', 'chess_type')

func call_config():
	var config = ConfigFile.new()
	
	var err = config.load("res://config.cfg")

	if err != OK:
		config.set_value('options', 'chess_type', 'Glinski')
		
	return config
