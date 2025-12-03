extends CanvasLayer

var _jump_rope_button: TextureButton
var _sunny_says_button: TextureButton
var _how_to_play_button: TextureButton
var _energy_label: Label
var _jump_rope_high_score_label: Label
var _sunny_says_high_score_label: Label

var high_scores: Dictionary = {
	"Jump Rope": 0,
	"Sunny Says": 0
}

# User authentication
var current_user_id: String = ""
var _uid_poll_timer: Timer = null
var _poll_attempts: int = 0
const MAX_POLL_ATTEMPTS: int = 20  # 10 seconds (20 * 0.5s)

# Energy tracking
var current_energy: int = 30
const JUMP_ROPE_ENERGY_COST: int = 10
const SUNNY_SAYS_ENERGY_COST: int = 15

func _ready() -> void:
	_jump_rope_button = $Root/LeftContainer/JumpRopeContainer/JumpRopeButton
	_sunny_says_button = $Root/LeftContainer/SunnySaysContainer/SunnySaysButton
	_how_to_play_button = $Root/HowToPlayButton
	_energy_label = $Root/EnergyContainer/EnergyLabel
	_jump_rope_high_score_label = $Root/LeftContainer/JumpRopeContainer/JumpRopeInfo/HighScoreLabel
	_sunny_says_high_score_label = $Root/LeftContainer/SunnySaysContainer/SunnySaysInfo/HighScoreLabel
	
	# Connect button signals
	_jump_rope_button.pressed.connect(_on_jump_rope_pressed)
	_sunny_says_button.pressed.connect(_on_sunny_says_pressed)
	_how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	
	# Update high score displays (will be updated from API if authenticated)
	_update_high_scores()
	
	# Initialize energy display
	_update_energy_display()
	
	# Initialize button states based on current energy
	_update_button_states()
	
	# Check if we already have a UID from persistent storage
	if UserData.has_user_id():
		# If we have a stored token, validate it; otherwise just set UID
		if UserData.has_jwt_token():
			set_user_id(UserData.get_user_id(), UserData.get_jwt_token())
		else:
			set_user_id(UserData.get_user_id())
		return
	
	# Setup JavaScript bridge for HTML5 export
	await get_tree().process_frame
	
	# Start polling timer to check for pending UID from JavaScript
	_uid_poll_timer = Timer.new()
	add_child(_uid_poll_timer)
	_uid_poll_timer.wait_time = 0.5
	_uid_poll_timer.one_shot = false
	
	if _uid_poll_timer.timeout.connect(_check_for_pending_uid) == OK:
		_uid_poll_timer.start()
	
	# Try polling once immediately
	_check_for_pending_uid()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		# Refresh high scores and energy when entering the menu scene (e.g., returning from a game)
		if UserData.has_user_id() and UserData.has_jwt_token():
			_fetch_high_scores_from_api()
			_fetch_energy_from_api()

func _update_high_scores() -> void:
	if _jump_rope_high_score_label:
		_jump_rope_high_score_label.text = "High Score: " + str(high_scores["Jump Rope"])
	if _sunny_says_high_score_label:
		_sunny_says_high_score_label.text = "High Score: " + str(high_scores["Sunny Says"])

func _on_jump_rope_pressed() -> void:
	# Check and deduct energy before starting game
	if not _check_and_deduct_energy("Jump Rope", JUMP_ROPE_ENERGY_COST):
		return
	get_tree().change_scene_to_file("res://jump-rope-level/jump-rope-main.tscn")

func _on_sunny_says_pressed() -> void:
	# Check and deduct energy before starting game
	if not _check_and_deduct_energy("Sunny Says", SUNNY_SAYS_ENERGY_COST):
		return
	get_tree().change_scene_to_file("res://sunny-says-level/sunny_says_main.tscn")

func _on_how_to_play_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/how_to_play.tscn")

