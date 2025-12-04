extends Node2D

@onready var pet := $pet
@onready var sunny := $sunny

var hud: CanvasLayer
var opponent_pet: Node2D = null  # Opponent pet instance for multiplayer
var opponent_label: Label = null  # "YOU" label for player
var websocket_client: Node = null  # WebSocket client

# Game state
var score: int = 0
var game_started: bool = false
var current_round_active: bool = false
var confusion_enabled: bool = false
const CONFUSION_THRESHOLD: int = 3
const COUNTDOWN_VALUES := ["3", "2", "1", "START"]

# Game mode
enum GameMode { SINGLEPLAYER, MULTIPLAYER }
var game_mode: GameMode = GameMode.SINGLEPLAYER
var is_waiting_for_opponent: bool = false
var opponent_game_over: bool = false

# Multiplayer timing queue for Sunny frames
var sunny_frame_queue: Array = []  # Queue of {frame: int, duration_ms: int}
var is_processing_sunny_queue: bool = false
var current_sunny_timer: float = 0.0

# Round timing constants (for singleplayer)
const MIN_WAIT_TIME: float = 0.5
const MAX_WAIT_TIME: float = 3.0
const MATCH_TIMEOUT: float = 0.5

# WebSocket message types
const MSG_TYPE_JOIN_ROOM = "join_room"
const MSG_TYPE_PLAYER_INPUT = "player_input"
const MSG_TYPE_WAIT_CHOICE = "wait_choice"
const MSG_TYPE_READY = "ready"
const MSG_TYPE_ROOM_JOINED = "room_joined"
const MSG_TYPE_WAITING = "waiting"
const MSG_TYPE_GAME_START = "game_start"
const MSG_TYPE_ROUND_START = "round_start"
const MSG_TYPE_SUNNY_FRAME = "sunny_frame"
const MSG_TYPE_OPPONENT_FRAME = "opponent_frame"
const MSG_TYPE_ROUND_RESULT = "round_result"
const MSG_TYPE_GAME_OVER = "game_over"
const MSG_TYPE_OPPONENT_GAME_OVER = "opponent_game_over"
const MSG_TYPE_ERROR = "error"

func _ready() -> void:
	await get_tree().process_frame
	
	# Setup HUD
	hud = $HUD
	if not hud:
		var hud_scene = load("res://sunny-says-level/hud.tscn")
		if hud_scene:
			hud = hud_scene.instantiate()
			add_child(hud)
	
	# Connect HUD signals
	if hud:
		hud.wait_chosen.connect(_on_wait_chosen)
		hud.singleplayer_chosen.connect(_on_singleplayer_chosen)
	
	# Position elements
	_position_relative_to_viewport()
	get_viewport().size_changed.connect(_position_relative_to_viewport)
	
	# Reset to idle
	if pet:
		pet.reset_to_idle()
		# Connect pet frame_changed signal for multiplayer
		if not pet.frame_changed.is_connected(_on_player_frame_changed):
			pet.frame_changed.connect(_on_player_frame_changed)
	if sunny:
		sunny.reset_to_idle()
	
	# Try to connect to multiplayer
	_try_connect_multiplayer()

func _try_connect_multiplayer() -> void:
	if not UserData.has_user_id() or not UserData.has_jwt_token():
		await _run_countdown()
		_start_singleplayer_game()
		return
	
	# Show searching text
	if hud:
		hud.show_searching(true)
	
	# Create WebSocket client
	websocket_client = preload("res://sunny-says-level/websocket_client.gd").new()
	add_child(websocket_client)
	websocket_client.connected.connect(_on_websocket_connected)
	websocket_client.disconnected.connect(_on_websocket_disconnected)
	websocket_client.message_received.connect(_on_websocket_message)
	websocket_client.error_occurred.connect(_on_websocket_error)
	
	# Connect to server (convert http to ws)
	var api_base_url = UserData.API_BASE_URL
	var ws_url = api_base_url.replace("http://", "ws://").replace("https://", "wss://") + "/ws/sunny-says"
	websocket_client.connect_to_server(ws_url, UserData.get_jwt_token())
	
	# Wait for connection or timeout
	await get_tree().create_timer(5.0).timeout
	if not websocket_client.is_connected:
		if hud:
			hud.show_searching(false)
		_start_singleplayer_game()

func _on_websocket_connected() -> void:
	is_waiting_for_opponent = true

