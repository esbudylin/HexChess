extends Control

func _ready():
	$VBoxContainer/Local.grab_focus()

func _on_Local_pressed():
	get_tree().set_network_peer(null)
	get_tree().change_scene("res://map.tscn")
