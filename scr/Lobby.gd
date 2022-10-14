extends Control

const DEFAULT_PORT = 8910

var rng = RandomNumberGenerator.new()

onready var address = $LobbyPanel/Address
onready var port_forward_label = $PortForward

onready var status_ok = $TextPanel/StatusOk
onready var status_fail = $TextPanel/StatusFail
onready var text_panel = $TextPanel

onready var host_button = $VBoxContainer/Host
onready var join_button = $VBoxContainer/Join

var peer = null
var color_index

func _ready():
# warning-ignore:return_value_discarded
	get_tree().connect("network_peer_connected", self, "_player_connected")
# warning-ignore:return_value_discarded
	get_tree().connect("connection_failed", self, "_connected_fail")
	
	rset_config("color_index", 1)
	rpc_config("set_colors", 1)
	rpc_config("set_chess_types", 1)
	
func _player_connected(_id):
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
	
	if get_tree().is_network_server():
		set_chess_types ()

func set_chess_types (chess_type = null):
	if chess_type == null:
		var config = get_node('/root/PlayersData').call_config()
		get_node('/root/PlayersData').chess_type = config.get_value('options', 'chess_type')
		rpc ('set_chess_types', config.get_value('options', 'chess_type'))
		
	else:
		get_node('/root/PlayersData').chess_type = chess_type
	
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://map.tscn")
	
func _connected_fail():
	_set_status("Couldn't connect", false)

	get_tree().set_network_peer(null) # Remove peer.
	host_button.set_disabled(false)
	join_button.set_disabled(false)

func _set_status(text, isok):
	if isok:
		status_ok.set_text(text)
		status_fail.set_text("")
	else:
		status_ok.set_text("")
		status_fail.set_text(text)

func _on_Join_pressed():
	$LobbyPanel.visible = true
	address.grab_focus()

func _on_Host_pressed():
	$LobbyPanel.visible = false
	text_panel.visible = true
	port_forward_label.visible = true
	
	peer = NetworkedMultiplayerENet.new()
	get_node('/root/PlayersData').peer = peer
	
	var err = peer.create_server(DEFAULT_PORT, 1)
	if err != OK:
		_set_status("Can't host, address in use.",false)
		return

	get_tree().set_network_peer(peer)
	host_button.set_disabled(true)
	join_button.set_disabled(true)
	_set_status("Waiting for player...", true)

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

func _on_Address_text_entered(_new_text):
	_on_OkButton_pressed ()