func _on_websocket_disconnected() -> void:
	if game_mode == GameMode.MULTIPLAYER and game_started:
		# Only game over if we haven't already received opponent game over
		# If opponent game over was received, we should continue playing solo
		if not opponent_game_over:
			# Connection lost during multiplayer game (unexpected disconnect)
			_game_over()
		# If opponent_game_over is true, the opponent disconnected but we continue playing

func _on_websocket_error(error: String) -> void:
	if hud:
		hud.show_searching(false)
	if not game_started:
		_start_singleplayer_game()

func _on_websocket_message(message: Dictionary) -> void:
	var msg_type = message.get("type", "")
	
	match msg_type:
		MSG_TYPE_ROOM_JOINED:
			pass
		
		MSG_TYPE_WAITING:
			# Only handle waiting messages if game hasn't started
			if not game_started:
				if message.get("message", "") == "timeout":
					# 10 seconds passed, hide searching and show wait choice
					if hud:
						hud.show_searching(false)
						hud.show_wait_choice()
				else:
					# Show searching text again (when player chooses to wait)
					if hud:
						hud.hide_wait_choice()  # Hide wait choice panel
						hud.show_searching(true)  # Show searching text
			# If game has started, ignore waiting messages (shouldn't happen but be safe)
		
		MSG_TYPE_GAME_START:
			# Game starting in multiplayer mode
			game_mode = GameMode.MULTIPLAYER
			is_waiting_for_opponent = false
			if hud:
				hud.show_searching(false)  # Hide searching text
				hud.hide_wait_choice()
			# Disable pet input until countdown ends
			if pet:
				pet.disable_input()
			_setup_multiplayer_ui()
			await _run_countdown()
			# Enable pet input after countdown
			if pet:
				pet.enable_input()
			# Send ready message to server after countdown
			if websocket_client and websocket_client.is_connected:
				websocket_client.send_message({
					"type": MSG_TYPE_READY
				})
			_start_multiplayer_game()
		
		MSG_TYPE_ROUND_START:
			# Server started a new round
			if pet:
				pet.reset_to_idle()
			if opponent_pet:
				# Reset opponent pet but keep input disabled
				if opponent_pet.has_method("set_frame"):
					opponent_pet.set_frame(0)
				# Ensure input stays disabled for opponent
				if opponent_pet.has_method("disable_input"):
					opponent_pet.disable_input()
			if sunny:
				sunny.reset_to_idle()
			# Clear any pending sunny frame queue
			sunny_frame_queue.clear()
			is_processing_sunny_queue = false
			current_sunny_timer = 0.0
			# Round is now starting, mark as not active yet (will be set to true when final frame arrives)
			current_round_active = false
		
		MSG_TYPE_SUNNY_FRAME:
			# Server sent Sunny's frame with optional duration
			var sunny_frame = message.get("sunny_frame", 0)
			var display_duration_ms = message.get("display_duration_ms", 0)
			
			# Add to queue for duration-based processing
			sunny_frame_queue.append({
				"frame": sunny_frame,
				"duration_ms": display_duration_ms
			})
			
			# Start processing queue if not already processing
			if not is_processing_sunny_queue:
				_process_sunny_frame_queue()
		
		MSG_TYPE_OPPONENT_FRAME:
			# Opponent's input received
			var opponent_frame = message.get("frame", 0)
			if opponent_pet and not opponent_game_over:
				if opponent_pet.has_method("set_frame"):
					opponent_pet.set_frame(opponent_frame)
		
		MSG_TYPE_ROUND_RESULT:
			# Round result from server
			var new_score = message.get("score", 0)
			score = new_score
			if hud:
				hud.update_score(score)
			# Send ready message to trigger next round
			# Only send if player hasn't game over and game is still active
			if game_started and pet and pet.input_enabled:
				if websocket_client and websocket_client.is_connected:
					websocket_client.send_message({
						"type": MSG_TYPE_READY
					})
		
		MSG_TYPE_GAME_OVER:
			# Player game over
			var final_score = message.get("score", score)
			score = final_score
			_game_over()
		
		MSG_TYPE_OPPONENT_GAME_OVER:
			# Opponent game over - they disconnected or game overed
			# Player should continue playing solo
			opponent_game_over = true
			if opponent_pet:
				opponent_pet.modulate.a = 0.5  # 50% opacity
			# Don't disconnect - keep playing!
			# Connection stays open, Sunny continues working
			# Mark round as inactive on client side (server will handle round state)
			# This allows the player to continue even if opponent disconnected during a round
			current_round_active = false
			# Send ready to trigger next round (server will mark round inactive if needed)
			if game_started and pet and pet.input_enabled:
				if websocket_client and websocket_client.is_connected:
					websocket_client.send_message({
						"type": MSG_TYPE_READY
					})
		
		MSG_TYPE_ERROR:
			var error_msg = message.get("message", "")
			if error_msg == "singleplayer_mode":
				# Switch to singleplayer
				game_mode = GameMode.SINGLEPLAYER
				if hud:
					hud.show_searching(false)
					hud.hide_wait_choice()
				await _run_countdown()
				_start_singleplayer_game()
			elif error_msg == "opponent_disconnected":
				# Opponent disconnected before game started - only show wait choice if game hasn't started
				if not game_started:
					if hud:
						hud.show_searching(false)
						hud.show_wait_choice()
				# If game has started, ignore this error (opponent game over message handles it)

