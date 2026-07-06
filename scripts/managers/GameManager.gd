extends Node

signal game_started
signal game_over
signal building_phase_started
signal combat_phase_started
signal reward_phase_started
signal victory_started

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

## Terminal state - reached only via TestHarness._on_wave_cleared when
## a full wipe lands on WaveManager.max_wave. Nothing currently
## transitions OUT of VICTORY except a full _reset_test() (which calls
## start_game() again).
func start_victory() -> void:
	current_state = GameEnums.GameState.VICTORY
	victory_started.emit()

func end_game() -> void:
	current_state = GameEnums.GameState.GAME_OVER
	game_over.emit()
