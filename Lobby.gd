# Typical lobby implementation; imagine this being in /root/lobby.

extends Node

func _ready():
	var peer = NetworkedMultiplayerENet.new()
	var SERVER_IP = "128.199.217.36"
	var SERVER_PORT = 4321
	var MAX_PLAYERS = 8

	if OS.has_feature("Server") or "--server" in OS.get_cmdline_args():
		peer.create_server(SERVER_PORT, MAX_PLAYERS)
	else:
		peer.create_client(SERVER_IP, SERVER_PORT)
		
	get_tree().network_peer = peer
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

# Player info, associate ID to data
var player_info = {}
# Info we send to other players
var my_info = { name = "Johnson Magenta", favorite_color = Color8(255, 0, 255) }
var chat_log = []
var puppet_chat_log = []

func _player_connected(id):
	# Called on both clients and server when a peer connects. Send my info to it.
	print("New player connected %s" % id)
	rpc_id(id, "register_player", my_info)

func _player_disconnected(id):
	player_info.erase(id) # Erase player from info.

func _connected_ok():
	pass # Only called on clients, not server. Will go unused; not useful here.

func _server_disconnected():
	pass # Server kicked us; show error and abort.

func _connected_fail():
	pass # Could not even connect to server; abort.

remote func register_player(info):
	# Get the id of the RPC sender.
	var id = get_tree().get_rpc_sender_id()
	# Store the info
	player_info[id] = info
	# Call function to update lobby UI here
	print("Player ID %s name %s info updated" % [id, player_info[id].name])
	
remote func create_message(contents: String):
	print("create_message received %s" % contents)
	var id = get_tree().get_rpc_sender_id()
	print("New message from %s" % id)
	var message = Message.new(
		player_info[id].name,
		contents
	)
	print("Message content: %s" % message._to_string())
	chat_log.push_back(message._to_string())
	print("New chat log:")
	pprint(chat_log)
	return message	
	
func pprint(chat_log):
	var result = ""
	for message in chat_log:
		result += message._to_string()
		result += "\n"
	print(result)
	return(result)

class Message:
	var sender
	var time
	var contents
	func _init(sender, contents):
		sender = sender
		time = OS.get_time()
		contents = contents
	func _to_string() -> String:
		return "%s: %s" % sender % contents
		# return ("%s [%s:%s:%s]: %s" % sender % time.hour % time.minute % time.second % contents)
		
puppet func _update_chat_log(chat_log):
	puppet_chat_log = chat_log

func _on_SendMessageButton_pressed():
	var my_id = get_tree().get_network_unique_id()
	rpc_id(1, "create_message", $ChatRoom/MessagePreview.text)
	
func _process(_delta):
	if get_tree().is_network_server():
		rpc("_update_chat_log", chat_log)
	else:
		chat_log = puppet_chat_log
		if $ChatRoom/ChatDisplay != null:
			$ChatRoom/ChatDisplay.text = pprint(chat_log)
