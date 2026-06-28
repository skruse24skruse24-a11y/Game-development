extends Node

## GameManager is an autoload singleton for tracking global game state.
##
## It is registered in project.godot under [autoload] so it is always
## available as "GameManager" from any script:
##
##   GameManager.add_score(10)
##   GameManager.score_changed.connect(_on_score_changed)

var score: int = 0
var lives: int = 3

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)

## Add points to the current score and emit score_changed.
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

## Subtract one life and emit lives_changed; triggers game_over when none remain.
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		_game_over()

## Reset score and lives back to their starting values.
func reset() -> void:
	score = 0
	lives = 3
	score_changed.emit(score)
	lives_changed.emit(lives)

## Called automatically when lives reach zero. Returns to the main menu.
## To change this behavior, override this method in a derived class or
## add your own game-over logic before calling super._game_over().
func _game_over() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
