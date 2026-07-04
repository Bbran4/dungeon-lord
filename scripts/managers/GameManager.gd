extends Node

signal game_started
signal game_over
signal building_phase_started
signal combat_phase_started
signal reward_phase_started

var current_state: GameEnums.GameState = GameEnums.GameState.MENU


func start_game() -> void:
	current_state = GameEnums.GameState.BUILDING
	game_started.emit()
	building_phase_started.emit()


func start_building_phase() -> void:
	current_state = GameEnums.GameState.BUILDING
	building_phase_started.emit()


func start_combat_phase() -> void:
	current_state = GameEnums.GameState.COMBAT
	combat_phase_started.emit()


func start_reward_phase() -> void:
	current_state = GameEnums.GameState.REWARD
	reward_phase_started.emit()


func end_game() -> void:
	current_state = GameEnums.GameState.GAME_OVER
	game_over.emit()