func _on_wait_chosen() -> void:
	# Player chose to wait
	if websocket_client and websocket_client.is_connected:
		websocket_client.send_message({
			"type": MSG_TYPE_WAIT_CHOICE,
			"choice": "wait"
		})
		if hud:
			hud.hide_wait_choice()
		# Wait another 10 seconds (handled by server)

func _on_singleplayer_chosen() -> void:
	# Player chose singleplayer
	if websocket_client:
		if websocket_client.is_connected:
			websocket_client.send_message({
				"type": MSG_TYPE_WAIT_CHOICE,
				"choice": "singleplayer"
			})
		websocket_client.disconnect_from_server()
		websocket_client.queue_free()
		websocket_client = null
	
	game_mode = GameMode.SINGLEPLAYER
	if hud:
		hud.show_searching(false)
		hud.hide_wait_choice()
	await _run_countdown()
	_start_singleplayer_game()

func _setup_multiplayer_ui() -> void:
	# Create opponent pet
	var pet_scene = load("res://sunny-says-level/pet.tscn")
	if pet_scene:
		opponent_pet = pet_scene.instantiate()
		add_child(opponent_pet)
		# Set opponent's cloud sprite to frame 1
		if opponent_pet.has_method("set_cloud_frame"):
			opponent_pet.set_cloud_frame(1)
		else:
			# Access cloud sprite directly
			var cloud_sprite = opponent_pet.get_node_or_null("CloudSprite")
			if cloud_sprite:
				cloud_sprite.frame = 1
		# Disable input for opponent pet
		if opponent_pet.has_method("disable_input"):
			opponent_pet.disable_input()
	
	# Create "YOU" label for player (programmatically)
	var you_label = Label.new()
	you_label.text = "YOU"
	you_label.name = "YouLabel"
	you_label.add_theme_font_size_override("font_size", 24)
	you_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(you_label)
	opponent_label = you_label
	
	# Reposition for multiplayer
	_position_relative_to_viewport()

func _run_countdown() -> void:
	if not hud:
		return
	for i in COUNTDOWN_VALUES.size():
		var text: String = COUNTDOWN_VALUES[i]
		hud.show_countdown_text(text, true)
		await get_tree().create_timer(1.0).timeout
	hud.show_countdown_text("", false)

func _start_singleplayer_game() -> void:
	score = 0
	confusion_enabled = false
	if hud:
		hud.update_score(score)
	game_started = true
	_start_singleplayer_round()

func _start_singleplayer_round() -> void:
	if not game_started:
		return
	
	current_round_active = false
	
	# Reset both to idle
	if pet:
		pet.reset_to_idle()
	if sunny:
		sunny.reset_to_idle()
	
	# Wait random time before Sunny shows symbol
	var wait_time = randf_range(MIN_WAIT_TIME, MAX_WAIT_TIME)
	await get_tree().create_timer(wait_time).timeout
	
	if not game_started:
		return
	
	# Check if confusion should be used
	var use_confusion = false
	if confusion_enabled and score >= CONFUSION_THRESHOLD:
		use_confusion = randf() < 0.5
	
	if use_confusion:
		await _run_confusion_sequence()
	else:
		var sunny_frame = _choose_random_symbol()
		if sunny:
			sunny.set_frame(sunny_frame)
	
	current_round_active = true
	
	# Wait for match timeout
	await get_tree().create_timer(MATCH_TIMEOUT).timeout
	
	if not game_started:
		return
	
	current_round_active = false
	
	var pet_frame = pet.get_current_frame() if pet else 0
	var sunny_frame = sunny.get_current_frame() if sunny else 0
	
	if pet_frame == sunny_frame and pet_frame != 0:
		score += 1
		if hud:
			hud.update_score(score)
		if score >= CONFUSION_THRESHOLD:
			confusion_enabled = true
		await get_tree().create_timer(0.5).timeout
		_start_singleplayer_round()
	else:
		_game_over()

