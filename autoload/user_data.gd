extends Node

# Persistent user data storage across scenes
var user_id: String = ""
var jwt_token: String = ""

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
