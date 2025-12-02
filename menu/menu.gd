extends CanvasLayer

var _jump_rope_button: Button
var _sunny_says_button: Button
var _mine_race_button: Button
var _auth_status_label: Label

var high_scores: Dictionary = {
	"Jump Rope": 0,
	"Sunny Says": 0,
	"Mine Race": 0
}

# User authentication
var current_user_id: String = ""
var _uid_poll_timer: Timer = null
var _poll_attempts: int = 0
const MAX_POLL_ATTEMPTS: int = 20  # 10 seconds (20 * 0.5s)

func _ready() -> void:
	_jump_rope_button = $Root/MainContainer/ButtonsContainer/JumpRopeButton
	_sunny_says_button = $Root/MainContainer/ButtonsContainer/SunnySaysButton
	_mine_race_button = $Root/MainContainer/ButtonsContainer/MineRaceButton
	_auth_status_label = $Root/AuthStatusLabel
	
	# Connect button signals
	_jump_rope_button.pressed.connect(_on_jump_rope_pressed)
	_sunny_says_button.pressed.connect(_on_sunny_says_pressed)
	_mine_race_button.pressed.connect(_on_mine_race_pressed)
	
	# Initialize auth status label
	_update_auth_status()
	
	# Update high score displays (will be updated from API if authenticated)
	_update_high_scores()
	
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
	else:
		print("ERROR: Failed to connect timer timeout signal")
	
	# Try polling once immediately
	_check_for_pending_uid()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		# Refresh high scores when entering the menu scene
		if UserData.has_user_id() and UserData.has_jwt_token():
			_fetch_high_scores_from_api()

func _update_high_scores() -> void:
	var jump_rope_score = $Root/MainContainer/HighScoresContainer/JumpRopeScoreContainer/JumpRopeScore
	var sunny_says_score = $Root/MainContainer/HighScoresContainer/SunnySaysScoreContainer/SunnySaysScore
	var mine_race_score = $Root/MainContainer/HighScoresContainer/MineRaceScoreContainer/MineRaceScore
	
	jump_rope_score.text = str(high_scores["Jump Rope"])
	sunny_says_score.text = str(high_scores["Sunny Says"])
	mine_race_score.text = str(high_scores["Mine Race"])

func _on_jump_rope_pressed() -> void:
	get_tree().change_scene_to_file("res://jump-rope-level/jump-rope-main.tscn")

func _on_sunny_says_pressed() -> void:
	# TODO: Implement when Sunny Says is created
	pass

func _on_mine_race_pressed() -> void:
	# TODO: Implement when Mine Race is created
	pass

func _update_auth_status() -> void:
	var uid = UserData.get_user_id()
	if not uid.is_empty():
		# Authentication successful - show green status and UID
		_auth_status_label.text = "Auth: OK | UID: " + uid
		_auth_status_label.modulate = Color(0.2, 1.0, 0.2)  # Green color
	else:
		# Not authenticated yet
		_auth_status_label.text = "Auth: Waiting..."
		_auth_status_label.modulate = Color(1.0, 1.0, 1.0)  # White color

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
		print("Timeout: Failed to receive UID after 10 seconds")
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
	_update_auth_status()
	_initialize_user_data()

func _initialize_user_data() -> void:
	if not UserData.has_user_id():
		return
	
	# Fetch user-specific game data (high scores)
	_fetch_high_scores_from_api()

func _fetch_high_scores_from_api() -> void:
	if not UserData.has_jwt_token():
		print("No JWT token available for API request")
		_update_auth_status_with_error("No token")
		return
	
	# Use UserData API helper to fetch high scores
	UserData.api_get("/api/v1/game/data", _on_high_scores_fetched)

func _on_high_scores_fetched(result: int, response_code: int, response_data) -> void:
	# Check if request was successful
	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed with result: ", result)
		_update_auth_status_with_error("Network error")
		return
	
	# Validate JWT by checking response code
	if response_code == 200:
		# JWT is valid - parse high scores
		if response_data != null and response_data.has("high_scores"):
			var high_scores_dict = response_data["high_scores"]
			# Update high scores dictionary
			if high_scores_dict.has("Jump Rope"):
				high_scores["Jump Rope"] = int(high_scores_dict["Jump Rope"])
			if high_scores_dict.has("Sunny Says"):
				high_scores["Sunny Says"] = int(high_scores_dict["Sunny Says"])
			if high_scores_dict.has("Mine Race"):
				high_scores["Mine Race"] = int(high_scores_dict["Mine Race"])
			
			# Update UI with fetched high scores
			_update_high_scores()
			print("Successfully fetched high scores")
		else:
			# No high scores yet, keep defaults
			print("No high scores found, using defaults")
		
		# Authentication confirmed
		_update_auth_status_validated()
	elif response_code == 401:
		# JWT is invalid or expired
		print("JWT validation failed: Unauthorized")
		_update_auth_status_with_error("Auth failed")
		# Clear invalid token
		UserData.set_jwt_token("")
	else:
		print("Unexpected response code: ", response_code)
		_update_auth_status_with_error("Server error")

func _update_auth_status_validated() -> void:
	var uid = UserData.get_user_id()
	if not uid.is_empty():
		_auth_status_label.text = "Auth: OK | UID: " + uid
		_auth_status_label.modulate = Color(0.2, 1.0, 0.2)  # Green color

func _update_auth_status_with_error(error_msg: String) -> void:
	var uid = UserData.get_user_id()
	if not uid.is_empty():
		_auth_status_label.text = "Auth: " + error_msg + " | UID: " + uid
		_auth_status_label.modulate = Color(1.0, 0.5, 0.2)  # Orange/red color
	else:
		_auth_status_label.text = "Auth: " + error_msg
		_auth_status_label.modulate = Color(1.0, 0.2, 0.2)  # Red color
