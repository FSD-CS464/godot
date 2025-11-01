extends CanvasLayer

var _jump_rope_button: Button
var _sunny_says_button: Button
var _mine_race_button: Button

var high_scores: Dictionary = {
	"Jump Rope": 0,
	"Sunny Says": 0,
	"Mine Race": 0
}

func _ready() -> void:
	_jump_rope_button = $Root/MainContainer/ButtonsContainer/JumpRopeButton
	_sunny_says_button = $Root/MainContainer/ButtonsContainer/SunnySaysButton
	_mine_race_button = $Root/MainContainer/ButtonsContainer/MineRaceButton
	
	# Connect button signals
	_jump_rope_button.pressed.connect(_on_jump_rope_pressed)
	_sunny_says_button.pressed.connect(_on_sunny_says_pressed)
	_mine_race_button.pressed.connect(_on_mine_race_pressed)
	
	# Update high score displays
	_update_high_scores()

func _update_high_scores() -> void:
	var jump_rope_score = $Root/MainContainer/HighScoresContainer/JumpRopeScoreContainer/JumpRopeScore
	var sunny_says_score = $Root/MainContainer/HighScoresContainer/SunnySaysScoreContainer/SunnySaysScore
	var mine_race_score = $Root/MainContainer/HighScoresContainer/MineRaceScoreContainer/MineRaceScore
	
	jump_rope_score.text = str(high_scores["Jump Rope"])
	sunny_says_score.text = str(high_scores["Sunny Says"])
	mine_race_score.text = str(high_scores["Mine Race"])

func _on_jump_rope_pressed() -> void:
	get_tree().change_scene_to_file("res://jump-rope-level/jump-rope-main.tscn")

func _on_sunny_says_pressed() -> void:
	# TODO: Implement when Sunny Says is created
	pass

func _on_mine_race_pressed() -> void:
	# TODO: Implement when Mine Race is created
	pass
