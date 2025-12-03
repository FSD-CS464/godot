extends CanvasLayer

var _back_button: TextureButton

func _ready() -> void:
	_back_button = $Root/BackButton
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/menu.tscn")

