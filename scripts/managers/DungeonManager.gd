extends Node

## Holds the dungeon as an ordered sequence of rooms from entrance to exit.
## Rooms are always contiguous (no empty-slot gaps) since the layout is a
## linear path rather than a fixed grid.
## Hard cap on how many rooms the dungeon can hold. DungeonGrid enforces
## this by rejecting request_insert() once room_count() reaches it, and
## locking every RoomGapZone so none of them can even accept a drop.
@export var max_rooms: int = 6

signal dungeon_generated
signal room_inserted(index: int, room_data: RoomData)
signal room_removed(index: int)
signal room_upgraded(index: int, room_data: RoomData)
signal boss_room_changed(room_data: RoomData)

var rooms: Array[RoomData] = []

## The dungeon's fixed boss room, if the active biome has one. Unlike
## `rooms`, this is never inserted, sold, or upgraded by the player -
## it's set once per run (see set_boss_room, normally called right
## after generate_dungeon() from BiomeManager) and DungeonGrid always
## renders it as one extra room after every player-built room, right
## before the exit. It does NOT count against max_rooms.
var boss_room: RoomData = null


func generate_dungeon(initial_rooms: Array[RoomData] = []) -> void:
	rooms = initial_rooms.duplicate()
	dungeon_generated.emit()


func set_boss_room(room_data: RoomData) -> void:
	boss_room = room_data
	boss_room_changed.emit(room_data)


func room_count() -> int:
	return rooms.size()


func get_room(index: int) -> RoomData:

	if index < 0 or index >= rooms.size():
		return null

	return rooms[index]


func insert_room(index: int, room_data: RoomData) -> bool:

	if room_data == null:
		return false

	index = clampi(index, 0, rooms.size())
	rooms.insert(index, room_data)

	room_inserted.emit(index, room_data)

	return true


func remove_room(index: int) -> bool:

	if index < 0 or index >= rooms.size():
		return false

	rooms.remove_at(index)

	room_removed.emit(index)

	return true


func upgrade_room(index: int) -> bool:

	if index < 0 or index >= rooms.size():
		return false

	var current: RoomData = rooms[index]

	if current == null or current.upgrade_path == null:
		return false

	rooms[index] = current.upgrade_path

	room_upgraded.emit(index, rooms[index])

	return true
