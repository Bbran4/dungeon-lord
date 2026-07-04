extends Node

signal wave_started(wave_number)
signal wave_completed(wave_number)

@export var starting_wave := 1

var current_wave := 0


func reset() -> void:
	current_wave = starting_wave - 1


func start_next_wave() -> void:

	current_wave += 1

	wave_started.emit(current_wave)


func complete_wave() -> void:

	wave_completed.emit(current_wave)
