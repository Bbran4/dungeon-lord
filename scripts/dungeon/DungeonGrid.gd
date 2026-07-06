extends Node2D
class_name DungeonGrid

## Renders DungeonManager's room sequence as a horizontal path from an
## entrance to an exit, with drop zones between rooms for building and
## floating upgrade/sell buttons above individual rooms.
##
## Assumes DungeonManager and EconomyManager are autoload singletons.

signal room_selected(index: int, room: Room)

@export var room_scene: PackedScene
@export var spacing: float = 600.0
@export var room_size: Vector2 = Vector2(500, 500)
@export var gap_width: float = 100.0

var room_nodes: Array[Room] = []
var gap_zones: Array[RoomGapZone] = []
var entrance_marker: Node2D
var exit_marker: Node2D

var _selected_index: int = -1


func _ready() -> void:
	DungeonManager.dungeon_generated.connect(_rebuild_layout)
	DungeonManager.room_inserted.connect(_on_dungeon_changed)
	DungeonManager.room_removed.connect(_on_dungeon_changed)
	DungeonManager.room_upgraded.connect(_on_dungeon_changed)

	_create_markers()
	_rebuild_layout()


func _on_dungeon_changed(_a: Variant = null, _b: Variant = null) -> void:
	_rebuild_layout()


## Spends gold and inserts a room at `index`. Used by RoomGapZone drops.
func request_insert(index: int, room_data: RoomData) -> bool:

	if room_data == null:
		return false

	if not EconomyManager.can_afford(room_data.cost):
		return false

	if not EconomyManager.spend_gold(room_data.cost):
		return false

	var inserted: bool = DungeonManager.insert_room(index, room_data)

	if not inserted:
		EconomyManager.add_gold(room_data.cost)

	return inserted


## Spends the cost difference and upgrades the room at `index`.
func request_upgrade(index: int) -> bool:

	var current: RoomData = DungeonManager.get_room(index)

	if current == null or current.upgrade_path == null:
		return false

	var upgrade_cost: int = current.upgrade_path.cost - current.cost

	if upgrade_cost > 0:
		if not EconomyManager.can_afford(upgrade_cost):
			return false
		EconomyManager.spend_gold(upgrade_cost)

	return DungeonManager.upgrade_room(index)


## Removes the room at `index` and refunds half its cost.
func sell_room_at(index: int) -> bool:

	var room_data: RoomData = DungeonManager.get_room(index)

	if room_data == null:
		return false

	var refund: int = int(room_data.cost * 0.5)
	var removed: bool = DungeonManager.remove_room(index)

	if removed:
		EconomyManager.add_gold(refund)

	return removed


## Waypoints for hero movement: entrance, then each room slot, then exit.
func get_path_waypoints() -> Array[Vector2]:

	var waypoints: Array[Vector2] = []

	waypoints.append(entrance_marker.position)

	for room: Room in room_nodes:
		waypoints.append(room.position)

	waypoints.append(exit_marker.position)

	return waypoints


## Maps a waypoint index (from get_path_waypoints) back to its RoomData.
## Index 0 is the entrance and has no room; the last index is the exit.
func get_room_data_at_path_index(path_index: int) -> RoomData:

	var room_index: int = path_index - 1

	return DungeonManager.get_room(room_index)


## Called by a palette/build UI when a matching room card starts dragging.
func show_upgrade_prompts_for(room_name: String) -> void:

	for i: int in room_nodes.size():

		var room_data: RoomData = DungeonManager.get_room(i)

		if room_data != null and room_data.room_name == room_name and room_data.upgrade_path != null:
			room_nodes[i].show_upgrade_prompt(i, room_name)


func hide_upgrade_prompts() -> void:

	for room: Room in room_nodes:
		room.hide_upgrade_prompt()


func _create_markers() -> void:

	entrance_marker = Node2D.new()
	entrance_marker.name = "Entrance"
	add_child(entrance_marker)

	var entrance_label: Label = Label.new()
	entrance_label.text = "Entrance"
	entrance_marker.add_child(entrance_label)

	exit_marker = Node2D.new()
	exit_marker.name = "Exit"
	add_child(exit_marker)

	var exit_label: Label = Label.new()
	exit_label.text = "Exit"
	exit_marker.add_child(exit_label)


func _rebuild_layout() -> void:

	_clear_layout()

	var room_count: int = DungeonManager.room_count()

	entrance_marker.position = Vector2.ZERO
	_add_gap_zone(0)

	for i: int in room_count:

		var room_data: RoomData = DungeonManager.get_room(i)

		var room: Room = room_scene.instantiate() as Room
		add_child(room)
		room.position = Vector2((i + 1) * spacing, 0.0)
		room.set_room(room_data)
		room.room_clicked.connect(_on_room_clicked)
		room.sell_requested.connect(_on_sell_requested)
		room.upgrade_zone.upgrade_requested.connect(_on_upgrade_requested)

		room_nodes.append(room)

		_add_gap_zone(i + 1)

	exit_marker.position = Vector2((room_count + 1) * spacing, 0.0)


func _add_gap_zone(insert_index: int) -> void:

	var zone: RoomGapZone = RoomGapZone.new()
	zone.gap_index = insert_index
	zone.size = Vector2(gap_width, room_size.y)
	zone.position = Vector2((insert_index + 0.5) * spacing - gap_width * 0.5, 0.0)
	zone.drop_requested.connect(_on_gap_drop_requested)

	add_child(zone)
	gap_zones.append(zone)


func _on_gap_drop_requested(gap_index: int, room_data: RoomData) -> void:
	request_insert(gap_index, room_data)


func _on_upgrade_requested(room_index: int) -> void:
	request_upgrade(room_index)
	hide_upgrade_prompts()


func _on_room_clicked(room: Room) -> void:

	var index: int = room_nodes.find(room)

	if index == -1:
		return

	if _selected_index == index:
		_deselect_room()
	else:
		_select_room(index)

	room_selected.emit(index, room)


func _select_room(index: int) -> void:

	_deselect_room()

	_selected_index = index
	room_nodes[index].show_sell_button()


func _deselect_room() -> void:

	if _selected_index != -1 and _selected_index < room_nodes.size():
		room_nodes[_selected_index].hide_sell_button()

	_selected_index = -1


func _on_sell_requested(room: Room) -> void:

	var index: int = room_nodes.find(room)

	if index != -1:
		sell_room_at(index)


func _clear_layout() -> void:

	for room: Room in room_nodes:
		if is_instance_valid(room):
			room.queue_free()

	room_nodes.clear()

	for zone: RoomGapZone in gap_zones:
		if is_instance_valid(zone):
			zone.queue_free()

	gap_zones.clear()

	_selected_index = -1
