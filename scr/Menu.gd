extends Control

func _ready():
	$VBoxContainer/Local.grab_focus()

func _on_Local_pressed():
	get_tree().change_scene("res://map.tscn")
