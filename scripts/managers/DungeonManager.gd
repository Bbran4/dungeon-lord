extends Node

signal room_placed(room_index, room_data)
signal room_removed(room_index)
signal dungeon_generated

var rooms: Array = []


func generate_dungeon(size: int) -> void:
	rooms.clear()

	for i in size:
		rooms.append(null)

	dungeon_generated.emit()


func place_room(index: int, room_data: RoomData) -> bool:

	if index < 0 or index >= rooms.size():
		return false

	rooms[index] = room_data

	room_placed.emit(index, room_data)

	return true


func remove_room(index: int) -> void:

	if index < 0 or index >= rooms.size():
		return

	rooms[index] = null

	room_removed.emit(index)


func get_room(index: int):

	if index < 0 or index >= rooms.size():
		return null

	return rooms[index]
