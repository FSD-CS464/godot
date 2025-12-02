extends Node

# WebSocket client for Sunny Says multiplayer
signal connected
signal disconnected
signal message_received(message: Dictionary)
signal error_occurred(error: String)

var websocket: WebSocketPeer = null
var is_connected: bool = false
var url: String = ""

func connect_to_server(server_url: String, token: String) -> void:
	url = server_url + "?token=" + token
	
	websocket = WebSocketPeer.new()
	var err = websocket.connect_to_url(url)
	if err != OK:
		error_occurred.emit("Failed to connect: " + str(err))
		return
	
	print("Connecting to WebSocket: ", url)

func disconnect_from_server() -> void:
	if websocket:
		websocket.close()
		is_connected = false
		disconnected.emit()

func send_message(message: Dictionary) -> void:
	if not is_connected or not websocket:
		print("Cannot send message: not connected")
		return
	
	var json = JSON.new()
	var json_string = json.stringify(message)
	var error = websocket.send_text(json_string)
	if error != OK:
		print("Failed to send message: ", error)

func _process(_delta: float) -> void:
	if not websocket:
		return
	
	websocket.poll()
	
	var state = websocket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			connected.emit()
		
		# Receive messages
		while websocket.get_available_packet_count() > 0:
			var packet = websocket.get_packet()
			var message_text = packet.get_string_from_utf8()
			
			var json = JSON.new()
			var parse_error = json.parse(message_text)
			if parse_error == OK:
				var message = json.data
				message_received.emit(message)
			else:
				print("Failed to parse WebSocket message: ", message_text)
	
	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			is_connected = false
			disconnected.emit()
	
	elif state == WebSocketPeer.STATE_CONNECTING:
		# Still connecting
		pass