# Poll JavaScript for pending UID
func _check_for_pending_uid() -> void:
	# Ensure this node is in the tree before proceeding (prevents mobile Chrome timing issues)
	if not is_inside_tree():
		return
	
	# Check persistent storage first
	if UserData.has_user_id():
		if _uid_poll_timer and is_instance_valid(_uid_poll_timer):
			_uid_poll_timer.stop()
			_uid_poll_timer.queue_free()
			_uid_poll_timer = null
		# If we have a stored token, validate it; otherwise just set UID
		if UserData.has_jwt_token():
			set_user_id(UserData.get_user_id(), UserData.get_jwt_token())
		else:
			set_user_id(UserData.get_user_id())
		return
	
	_poll_attempts += 1
	
	# Stop polling after 10 seconds (20 attempts * 0.5s)
	if _poll_attempts > MAX_POLL_ATTEMPTS:
		if _uid_poll_timer and is_instance_valid(_uid_poll_timer):
			_uid_poll_timer.stop()
			_uid_poll_timer.queue_free()
			_uid_poll_timer = null
		return
	
	# Call JavaScript function to get pending UID and token
	var js_code_uid = "window.getPendingUID ? window.getPendingUID() : null;"
	var result_uid = JavaScriptBridge.eval(js_code_uid, true)
	
	var js_code_token = "window.getPendingToken ? window.getPendingToken() : null;"
	var result_token = JavaScriptBridge.eval(js_code_token, true)
	
	# Extract UID from result
	var uid = ""
	if result_uid is String:
		uid = result_uid.strip_edges()
	elif result_uid != null:
		uid = str(result_uid).strip_edges()
	
	# Extract JWT token from result
	var token = ""
	if result_token is String:
		token = result_token.strip_edges()
	elif result_token != null:
		token = str(result_token).strip_edges()
	
	# Validate and process UID and token
	if not uid.is_empty() and uid != "null" and uid != "undefined":
		# Stop timer
		if _uid_poll_timer and is_instance_valid(_uid_poll_timer):
			_uid_poll_timer.stop()
			_uid_poll_timer.queue_free()
			_uid_poll_timer = null
		
		# Process UID and token
		set_user_id(uid, token)

# Function to receive the UID and JWT token from the JavaScript layer
func set_user_id(uid: String, token: String = "") -> void:
	# Store in persistent autoload
	UserData.set_user_id(uid)
	if not token.is_empty():
		UserData.set_jwt_token(token)
	_initialize_user_data()

func _initialize_user_data() -> void:
	if not UserData.has_user_id():
		return
	
	# Fetch user-specific game data (high scores and energy)
	_fetch_high_scores_from_api()
	_fetch_energy_from_api()

func _fetch_high_scores_from_api() -> void:
	if not UserData.has_jwt_token():
		return
	
	# Use UserData API helper to fetch high scores
	UserData.api_get("/api/v1/game/data", _on_high_scores_fetched)

func _on_high_scores_fetched(result: int, response_code: int, response_data) -> void:
	# Check if request was successful
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	
	# Validate JWT by checking response code
	if response_code == 200:
		# JWT is valid - response_data is already parsed by UserData.api_get
		
		# Parse and update high scores from response
		if response_data != null and response_data.has("high_scores"):
			var high_scores_dict = response_data["high_scores"]
			# Update high scores dictionary
			if high_scores_dict.has("Jump Rope"):
				high_scores["Jump Rope"] = int(high_scores_dict["Jump Rope"])
			if high_scores_dict.has("Sunny Says"):
				high_scores["Sunny Says"] = int(high_scores_dict["Sunny Says"])
			
			# Update UI with fetched high scores
			_update_high_scores()
		
		# Parse and update energy from response
		if response_data != null and response_data.has("energy"):
			current_energy = int(response_data["energy"])
			_update_energy_display()
			_update_button_states()
	elif response_code == 401:
		# JWT is invalid or expired - clear invalid token
		UserData.set_jwt_token("")

func _fetch_energy_from_api() -> void:
	if not UserData.has_jwt_token():
		return
	
	# Use UserData API helper to fetch energy
	UserData.api_get("/api/v1/users/me/energy", _on_energy_fetched)

func _on_energy_fetched(result: int, response_code: int, response_data) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	
	if response_code == 200 and response_data != null and response_data.has("energy"):
		current_energy = int(response_data["energy"])
		_update_energy_display()
		_update_button_states()

func _update_energy_display() -> void:
	if _energy_label:
		_energy_label.text = "Energy: " + str(current_energy)

func _update_button_states() -> void:
	# Disable buttons if insufficient energy (disabled texture will be used automatically)
	if _jump_rope_button:
		_jump_rope_button.disabled = current_energy < JUMP_ROPE_ENERGY_COST
	
	if _sunny_says_button:
		_sunny_says_button.disabled = current_energy < SUNNY_SAYS_ENERGY_COST

func _check_and_deduct_energy(game_type: String, energy_cost: int) -> bool:
	# Check if user has enough energy
	if current_energy < energy_cost:
		return false
	
	# Deduct energy via API
	if not UserData.has_jwt_token():
		return false
	
	var data = {
		"game_type": game_type
	}
	
	UserData.api_post("/api/v1/game/deduct-energy", data, _on_energy_deducted)
	
	# Optimistically update local energy
	current_energy -= energy_cost
	_update_energy_display()
	_update_button_states()
	
	return true

func _on_energy_deducted(result: int, response_code: int, response_data) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if response_data != null and response_data.has("new_energy"):
			current_energy = int(response_data["new_energy"])
			_update_energy_display()
			_update_button_states()
	else:
		# Revert optimistic update if deduction failed
		_fetch_energy_from_api()