func _start_multiplayer_game() -> void:
	score = 0
	if hud:
		hud.update_score(score)
	game_started = true
	# Rounds are controlled by server

func _run_confusion_sequence() -> void:
	var flash_count = randi_range(1, 3)
	
	for i in flash_count:
		var flash_frame = _choose_random_symbol()
		if sunny:
			sunny.set_frame(flash_frame)
		await get_tree().create_timer(0.3).timeout
		if i < flash_count - 1:
			var wait_time = randf_range(0.3, 1.0)
			await get_tree().create_timer(wait_time).timeout
			if sunny:
				sunny.set_frame(0)
			await get_tree().create_timer(0.1).timeout
	
	var final_frame = _choose_random_symbol()
	if sunny:
		sunny.set_frame(final_frame)

func _choose_random_symbol() -> int:
	return randi_range(1, 3)

func _game_over() -> void:
	game_started = false
	current_round_active = false
	
	# Clear sunny frame queue
	sunny_frame_queue.clear()
	is_processing_sunny_queue = false
	current_sunny_timer = 0.0
	
	if pet:
		pet.disable_input()
	
	if websocket_client:
		websocket_client.disconnect_from_server()
	
	if hud:
		hud.show_game_over(score)
	
	_save_high_score(score)

func _position_relative_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	var center_x := vp_size.x * 0.5
	var sunny_y := vp_size.y * 0.55 - 80.0
	var pet_y := vp_size.y * 0.25
	
	if is_instance_valid(sunny):
		sunny.position.x = center_x
		sunny.position.y = sunny_y
	
	if game_mode == GameMode.MULTIPLAYER:
		# Player on left, opponent on right
		if is_instance_valid(pet):
			pet.position.x = center_x - 400.0
			pet.position.y = pet_y
		
		if is_instance_valid(opponent_pet):
			opponent_pet.position.x = center_x + 400.0
			opponent_pet.position.y = pet_y
		
		# Position "YOU" label below player pet
		if is_instance_valid(opponent_label):
			opponent_label.position.x = center_x - 400.0
			opponent_label.position.y = pet_y + 120.0  # 20px margin + sprite height
	else:
		# Singleplayer - center pet
		if is_instance_valid(pet):
			pet.position.x = center_x
			pet.position.y = pet_y

func _on_player_frame_changed(new_frame: int) -> void:
	# Send player input to server
	if websocket_client and websocket_client.is_connected:
		websocket_client.send_message({
			"type": MSG_TYPE_PLAYER_INPUT,
			"frame": new_frame
		})

func _process_sunny_frame_queue() -> void:
	# Process the queue of Sunny frames with proper timing
	if is_processing_sunny_queue:
		return
	
	if sunny_frame_queue.is_empty():
		return
	
	is_processing_sunny_queue = true
	
	# Process frames one at a time with proper timing
	_process_next_sunny_frame()

func _process_next_sunny_frame() -> void:
	# Check if queue is empty
	if sunny_frame_queue.is_empty():
		is_processing_sunny_queue = false
		return
	
	# Get next frame from queue
	var frame_data = sunny_frame_queue.pop_front()
	var frame = frame_data.get("frame", 0)
	var duration_ms = frame_data.get("duration_ms", 0)
	
	# Set the frame immediately
	if sunny:
		sunny.set_frame(frame)
	
	# If this is the final frame (no duration), mark round as active and stop processing
	if duration_ms <= 0:
		current_round_active = true
		is_processing_sunny_queue = false
		return
	
	# Wait for the specified duration before processing next frame
	await get_tree().create_timer(duration_ms / 1000.0).timeout
	
	# Process next frame recursively
	_process_next_sunny_frame()

func _save_high_score(final_score: int) -> void:
	if not UserData.has_user_id() or not UserData.has_jwt_token():
		return
	
	# Use UserData API helper to save high score
	var data = {
		"game_type": "Sunny Says",
		"score": final_score
	}
	
	UserData.api_post("/api/v1/game/save", data, _on_save_high_score_completed)

func _on_save_high_score_completed(result: int, response_code: int, response_data) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		pass  # Silent failure
