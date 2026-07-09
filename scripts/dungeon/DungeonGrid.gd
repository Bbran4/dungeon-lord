extends Node2D
class_name DungeonGrid

## Renders DungeonManager's sparse grid as an actual 2D layout instead
## of a single horizontal row. Every empty in-bounds cell gets a
## RoomGapZone (visible only during a RoomCard drag, and only if
## DungeonManager.can_place_at(cell) is true at that moment); every
## occupied cell gets a real Room node.
##
## DOORWAYS ARE DERIVED, NEVER AUTHORED: a room's 4 edge doors simply
## reflect DungeonManager.is_passable() on its neighbors at render
## time (see _apply_doors) - there's no door-configuration field
## anywhere on RoomData. This is what makes "the grid decides the
## doors" rather than "the content author decides the doors."
##
## THE BOSS ROOM renders wherever DungeonManager.boss_cell currently
## is (if it's been placed at all - see DungeonManager.UNPLACED_CELL).
## Boss PLACEMENT UI is deliberately not built yet (deferred by
## agreement) - this only renders it once boss_cell is set some other
## way (e.g. a direct DungeonManager.set_boss_cell() call for testing).
##
## STAGE 3 DEPENDENCY: Dungeon.gd's movement loop still expects the
## old linear get_path_waypoints()/get_room_data_at_path_index() API,
## which no longer exists here. Building/placement works standalone;
## sending a wave does not, until Dungeon.gd is updated to consume
## DungeonManager.get_shortest_path() instead.
##
## Assumes DungeonManager, EconomyManager, and CardHandManager are
## autoload singletons.

signal room_selected(cell: Vector2i, room: Room)
signal room_placed(room_data: RoomData)

@export var room_scene: PackedScene
@export var room_size: Vector2 = Vector2(250, 250)

const MARKER_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)
const NO_SELECTION: Vector2i = Vector2i(-1, -1)

var room_nodes: Dictionary = {}  # Vector2i -> Room, player-built rooms only
var cell_zones: Dictionary = {}  # Vector2i -> RoomGapZone, one per empty in-bounds cell
var boss_room_node: Room = null
var entrance_marker: Node2D

var _selected_cell: Vector2i = NO_SELECTION


func _ready() -> void:
	DungeonManager.dungeon_generated.connect(_rebuild_layout)
	DungeonManager.room_placed.connect(_on_dungeon_changed)
	DungeonManager.room_removed.connect(_on_dungeon_changed)
	DungeonManager.room_upgraded.connect(_on_dungeon_changed)
	DungeonManager.boss_cell_changed.connect(_on_dungeon_changed)
	DungeonManager.boss_room_changed.connect(_on_dungeon_changed)

	_create_entrance_marker()
	_rebuild_layout()


func _on_dungeon_changed(_a: Variant = null, _b: Variant = null) -> void:
	_rebuild_layout()


## Consumes a matching card from the player's hand and places a room
## at `cell`. Used by RoomGapZone drops.
func request_insert(cell: Vector2i, room_data: RoomData) -> bool:

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return false

	if room_data == null:
		return false

	if not CardHandManager.remove_card(room_data):
		return false

	var placed: bool = DungeonManager.place_room(cell, room_data)

	if not placed:
		# Give the card back - the placement itself failed for some
		# other reason (shouldn't normally happen given can_place_at
		# was already checked by the drop zone, but this keeps a
		# failed placement from silently burning a paid-for card).
		CardHandManager.add_card(room_data)

	if placed:
		room_placed.emit(room_data)

	return placed


## Spends the cost difference and upgrades the room at `cell`.
func request_upgrade(cell: Vector2i) -> bool:

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return false

	var current: RoomData = DungeonManager.get_room(cell)

	if current == null or current.upgrade_path == null:
		return false

	var upgrade_cost: int = current.upgrade_path.cost - current.cost

	if upgrade_cost > 0:
		if not EconomyManager.can_afford(upgrade_cost):
			return false
		EconomyManager.spend_gold(upgrade_cost)

	return DungeonManager.upgrade_room(cell)


## Removes the room at `cell` and refunds half its cost.
func sell_room_at(cell: Vector2i) -> bool:

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return false

	var room_data: RoomData = DungeonManager.get_room(cell)

	if room_data == null:
		return false

	var refund: int = int(room_data.cost * 0.5)
	var removed: bool = DungeonManager.remove_room(cell)

	if removed:
		EconomyManager.add_gold(refund)

	return removed


## World position for the center of a grid cell.
func cell_to_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * room_size.x, cell.y * room_size.y)


## Called by a palette/build UI when a matching room card starts dragging.
func show_upgrade_prompts_for(dragged_room_data: RoomData) -> void:

	for cell: Vector2i in room_nodes:

		var current: RoomData = DungeonManager.get_room(cell)

		if current != null and current.upgrade_path == dragged_room_data:
			room_nodes[cell].show_upgrade_prompt(cell)


