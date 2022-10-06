extends Control

#signal game_finished()

const DEFAULT_PORT = 8910

onready var address = $Address
onready var status_ok = $StatusOk
onready var status_fail = $StatusFail
onready var port_forward_label = $PortForward
onready var find_public_ip_button = $FindPublicIP

onready var host_button = get_node('/root/Control/VBoxContainer/Host')
onready var join_button = get_node('/root/Control/VBoxContainer/Join')

var peer = null

func _ready():
	# Connect all the callbacks related to networking.
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
func _player_connected(_id):
	# Someone connected, start the game!
	get_tree().change_scene("res://map.tscn")

func _player_disconnected(_id):
	if get_tree().is_network_server():
		_end_game("Client disconnected")
	else:
		_end_game("Server disconnected")

func _connected_fail():
	_set_status("Couldn't connect", false)

	get_tree().set_network_peer(null) # Remove peer.
	host_button.set_disabled(false)
	join_button.set_disabled(false)

func _server_disconnected():
	_end_game("Server disconnected")

##### Game creation functions ######

func _end_game(with_error = ""):

	get_tree().set_network_peer(null) # Remove peer.
	host_button.set_disabled(false)
	join_button.set_disabled(false)

	_set_status(with_error, false)

func _set_status(text, isok):
	# Simple way to show status.
	if isok:
		status_ok.set_text(text)
		status_fail.set_text("")
	else:
		status_ok.set_text("")
		status_fail.set_text(text)

func _on_find_public_ip_pressed():
	OS.shell_open("https://icanhazip.com/")

func _on_Join_pressed():
	self.visible = true
	
	var ip = address.get_text()
	if not ip.is_valid_ip_address():
		_set_status("IP address is invalid", false)
		return

	peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)

	_set_status("Connecting...", true)

func _on_Host_pressed():
	self.visible = true
	
	peer = NetworkedMultiplayerENet.new()
	var err = peer.create_server(DEFAULT_PORT, 1) # Maximum of 1 peer, since it's a 2-player game.
	if err != OK:
		# Is another server running?
		_set_status("Can't host, address in use.",false)
		return

	get_tree().set_network_peer(peer)
	host_button.set_disabled(true)
	join_button.set_disabled(true)
	_set_status("Waiting for player...", true)

	# Only show hosting instructions when relevant.
	port_forward_label.visible = true
	find_public_ip_button.visible = true
