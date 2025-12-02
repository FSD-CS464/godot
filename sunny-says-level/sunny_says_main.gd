extends Node2D

@onready var pet := $pet
@onready var sunny := $sunny

var hud: CanvasLayer
var score: int = 0
var game_started: bool = false
var current_round_active: bool = false
var confusion_enabled: bool = false  # Enabled after 3 points
const CONFUSION_THRESHOLD: int = 3
const COUNTDOWN_VALUES := ["3", "2", "1", "START"]

# Round timing constants
const MIN_WAIT_TIME: float = 0.5
const MAX_WAIT_TIME: float = 3.0
const MATCH_TIMEOUT: float = 0.5  # Time player has to match after Sunny shows symbol

func _ready() -> void:
	# Ensure children are ready
	await get_tree().process_frame
	# Use HUD instance - need to add it to scene
	hud = $HUD
	if not hud:
		# If HUD not in scene, create it programmatically
		var hud_scene = load("res://sunny-says-level/hud.tscn")
		if hud_scene:
			hud = hud_scene.instantiate()
			add_child(hud)
	
	# Position along center X and sensible relative Y
	_position_relative_to_viewport()
	get_viewport().size_changed.connect(_position_relative_to_viewport)
	
	# Reset both to idle
	if pet:
		pet.reset_to_idle()
	if sunny:
		sunny.reset_to_idle()
	
	# Start countdown then game
	await _run_countdown()
	_start_game()

func _run_countdown() -> void:
	if not hud:
		return
	for i in COUNTDOWN_VALUES.size():
		var text: String = COUNTDOWN_VALUES[i]
		(hud as Node).call_deferred("show_countdown_text", text, true)
		await get_tree().create_timer(1.0).timeout
	# Hide countdown label
	(hud as Node).call_deferred("show_countdown_text", "", false)

func _start_game() -> void:
	score = 0
	confusion_enabled = false
	if hud:
		(hud as Node).call_deferred("update_score", score)
	game_started = true
	_start_round()

func _start_round() -> void:
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
	
	# Check if confusion should be used (only after 3 points)
	var use_confusion = false
	if confusion_enabled and score >= CONFUSION_THRESHOLD:
		# Random chance to use confusion (50% chance)
		use_confusion = randf() < 0.5
	
	if use_confusion:
		await _run_confusion_sequence()
	else:
		# Normal round - Sunny shows symbol immediately
		var sunny_frame = _choose_random_symbol()
		if sunny:
			sunny.set_frame(sunny_frame)
	
	# Mark round as active - player can now respond
	current_round_active = true
	
	# Wait for the full 1 second timeout period
	await get_tree().create_timer(MATCH_TIMEOUT).timeout
	
	if not game_started:
		return
	
	# After timeout, validate the player's input
	current_round_active = false
	
	var pet_frame = pet.get_current_frame() if pet else 0
	var sunny_frame = sunny.get_current_frame() if sunny else 0
	
	# Check if frames match and pet made an input (not 0)
	if pet_frame == sunny_frame and pet_frame != 0:
		# Match successful!
		score += 1
		if hud:
			(hud as Node).call_deferred("update_score", score)
		
		# Enable confusion after gaining 3 points (score >= 3)
		if score >= CONFUSION_THRESHOLD:
			confusion_enabled = true
		
		# Wait a bit before next round
		await get_tree().create_timer(0.5).timeout
		_start_round()
	else:
		# Wrong match, no match, or timeout - game over
		_game_over()

func _run_confusion_sequence() -> void:
	# Flash symbols up to 3 times
	var flash_count = randi_range(1, 3)
	
	for i in flash_count:
		# Flash a random symbol for 0.3 seconds
		var flash_frame = _choose_random_symbol()
		if sunny:
			sunny.set_frame(flash_frame)
		
		await get_tree().create_timer(0.3).timeout
		
		# Wait random time between flashes (0.3 to 1 second)
		if i < flash_count - 1:  # Don't wait after last flash
			var wait_time = randf_range(0.3, 1.0)
			await get_tree().create_timer(wait_time).timeout
			# Reset to idle briefly
			if sunny:
				sunny.set_frame(0)
			await get_tree().create_timer(0.1).timeout
	
	# After flashing, show final symbol
	var final_frame = _choose_random_symbol()
	if sunny:
		sunny.set_frame(final_frame)

func _choose_random_symbol() -> int:
	# Returns random frame: 1 (heart), 2 (diamond), or 3 (both)
	# Frame 0 (nothing) is not used as Sunny's choice
	return randi_range(1, 3)


func _game_over() -> void:
	game_started = false
	current_round_active = false
	
	# Disable pet input when game over
	if pet:
		pet.disable_input()
	
	if hud:
		(hud as Node).call_deferred("show_game_over", score)
	
	# Save high score
	_save_high_score(score)

func _position_relative_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	var center_x := vp_size.x * 0.5
	# Y Axis sprite positions relative to viewport
	var sunny_y := vp_size.y * 0.55 - 80.0  # Moved up 20 pixels
	var pet_y := vp_size.y * 0.25
	
	if is_instance_valid(sunny):
		sunny.position.x = center_x
		sunny.position.y = sunny_y
	if is_instance_valid(pet):
		pet.position.x = center_x
		pet.position.y = pet_y

func _save_high_score(final_score: int) -> void:
	if not UserData.has_user_id() or not UserData.has_jwt_token():
		print("Cannot save high score: User not authenticated")
		return
	
	# Create HTTPRequest node to make authenticated request
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_save_high_score_completed.bind(http_request))
	
	# Get backend API URL
	var api_base_url = "http://localhost:8080"
	var api_endpoint = api_base_url + "/api/v1/game/save"
	
	# Prepare JSON data
	var json = JSON.new()
	var data = {
		"game_type": "Sunny Says",
		"score": final_score
	}
	var json_string = json.stringify(data)
	
	# Prepare headers with JWT token
	var headers = PackedStringArray([
		"Authorization: Bearer " + UserData.get_jwt_token(),
		"Content-Type: application/json"
	])
	
	# Make POST request
	var error = http_request.request(api_endpoint, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		print("Failed to create HTTP request: ", error)
		http_request.queue_free()

func _on_save_high_score_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest) -> void:
	# Clean up the HTTPRequest node
	if is_instance_valid(http_request):
		http_request.queue_free()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_error = json.parse(body.get_string_from_utf8())
		if parse_error == OK:
			var response_data = json.data
			if response_data != null and response_data.has("high_score"):
				print("High score saved successfully: ", response_data["high_score"])
			else:
				print("High score saved successfully")
		else:
			print("Failed to parse response JSON")
	else:
		print("Failed to save high score. Response code: ", response_code)
