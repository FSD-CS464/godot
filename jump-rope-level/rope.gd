extends Area2D

signal rope_looped
signal rope_hit

@export var min_speed_scale: float = 0.5
@export var max_speed_scale: float = 1.5
@export var z_index_in_front: int = 10
@export var z_index_behind: int = -10

var current_speed_scale: float = 0.5
var score_for_difficulty: int = 0

var _animated_sprite: AnimatedSprite2D
var _collision_polygon: CollisionPolygon2D
var _last_frame_index: int = -1

func _ready() -> void:
	_animated_sprite = $AnimatedSprite2D
	_collision_polygon = $CollisionPolygon2D
	# Start in default animation and disable collision until game starts
	_animated_sprite.play("default")
	_animated_sprite.speed_scale = current_speed_scale
	_collision_polygon.disabled = true
	_animated_sprite.frame_changed.connect(_on_frame_changed)
	# Using frame wrap detection for loop events
	_last_frame_index = _animated_sprite.frame
	body_entered.connect(_on_body_entered)

func start_swing() -> void:
	_animated_sprite.play("swing")
	_animated_sprite.speed_scale = current_speed_scale

func stop_swing() -> void:
	_animated_sprite.play("default")
	_collision_polygon.disabled = true

func set_score_for_difficulty(new_score: int) -> void:
	score_for_difficulty = new_score

func _process(_delta: float) -> void:
	# Detect animation loops by observing frame wrap-around while in swing
	if _animated_sprite.animation == "swing":
		var frame_now := _animated_sprite.frame
		var total_frames := _animated_sprite.sprite_frames.get_frame_count("swing")
		if _last_frame_index == total_frames - 1 and frame_now == 0:
			_emit_loop_and_maybe_adjust_speed()
		_last_frame_index = frame_now

func _on_frame_changed() -> void:
	# Enable hitbox only on frame index 3 for the swing animation
	if _animated_sprite.animation == "swing":
		var is_active_frame := _animated_sprite.frame == 4
		_collision_polygon.disabled = not is_active_frame
		# On frame index 5, render behind the pet; otherwise render in front
		if _animated_sprite.frame == 5:
			z_index = z_index_behind
		else:
			z_index = z_index_in_front
	else:
		_collision_polygon.disabled = true

func _on_body_entered(_body: Node) -> void:
	# Only valid hit during the active frame; collision is disabled otherwise
	emit_signal("rope_hit")

func _emit_loop_and_maybe_adjust_speed() -> void:
	emit_signal("rope_looped")
	# After 5 points, increase chance of random speed changes as score grows
	if score_for_difficulty >= 5:
		var difficulty: float = clamp((float(score_for_difficulty) - 4.0) / 10.0, 0.0, 1.0)
		# Probability between ~15% and ~70%
		var change_probability: float = lerp(0.15, 0.7, difficulty)
		if randf() < change_probability:
			# Randomly nudge speed up or down
			var delta := randf_range(-0.25, 0.35)
			current_speed_scale = clamp(current_speed_scale + delta, min_speed_scale, max_speed_scale)
			_animated_sprite.speed_scale = current_speed_scale

func reset_speed() -> void:
	current_speed_scale = min_speed_scale
	if is_instance_valid(_animated_sprite):
		_animated_sprite.speed_scale = current_speed_scale
