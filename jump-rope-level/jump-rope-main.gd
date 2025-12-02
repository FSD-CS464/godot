extends Node2D

@onready var pet := $Pet
@onready var map := $map
@onready var rope := $rope

var hud: CanvasLayer
var score: int = 0
var game_started: bool = false
const COUNTDOWN_VALUES := ["3", "2", "1", "START"]

func _ready() -> void:
	# Ensure children are ready
	await get_tree().process_frame
	# Use HUD instance already in the scene
	hud = $HUD
	# Position along center X and sensible relative Y; connect resize
	_position_relative_to_viewport()
	get_viewport().size_changed.connect(_position_relative_to_viewport)
	# Prepare rope
	rope.reset_speed()
	rope.rope_looped.connect(_on_rope_looped)
	rope.rope_hit.connect(_on_rope_hit)
	# Make sure default animations are set
	if rope.has_method("stop_swing"):
		rope.stop_swing()
	if pet.has_node("PetAnimatedSprite"):
		pet.get_node("PetAnimatedSprite").play("default")
	# Start countdown then game
	await _run_countdown()
	_start_game()

func _run_countdown() -> void:
	for i in COUNTDOWN_VALUES.size():
		var text: String = COUNTDOWN_VALUES[i]
		(hud as Node).call_deferred("show_countdown_text", text, true)
		await get_tree().create_timer(1.0).timeout
	# Hide countdown label
	(hud as Node).call_deferred("show_countdown_text", "", false)

func _start_game() -> void:
	score = 0
	(hud as Node).call_deferred("update_score", score)
	game_started = true
	if pet and pet.has_method("set_can_jump"):
		pet.set_can_jump(true)
	rope.set_score_for_difficulty(score)
	rope.start_swing()

func _on_rope_looped() -> void:
	if not game_started:
		return
	score += 1
	(hud as Node).call_deferred("update_score", score)
	rope.set_score_for_difficulty(score)

func _on_rope_hit() -> void:
	if not game_started:
		return
	game_started = false
	if pet and pet.has_method("set_can_jump"):
		pet.set_can_jump(false)
	if rope.has_method("stop_swing"):
		rope.stop_swing()
	(hud as Node).call_deferred("show_game_over", score)
	# Save high score to backend
	_save_high_score(score)

func _position_relative_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	var center_x := vp_size.x * 0.5
	# Y Axis sprite positions relative to viewport
	var map_y := vp_size.y * 0.05
	var rope_y := vp_size.y * 0.20
	var pet_y := vp_size.y * 0.55
	if is_instance_valid(map):
		map.position.x = center_x
		map.position.y = map_y
	if is_instance_valid(rope):
		rope.position.x = center_x
		rope.position.y = rope_y
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
		"game_type": "Jump Rope",
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
