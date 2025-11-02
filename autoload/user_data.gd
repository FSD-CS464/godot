extends Node

# Persistent user data storage across scenes
var user_id: String = ""

func set_user_id(uid: String) -> void:
	user_id = uid

func get_user_id() -> String:
	return user_id

func has_user_id() -> bool:
	return not user_id.is_empty()
