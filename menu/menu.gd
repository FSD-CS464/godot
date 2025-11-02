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
	
	# Update high score displays
	_update_high_scores()
	
	# Check if we already have a UID from persistent storage
	if UserData.has_user_id():
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
	
	# Call JavaScript function to get pending UID
	var js_code = "window.getPendingUID ? window.getPendingUID() : null;"
	var result = JavaScriptBridge.eval(js_code, true)
	
	# Extract UID from result
	var uid = ""
	if result is String:
		uid = result.strip_edges()
	elif result != null:
		uid = str(result).strip_edges()
	
	# Validate and process UID
	if not uid.is_empty() and uid != "null" and uid != "undefined":
		# Stop timer
		if _uid_poll_timer and is_instance_valid(_uid_poll_timer):
			_uid_poll_timer.stop()
			_uid_poll_timer.queue_free()
			_uid_poll_timer = null
		
		# Process UID
		set_user_id(uid)

# Function to receive the UID from the JavaScript layer
func set_user_id(uid: String) -> void:
	# Store in persistent autoload
	UserData.set_user_id(uid)
	_update_auth_status()
	_initialize_user_data()

func _initialize_user_data() -> void:
	if not UserData.has_user_id():
		return
	
	# TODO: Implement HTTP request to fetch user-specific game data
	# The browser will automatically send the JWT cookie with requests
	# Example API endpoint: http://localhost:8080/api/v1/game/data
	_fetch_user_data_from_golang_api()

func _fetch_user_data_from_golang_api() -> void:
	# Placeholder for future HTTP request implementation
	# Use HTTPRequest node or HTTPClient to fetch user data
	pass
