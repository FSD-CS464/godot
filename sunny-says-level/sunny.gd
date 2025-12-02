extends Node2D

var _animated_sprite: AnimatedSprite2D

func _ready() -> void:
	_animated_sprite = $AnimatedSprite2D
	if _animated_sprite:
		# Stop any animation and set frame directly
		_animated_sprite.stop()
		reset_to_idle()

func reset_to_idle() -> void:
	if _animated_sprite:
		_animated_sprite.stop()  # Stop animation if playing
		_animated_sprite.frame = 0

func set_frame(frame: int) -> void:
	if _animated_sprite:
		_animated_sprite.stop()  # Stop animation if playing
		_animated_sprite.frame = clamp(frame, 0, 3)

func get_current_frame() -> int:
	if _animated_sprite:
		return _animated_sprite.frame
	return 0
