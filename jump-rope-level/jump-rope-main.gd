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

func _position_relative_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	var center_x := vp_size.x * 0.5
	# Y Axis sprite positions relative to viewport
	var map_y := vp_size.y * 0.08
	var rope_y := vp_size.y * 0.20
	var pet_y := vp_size.y * 0.58
	if is_instance_valid(map):
		map.position.x = center_x
		map.position.y = map_y
	if is_instance_valid(rope):
		rope.position.x = center_x
		rope.position.y = rope_y
	if is_instance_valid(pet):
		pet.position.x = center_x
		pet.position.y = pet_y
