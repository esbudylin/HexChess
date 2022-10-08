extends Control

#signal game_finished()

const DEFAULT_PORT = 8910

var rng = RandomNumberGenerator.new()

onready var address = $Address
onready var port_forward_label = get_node('/root/Control/PortForward')

onready var status_ok = get_node('/root/Control/TextPanel/StatusOk')
onready var status_fail = get_node('/root/Control/TextPanel/StatusFail')
onready var text_panel = get_node('/root/Control/TextPanel')

onready var host_button = get_node('/root/Control/VBoxContainer/Host')
onready var join_button = get_node('/root/Control/VBoxContainer/Join')

var peer = null
var color_index

func _ready():
	# Connect all the callbacks related to networking.
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("connection_failed", self, "_connected_fail")
	
	rset_config("color_index", 1)
	rpc_config("set_colors", 1)
	
func _player_connected(_id):
	# Someone connected, start the game!
	generate_color_index()

func generate_color_index():
	if get_tree().is_network_server():
		rng.randomize()
		color_index = rng.randi_range (0, 1)
		rpc ('set_colors', color_index)
		set_colors(color_index)
		
func set_colors (color_index_local):
	if color_index_local == 0:
		get_node('/root/PlayersData').master_color = 'white'
		get_node('/root/PlayersData').puppet_color = 'black'
	else:
		get_node('/root/PlayersData').master_color = 'black'
		get_node('/root/PlayersData').puppet_color = 'white'
	
	get_tree().change_scene("res://map.tscn")
	
func _connected_fail():
	_set_status("Couldn't connect", false)

	get_tree().set_network_peer(null) # Remove peer.
	host_button.set_disabled(false)
	join_button.set_disabled(false)

func _set_status(text, isok):
	# Simple way to show status.
	if isok:
		status_ok.set_text(text)
		status_fail.set_text("")
	else:
		status_ok.set_text("")
		status_fail.set_text(text)

func _on_Join_pressed():
	self.visible = true
	address.grab_focus()

func _on_Host_pressed():
	text_panel.visible = true
	port_forward_label.visible = true
	
	peer = NetworkedMultiplayerENet.new()
	get_node('/root/PlayersData').peer = peer
	
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

func _on_OkButton_pressed():
	text_panel.visible = true
	
	var ip = address.get_text()
	if not ip.is_valid_ip_address():
		_set_status("IP address is invalid", false)
		return

	peer = NetworkedMultiplayerENet.new()
	get_node('/root/PlayersData').peer = peer
	
	peer.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)

	_set_status("Connecting...", true)

func _on_Address_text_entered():
	_on_OkButton_pressed ()
