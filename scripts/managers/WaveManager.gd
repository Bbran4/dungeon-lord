extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

@export var starting_wave: int = 1

var current_wave: int = 0


func reset() -> void:
	current_wave = starting_wave - 1


func start_next_wave() -> void:

	current_wave += 1

	wave_started.emit(current_wave)


func complete_wave() -> void:

	wave_completed.emit(current_wave)
