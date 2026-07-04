extends Node2D
class_name Room

signal room_clicked(room: Room)

@export var room_data: RoomData

var monster: Node = null
var hero: Node = null


func set_room(data: RoomData) -> void:

	room_data = data

	update_visuals()


func update_visuals() -> void:

	if room_data == null:
		return

	$Label.text = room_data.room_name


func _on_button_pressed() -> void:

	room_clicked.emit(self)
