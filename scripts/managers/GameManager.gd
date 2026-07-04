extends Node

signal game_started
signal game_over
signal building_phase_started
signal combat_phase_started
signal reward_phase_started

enum GameState {
	MENU,
	BUILDING,
	COMBAT,
	REWARD,
	GAME_OVER
}

var current_state: GameState = GameState.MENU


func start_game() -> void:
	current_state = GameState.BUILDING
	game_started.emit()
	building_phase_started.emit()


func start_building_phase() -> void:
	current_state = GameState.BUILDING
	building_phase_started.emit()


func start_combat_phase() -> void:
	current_state = GameState.COMBAT
	combat_phase_started.emit()


func start_reward_phase() -> void:
	current_state = GameState.REWARD
	reward_phase_started.emit()


func end_game() -> void:
	current_state = GameState.GAME_OVER
	game_over.emit()
