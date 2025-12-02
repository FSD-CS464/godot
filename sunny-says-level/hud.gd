extends CanvasLayer

@export var ui_font: FontFile

var _countdown_label: Label
var _score_label: Label
var _game_over_panel: PanelContainer
var _final_score_label: Label
var _return_button: Button
var _wait_choice_panel: PanelContainer
var _wait_button: Button
var _singleplayer_button: Button
var _wait_label: Label

func _ready() -> void:
	_countdown_label = $Root/CountdownLabel
	_score_label = $Root/ScoreLabel
	_game_over_panel = $Root/GameOverPanel
	_final_score_label = $Root/GameOverPanel/VBox/FinalScoreLabel
	_return_button = $Root/GameOverPanel/VBox/ReturnButton
	_wait_choice_panel = $Root/WaitChoicePanel
	_wait_label = $Root/WaitChoicePanel/VBox/WaitLabel
	_wait_button = $Root/WaitChoicePanel/VBox/WaitButton
	_singleplayer_button = $Root/WaitChoicePanel/VBox/SingleplayerButton
	
	# Connect buttons
	_return_button.pressed.connect(_on_return_button_pressed)
	_wait_button.pressed.connect(_on_wait_button_pressed)
	_singleplayer_button.pressed.connect(_on_singleplayer_button_pressed)
	
	# Hide wait choice panel initially
	_wait_choice_panel.visible = false
	# Apply font if provided
	if ui_font:
		var font_theme := Theme.new()
		font_theme.set_font("font", "Label", ui_font)
		$Root.theme = font_theme
	else:
		var fallback_font := load("res://fonts/TsunagiGothic.ttf") as FontFile
		if fallback_font:
			ui_font = fallback_font
			var font_theme2 := Theme.new()
			font_theme2.set_font("font", "Label", ui_font)
			$Root.theme = font_theme2

func show_countdown_text(text: String, visible_flag: bool) -> void:
	_countdown_label.text = text
	_countdown_label.visible = visible_flag

func update_score(score: int) -> void:
	_score_label.text = "Score: %d" % score

func show_game_over(score: int) -> void:
	_final_score_label.text = "Score: %d" % score
	_game_over_panel.visible = true
	show_countdown_text("", false)

func show_wait_choice() -> void:
	_wait_choice_panel.visible = true

func hide_wait_choice() -> void:
	_wait_choice_panel.visible = false

func show_searching(show: bool) -> void:
	if show:
		_countdown_label.text = "Searching for match..."
		_countdown_label.visible = true
	else:
		_countdown_label.text = ""
		_countdown_label.visible = false

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/menu.tscn")

signal wait_chosen
signal singleplayer_chosen

func _on_wait_button_pressed() -> void:
	wait_chosen.emit()

func _on_singleplayer_button_pressed() -> void:
	singleplayer_chosen.emit()

