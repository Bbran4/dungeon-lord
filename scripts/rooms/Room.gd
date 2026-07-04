extends Node2D
class_name Room

signal room_clicked(room)

@export var room_data : RoomData

var monster = null
var hero = null


func set_room(data : RoomData):

	room_data = data

	update_visuals()


func update_visuals():

	if room_data == null:
		return

	$Label.text = room_data.room_name


func _on_button_pressed():

	room_clicked.emit(self)
