extends Node2D
class_name DungeonGrid

## Emitted when a Room is clicked, so a UI (build menu, info panel, etc.)
## can react without DungeonGrid needing to know about any UI.
signal room_selected(index: int, room: Room)

@export var room_scene: PackedScene
@export var columns: int = 5
@export var cell_size: Vector2 = Vector2(520, 520)

var room_nodes: Array[Room] = []


func _ready() -> void:
	# Assumes DungeonManager and EconomyManager are autoload singletons.
	# Project Settings -> Autoload, name them exactly "DungeonManager"
	# and "EconomyManager" if they aren't already.
	DungeonManager.room_placed.connect(_on_room_placed)
	DungeonManager.room_removed.connect(_on_room_removed)


## Builds a fresh grid of `size` empty room slots and resets the
## dungeon's data to match.
func build_grid(size: int) -> void:

	_clear_grid()

	DungeonManager.generate_dungeon(size)

	for i: int in size:

		var room: Room = room_scene.instantiate() as Room

		add_child(room)

		room.position = _index_to_position(i)
		room.room_clicked.connect(_on_room_clicked)
		room.set_room(null)

		room_nodes.append(room)


## Attempts to place a room at `index`, spending gold first.
## Returns false if the slot is invalid, the player can't afford it,
## or the placement itself fails.
func place_room_at(index: int, room_data: RoomData) -> bool:

	if index < 0 or index >= room_nodes.size():
		return false

	if room_data == null:
		return false

	if not EconomyManager.can_afford(room_data.cost):
		return false

	if not EconomyManager.spend_gold(room_data.cost):
		return false

	var placed: bool = DungeonManager.place_room(index, room_data)

	if not placed:
		# Refund if placement failed after gold was already spent.
		EconomyManager.add_gold(room_data.cost)

	return placed


## Clears the room at `index` back to empty. Does not refund gold.
func remove_room_at(index: int) -> void:
	DungeonManager.remove_room(index)


func _on_room_placed(index: int, room_data: RoomData) -> void:

	if index < 0 or index >= room_nodes.size():
		return

	room_nodes[index].set_room(room_data)


func _on_room_removed(index: int) -> void:

	if index < 0 or index >= room_nodes.size():
		return

	room_nodes[index].set_room(null)


func _on_room_clicked(room: Room) -> void:

	var index: int = room_nodes.find(room)

	room_selected.emit(index, room)


func _index_to_position(index: int) -> Vector2:

	var column: int = index % columns
	var row: int = index / columns

	return Vector2(column, row) * cell_size


func _clear_grid() -> void:

	for room: Room in room_nodes:
		if is_instance_valid(room):
			room.queue_free()

	room_nodes.clear()
