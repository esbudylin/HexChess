extends Control

onready var config = get_node('/root/PlayersData').call_config()

func _ready():
	$Menu/VBoxContainer/Local.grab_focus()

func _on_Local_pressed():
	get_node('/root/PlayersData').chess_type = config.get_value('options', 'chess_type')

	get_tree().set_network_peer(null)
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://map.tscn")

func _on_Options_pressed():
	$Menu.visible = false
	$ColorRect/BackPanel.visible = true
	$Options.visible = true
	$Options/VBoxContainer/HBoxContainer/Glinski.grab_focus()
	
	var chess_type = config.get_value('options', 'chess_type')
	
	for checkbox in get_tree().get_nodes_in_group('chess_types'):
		if checkbox.name == chess_type:
			checkbox.pressed = true
			break
	
func _on_BackPanel_pressed():
	$Menu/VBoxContainer/Local.grab_focus()
	$Menu.visible = true
	$ColorRect/BackPanel.visible = false
	$Options.visible = false
	
	for checkbox in get_tree().get_nodes_in_group('chess_types'):
		if checkbox.pressed:
			config.set_value('options', 'chess_type', checkbox.name)
			break
	
	config.save("res://config.cfg")
