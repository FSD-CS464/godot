extends Node

# Persistent user data storage across scenes
var user_id: String = ""
var jwt_token: String = ""

# API configuration
const API_BASE_URL = "http://localhost:8080"  # TODO: Update for production

func set_user_id(uid: String) -> void:
	user_id = uid

func get_user_id() -> String:
	return user_id

func has_user_id() -> bool:
	return not user_id.is_empty()

func set_jwt_token(token: String) -> void:
	jwt_token = token

func get_jwt_token() -> String:
	return jwt_token

func has_jwt_token() -> bool:
	return not jwt_token.is_empty()

# API Helper Functions

# Make an authenticated GET request
func api_get(endpoint: String, callback: Callable) -> HTTPRequest:
	if not has_jwt_token():
		print("No JWT token available for API request")
		return null
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_api_request_completed.bind(http_request, callback))
	
	var full_url = API_BASE_URL + endpoint
	var headers = PackedStringArray([
		"Authorization: Bearer " + jwt_token,
		"Content-Type: application/json"
	])
	
	var error = http_request.request(full_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("Failed to create HTTP GET request: ", error)
		http_request.queue_free()
		return null
	
	return http_request

# Make an authenticated POST request
func api_post(endpoint: String, data: Dictionary, callback: Callable) -> HTTPRequest:
	if not has_jwt_token():
		print("No JWT token available for API request")
		return null
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_api_request_completed.bind(http_request, callback))
	
	var full_url = API_BASE_URL + endpoint
	var headers = PackedStringArray([
		"Authorization: Bearer " + jwt_token,
		"Content-Type: application/json"
	])
	
	var json = JSON.new()
	var json_string = json.stringify(data)
	
	var error = http_request.request(full_url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		print("Failed to create HTTP POST request: ", error)
		http_request.queue_free()
		return null
	
	return http_request

func _on_api_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest, callback: Callable) -> void:
	# Clean up the HTTPRequest node
	if is_instance_valid(http_request):
		http_request.queue_free()
	
	# Parse response
	var response_data = null
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_error = json.parse(body.get_string_from_utf8())
		if parse_error == OK:
			response_data = json.data
		else:
			print("Failed to parse response JSON")
	
	# Call the callback with result, response_code, and response_data
	if callback.is_valid():
		callback.call(result, response_code, response_data)
