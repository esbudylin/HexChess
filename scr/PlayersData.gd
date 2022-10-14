extends Node

var colors = ['white', 'black']

var master_color 
var puppet_color 

var peer

var chess_type

func call_config ():
	var config = ConfigFile.new()
	
	var err = config.load("res://config.cfg")

	if err != OK:
		config.set_value('options', 'chess_type', 'Glinski')
		
	return config
