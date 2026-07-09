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
## CARD-BASED PLACEMENT: dropping a room onto a RoomGapZone no longer
## charges gold directly - it consumes one matching card from
## CardHandManager's hand (see request_insert). The gold cost was
## already paid when the card was acquired (a starter card, or bought
## in the shop via ShopManager.buy_room / a card pack). RoomData.cost
## still drives the shop's price and a room's sell refund - it's just
## not charged a second time here.
##
## BOSS ROOM: DungeonManager.boss_room is a second, separate room slot
## that always renders as one extra room after every player-built room
## and before the exit - never insertable-into, sellable, or
## upgradable, and never counted against max_rooms. Set once per run
## via DungeonManager.set_boss_room() (see BiomeManager). This is
## rendered with its own dedicated node (boss_room_node), kept entirely
## out of room_nodes so none of the player-room interaction logic
## (selection, sell, upgrade, gap-zone math) can ever touch it.
##
## Assumes DungeonManager, EconomyManager, and CardHandManager are
## autoload singletons.

signal room_selected(index: int, room: Room)
signal room_placed(room_data: RoomData)

@export var room_scene: PackedScene
@export var room_size: Vector2 = Vector2(500, 500)
@export var gap_width: float = 20.0

const MARKER_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)

var room_nodes: Array[Room] = []
var gap_zones: Array[RoomGapZone] = []
var entrance_marker: Node2D
var exit_marker: Node2D

## The dedicated visual node for DungeonManager.boss_room, or null if
## the active biome has no boss room set. Never appears in room_nodes.
var boss_room_node: Room = null

## path_index (as used by get_path_waypoints/get_room_data_at_path_index)
## -> RoomData, rebuilt every _rebuild_layout(). Covers both player
## rooms and the trailing boss room slot, so callers don't need to
## know which is which.
var _room_data_by_path_index: Dictionary = {}

var _selected_index: int = -1


func _ready() -> void:
	DungeonManager.dungeon_generated.connect(_rebuild_layout)
	DungeonManager.room_inserted.connect(_on_dungeon_changed)
	DungeonManager.room_removed.connect(_on_dungeon_changed)
	DungeonManager.room_upgraded.connect(_on_dungeon_changed)
	DungeonManager.boss_room_changed.connect(_on_dungeon_changed)

	_create_markers()
	_rebuild_layout()
	_update_gap_zone_lock_state()

func _on_dungeon_changed(_a: Variant = null, _b: Variant = null) -> void:
	_rebuild_layout()


## Consumes a matching card from the player's hand and inserts a room
## at `index`. Used by RoomGapZone drops. Refuses if the card isn't
## actually in hand - dragging is only possible from an existing
## RoomCard in the hand UI, so this should normally always succeed,
## but it's checked explicitly rather than assumed.
func request_insert(index: int, room_data: RoomData) -> bool:

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return false

	if DungeonManager.room_count() >= DungeonManager.max_rooms:
		return false

	if room_data == null:
		return false

	if not CardHandManager.remove_card(room_data):
		return false

	var inserted: bool = DungeonManager.insert_room(index, room_data)

	if not inserted:
		# Give the card back - the insert itself failed for some other
		# reason (shouldn't normally happen given the checks above, but
		# this keeps a failed insert from silently burning a card the
		# player paid for).
		CardHandManager.add_card(room_data)

	_update_gap_zone_lock_state()

	if inserted:
		room_placed.emit(room_data)

	return inserted

## Spends the cost difference and upgrades the room at `index`. Upgrade
## cards are NOT part of the hand system - they remain always-available
## in the palette, gold-charged at the cost delta, same as before.
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

	_update_gap_zone_lock_state()

	return removed


## Waypoints for hero movement: entrance, then each player room slot,
## then the boss room (if any), then exit. Every position is the
## vertical center of its room, so a hero walking this path stays
## centered top-to-bottom the whole way through.
func get_path_waypoints() -> Array[Vector2]:

	var waypoints: Array[Vector2] = []

	waypoints.append(entrance_marker.position)

	for room: Room in room_nodes:
		waypoints.append(room.position)

	if is_instance_valid(boss_room_node):
		waypoints.append(boss_room_node.position)

	waypoints.append(exit_marker.position)

	return waypoints


## Maps a waypoint index (from get_path_waypoints) back to its RoomData.
## Index 0 is the entrance and has no room; the last index is the exit.
## Backed by a lookup table rebuilt every _rebuild_layout(), rather than
## arithmetic, since the boss room makes the mapping non-uniform.
func get_room_data_at_path_index(path_index: int) -> RoomData:
	return _room_data_by_path_index.get(path_index, null)


## Called by a palette/build UI when a matching room card starts dragging.
func show_upgrade_prompts_for(dragged_room_data: RoomData) -> void:

	for i: int in room_nodes.size():

		var current: RoomData = DungeonManager.get_room(i)

		if current != null and current.upgrade_path == dragged_room_data:
			room_nodes[i].show_upgrade_prompt(i)


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
		_room_data_by_path_index[i + 1] = room_data

		_add_gap_zone(i + 1)

	var trailing_slot: int = room_count + 1

	if DungeonManager.boss_room != null:

		boss_room_node = room_scene.instantiate() as Room
		add_child(boss_room_node)
		boss_room_node.position = Vector2(_slot_center_x(trailing_slot), 0.0)
		boss_room_node.set_room(DungeonManager.boss_room)
		# Deliberately NOT connected to room_clicked / sell_requested /
		# upgrade_zone - the boss room can't be selected, sold, or
		# upgraded, it's fixed for the whole run.

		_room_data_by_path_index[trailing_slot] = DungeonManager.boss_room

		trailing_slot += 1

	exit_marker.position = Vector2(_slot_center_x(trailing_slot), 0.0)


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

## Locks/unlocks every gap zone based on whether the dungeon is
## currently at its room cap. Called once in _ready() and again after
## any successful insert or sell, since either can cross the cap. The
## boss room is intentionally excluded from this check - it never
## counts against max_rooms.
func _update_gap_zone_lock_state() -> void:

	var at_cap: bool = DungeonManager.room_count() >= DungeonManager.max_rooms

	for zone: RoomGapZone in gap_zones:
		zone.set_locked(at_cap)

func _clear_layout() -> void:

	for room: Room in room_nodes:
		if is_instance_valid(room):
			room.queue_free()

	room_nodes.clear()

	if is_instance_valid(boss_room_node):
		boss_room_node.queue_free()
	boss_room_node = null

	_room_data_by_path_index.clear()

	for zone: RoomGapZone in gap_zones:
		if is_instance_valid(zone):
			zone.queue_free()

	gap_zones.clear()

	_selected_index = -1