func hide_upgrade_prompts() -> void:

	for cell: Vector2i in room_nodes:
		room_nodes[cell].hide_upgrade_prompt()


func _create_entrance_marker() -> void:

	entrance_marker = Node2D.new()
	entrance_marker.name = "Entrance"
	add_child(entrance_marker)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = MARKER_COLOR
	backdrop.position = room_size * -0.5
	backdrop.size = room_size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entrance_marker.add_child(backdrop)

	var label: Label = Label.new()
	label.text = "Entrance"
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
	entrance_marker.add_child(label)


func _rebuild_layout() -> void:

	_clear_layout()

	entrance_marker.position = cell_to_position(DungeonManager.entrance_cell)

	for x: int in DungeonManager.grid_size.x:
		for y: int in DungeonManager.grid_size.y:

			var cell: Vector2i = Vector2i(x, y)

			if cell == DungeonManager.entrance_cell or cell == DungeonManager.boss_cell:
				continue

			var room_data: RoomData = DungeonManager.get_room(cell)

			if room_data != null:
				_spawn_room_node(cell, room_data)
			else:
				_spawn_cell_zone(cell)

	if DungeonManager.boss_cell != DungeonManager.UNPLACED_CELL and DungeonManager.boss_room != null:

		boss_room_node = room_scene.instantiate() as Room
		add_child(boss_room_node)
		boss_room_node.position = cell_to_position(DungeonManager.boss_cell)
		boss_room_node.set_room(DungeonManager.boss_room)
		# Deliberately NOT connected to room_clicked / sell_requested /
		# upgrade_zone - the boss room can't be selected, sold, or
		# upgraded through the normal room UI.
		_apply_doors(boss_room_node, DungeonManager.boss_cell)


func _spawn_room_node(cell: Vector2i, room_data: RoomData) -> void:

	var room: Room = room_scene.instantiate() as Room
	add_child(room)
	room.position = cell_to_position(cell)
	room.set_room(room_data)
	room.room_clicked.connect(_on_room_clicked.bind(cell))
	room.sell_requested.connect(_on_sell_requested.bind(cell))
	room.upgrade_zone.upgrade_requested.connect(_on_upgrade_requested)

	room_nodes[cell] = room
	_apply_doors(room, cell)


func _spawn_cell_zone(cell: Vector2i) -> void:

	var zone: RoomGapZone = RoomGapZone.new()
	zone.cell = cell
	zone.z_index = 1
	zone.size = room_size
	zone.position = cell_to_position(cell) - room_size * 0.5
	zone.drop_requested.connect(_on_cell_drop_requested)

	add_child(zone)
	cell_zones[cell] = zone


## Sets a room's 4 doorway markers based on DungeonManager's actual
## connection graph - NOT raw grid adjacency. Two grid-adjacent rooms
## don't necessarily have a door between them (see
## DungeonManager.has_connection / the MAX_ROOM_CONNECTIONS cap).
func _apply_doors(room: Room, cell: Vector2i) -> void:

	var open_edges: Dictionary = {
		"north": DungeonManager.has_connection(cell, cell + Vector2i(0, -1)),
		"east": DungeonManager.has_connection(cell, cell + Vector2i(1, 0)),
		"south": DungeonManager.has_connection(cell, cell + Vector2i(0, 1)),
		"west": DungeonManager.has_connection(cell, cell + Vector2i(-1, 0)),
	}

	room.set_open_doors(open_edges)


func _on_cell_drop_requested(cell: Vector2i, room_data: RoomData) -> void:
	if room_data == DungeonManager.boss_room:
		DungeonManager.set_boss_cell(cell)
	else:
		request_insert(cell, room_data)


func _on_upgrade_requested(cell: Vector2i) -> void:
	request_upgrade(cell)
	hide_upgrade_prompts()


func _on_room_clicked(room: Room, cell: Vector2i) -> void:

	if _selected_cell == cell:
		_deselect_room()
	else:
		_select_room(cell)

	room_selected.emit(cell, room)


func _select_room(cell: Vector2i) -> void:

	_deselect_room()

	_selected_cell = cell

	if room_nodes.has(cell):
		room_nodes[cell].show_sell_button()


func _deselect_room() -> void:

	if _selected_cell != NO_SELECTION and room_nodes.has(_selected_cell):
		room_nodes[_selected_cell].hide_sell_button()

	_selected_cell = NO_SELECTION


func _on_sell_requested(room: Room, cell: Vector2i) -> void:
	sell_room_at(cell)


func _clear_layout() -> void:

	for cell: Vector2i in room_nodes:
		var room: Room = room_nodes[cell]
		if is_instance_valid(room):
			room.queue_free()
	room_nodes.clear()

	if is_instance_valid(boss_room_node):
		boss_room_node.queue_free()
	boss_room_node = null

	for cell: Vector2i in cell_zones:
		var zone: RoomGapZone = cell_zones[cell]
		if is_instance_valid(zone):
			zone.queue_free()
	cell_zones.clear()

	_selected_cell = NO_SELECTION
