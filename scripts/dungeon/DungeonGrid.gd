extends Node2D
class_name DungeonGrid

## Renders DungeonManager's room sequence as a horizontal path from an
## entrance to an exit. Rooms sit edge-to-edge (Room's own local origin
## is its visual center, so this is just `index * room_size.x`); a thin
## RoomGapZone straddles each seam as a drop target for inserting new
## rooms, the same way a video editor shows a transition control between
## two clips. Entrance and exit are drawn as darker placeholder rooms so
## their footprint is visible even though they hold no RoomData.
##
## Assumes DungeonManager and EconomyManager are autoload singletons.

signal room_selected(index: int, room: Room)

@export var room_scene: PackedScene
@export var room_size: Vector2 = Vector2(500, 500)
@export var gap_width: float = 20.0

const MARKER_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)

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

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return false

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

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return false

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

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return false

	var room_data: RoomData = DungeonManager.get_room(index)

	if room_data == null:
		return false

	var refund: int = int(room_data.cost * 0.5)
	var removed: bool = DungeonManager.remove_room(index)

	if removed:
		EconomyManager.add_gold(refund)

	return removed


## Waypoints for hero movement: entrance, then each room slot, then exit.
## Every position is the vertical center of its room, so a hero walking
## this path stays centered top-to-bottom the whole way through.
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


## Slot 0 is the entrance, 1..room_count are rooms, room_count + 1 is the
## exit. Rooms sit edge-to-edge because each is `room_size.x` wide and
## its own origin is its center, so this is simply `slot * room_size.x`.
func _slot_center_x(slot: int) -> float:
	return slot * room_size.x


func _create_markers() -> void:
	entrance_marker = _build_marker("Entrance")
	add_child(entrance_marker)

	exit_marker = _build_marker("Exit")
	add_child(exit_marker)


func _build_marker(label_text: String) -> Node2D:

	var marker: Node2D = Node2D.new()
	marker.name = label_text

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = MARKER_COLOR
	backdrop.position = room_size * -0.5
	backdrop.size = room_size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(backdrop)

	var label: Label = Label.new()
	label.text = label_text
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -60.0
	label.offset_right = 60.0
	label.offset_top = -12.0
	label.offset_bottom = 12.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)

	return marker


func _rebuild_layout() -> void:

	_clear_layout()

	var room_count: int = DungeonManager.room_count()

	entrance_marker.position = Vector2(_slot_center_x(0), 0.0)
	_add_gap_zone(0)

	for i: int in room_count:

		var room_data: RoomData = DungeonManager.get_room(i)

		var room: Room = room_scene.instantiate() as Room
		add_child(room)
		room.position = Vector2(_slot_center_x(i + 1), 0.0)
		room.set_room(room_data)
		room.room_clicked.connect(_on_room_clicked)
		room.sell_requested.connect(_on_sell_requested)
		room.upgrade_zone.upgrade_requested.connect(_on_upgrade_requested)

		room_nodes.append(room)

		_add_gap_zone(i + 1)

	exit_marker.position = Vector2(_slot_center_x(room_count + 1), 0.0)


func _add_gap_zone(insert_index: int) -> void:

	var zone: RoomGapZone = RoomGapZone.new()
	zone.gap_index = insert_index
	zone.z_index = 1 # always draw above rooms, regardless of sibling order

	var seam_x: float = (_slot_center_x(insert_index) + _slot_center_x(insert_index + 1)) * 0.5

	zone.size = Vector2(gap_width, room_size.y)
	zone.position = Vector2(seam_x - gap_width * 0.5, room_size.y * -0.5)
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
