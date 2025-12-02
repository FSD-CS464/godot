extends Node2D

var _pet_sprite: AnimatedSprite2D
var _cloud_sprite: AnimatedSprite2D
var current_frame: int = 0
var input_buffer_timer: float = 0.0
var input_enabled: bool = true  # Can be disabled when game is over
const INPUT_BUFFER_TIME: float = 0.05  # Short buffer to allow both keys to register

signal frame_changed(new_frame: int)

func _ready() -> void:
	_pet_sprite = $PetSprite
	_cloud_sprite = $CloudSprite
	
	if _pet_sprite:
		# Stop any animation and set frame directly
		_pet_sprite.stop()
	
	if _cloud_sprite:
		# Stop any animation and set cloud to frame 0 (for singleplayer)
		_cloud_sprite.stop()
		_cloud_sprite.frame = 0
	
	reset_to_idle()

func reset_to_idle() -> void:
	current_frame = 0
	input_buffer_timer = 0.0
	input_enabled = true  # Re-enable input when resetting
	if _pet_sprite:
		_pet_sprite.stop()  # Stop animation if playing
		_pet_sprite.frame = 0
	if _cloud_sprite:
		_cloud_sprite.stop()  # Stop animation if playing
		_cloud_sprite.frame = 0  # Always frame 0 in singleplayer

func _process(delta: float) -> void:
	# Handle input buffer for simultaneous key presses
	if input_buffer_timer > 0.0:
		input_buffer_timer -= delta
		if input_buffer_timer <= 0.0:
			# Buffer time elapsed, check keys now
			_check_keys_after_buffer()

func _input(event: InputEvent) -> void:
	# Don't process input if disabled (e.g., game over)
	if not input_enabled:
		return
	
	# Check for arrow key presses (just pressed, not held)
	if event is InputEventKey and event.pressed:
		# Check if this is a left or right arrow key
		var is_left = event.keycode == KEY_LEFT
		var is_right = event.keycode == KEY_RIGHT
		
		if not is_left and not is_right:
			return
		
		# Start buffer timer to allow both keys to register
		if input_buffer_timer <= 0.0:
			input_buffer_timer = INPUT_BUFFER_TIME

func _check_keys_after_buffer() -> void:
	# Don't process input if disabled (e.g., game over)
	if not input_enabled:
		return
	
	# Check what keys are currently pressed after buffer
	var left_pressed = Input.is_key_pressed(KEY_LEFT)
	var right_pressed = Input.is_key_pressed(KEY_RIGHT)
	
	# Determine which frame based on key combination
	var new_frame: int = 0
	if left_pressed and right_pressed:
		new_frame = 3  # Both
	elif left_pressed:
		new_frame = 1  # Heart only
	elif right_pressed:
		new_frame = 2  # Diamond/Star only
	
	# Update frame if it changed (allow changes at any time)
	if new_frame != current_frame:
		current_frame = new_frame
		if _pet_sprite:
			_pet_sprite.stop()  # Stop animation if playing
			_pet_sprite.frame = current_frame
		frame_changed.emit(current_frame)

func get_current_frame() -> int:
	return current_frame

func disable_input() -> void:
	input_enabled = false

func enable_input() -> void:
	input_enabled = true
