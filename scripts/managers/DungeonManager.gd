extends Node

## Holds the dungeon as a sparse grid of rooms rather than a linear
## path. entrance_cell is a fixed anchor point - always "passable"
## (see is_passable), never buildable. Player-built rooms live in
## `grid`, keyed by cell.
##
## DOORS ARE DECIDED AT PLACEMENT TIME, NOT PURELY DERIVED FROM RAW
## ADJACENCY: a room's doorways are established once, in
## _connect_cell(), when it's placed. A NEW connection between two
## REGULAR rooms is skipped if they're already reachable from each
## other via some existing chain (see _same_component) - this is what
## stops a built path that curls back on itself (e.g. room D
## happening to become grid-adjacent to room A after a chain
## A-B-C-D) from silently opening an unintended extra door, WITHOUT
## capping how many doors a room can have overall. Genuine forking - a
## room branching toward two areas that aren't otherwise connected to
## each other - is unaffected, since neither side is reachable from
## the other yet.
##
## THE ENTRANCE AND BOSS ROOM ARE HUBS, exempt from that cycle check -
## connecting to (or from) either of them always succeeds regardless
## of existing components. This is deliberate: they're the two points
## multiple branches are explicitly allowed to reconverge at (a
## regular room reconverging two branches would fail the check above,
## since by definition both branches already reach each other through
## it - only the entrance/boss are meant to do that).
##
## `connections` (Vector2i -> Array[Vector2i]) is the actual,
## authoritative doorway graph - both door rendering and
## get_shortest_path() read this, never raw grid adjacency.
## `is_passable` is a separate, weaker check ("is this cell part of
## the dungeon at all"), used only to decide whether a NEW connection
## is even geometrically eligible to form.
##
## KNOWN LIMITATION: when a newly-placed cell has multiple eligible
## neighbors and more than one would trigger the cycle check, which
## one "wins" (gets skipped vs connected) depends on scan order
## (N/E/S/W) relative to the room's actual geometry, not on which
## neighbor the player intended to build from - there's currently no
## way to know that intent from the placement call alone. In practice
## the geometrically "obvious" attachment is almost always scanned
## first, but a rare layout could pick the coincidental neighbor
## instead of the intended one.
##
## THE BOSS ROOM IS MOBILE - unlike the entrance, boss_cell is not a
## fixed anchor. It starts UNPLACED (see UNPLACED_CELL) and the player
## places (and can later relocate) it anywhere in the network via
## set_boss_cell(), under the exact same connectivity rule as a normal
## room. It doesn't count against max_rooms and isn't stored in `grid`.
##
## - Selling a bridging room, or relocating the boss room away from a
##   branch that only existed to reach it, CAN disconnect the dungeon.
##   This is intentionally not specially guarded against here - it
##   just means get_shortest_path() returns [] until reconnected, the
##   same "can't send a wave" gate as never having built a path at all.
##
## max_rooms is a hard cap on player-built room COUNT, independent of
## grid_size - a 6x6 grid does not mean 36 buildable rooms.

@export var grid_size: Vector2i = Vector2i(6, 6)
@export var max_rooms: int = 6

## Never a valid in-bounds cell (grid coordinates are always >= 0), so
## it's a safe "not placed yet" sentinel for boss_cell.
const UNPLACED_CELL: Vector2i = Vector2i(-1, -1)

signal dungeon_generated
signal room_placed(cell: Vector2i, room_data: RoomData)
signal room_removed(cell: Vector2i)
signal room_upgraded(cell: Vector2i, room_data: RoomData)
signal boss_room_changed(room_data: RoomData)
signal boss_cell_changed(cell: Vector2i)

var grid: Dictionary = {} # Vector2i -> RoomData, player-built rooms only

## Vector2i -> Array[Vector2i]. The actual, authoritative doorway graph
## - symmetric (if A lists B, B lists A). This is what get_shortest_path()
## and door rendering both read; NOT is_passable/get_adjacent_cells.
var connections: Dictionary = {}

var entrance_cell: Vector2i
var boss_cell: Vector2i = UNPLACED_CELL

## The boss encounter authored for the active biome (see
## BiomeManager.get_current_boss_room / set_boss_room). Having this
## set does NOT mean the boss room is on the grid yet - it just means
## there's something for the player to place. Check boss_cell !=
## UNPLACED_CELL for whether it's actually been positioned.
var boss_room: RoomData = null


func _ready() -> void:
	entrance_cell = Vector2i(0, grid_size.y / 2)


func generate_dungeon() -> void:
	grid.clear()
	connections.clear()
	boss_cell = UNPLACED_CELL
	dungeon_generated.emit()


func set_boss_room(room_data: RoomData) -> void:
	boss_room = room_data
	boss_room_changed.emit(room_data)


## Places (or relocates) the boss room at `cell`. Same connectivity
## rule as a normal room. Safe to call again later to move the boss
## room elsewhere - the old cell's connections are torn down first,
## freeing capacity on whatever it used to be connected to.
func set_boss_cell(cell: Vector2i) -> bool:

	if not can_place_boss_at(cell):
		return false

	if boss_cell != UNPLACED_CELL:
		_disconnect_cell(boss_cell)

	boss_cell = cell
	_connect_cell(boss_cell)
	boss_cell_changed.emit(cell)

	return true


## Whether the boss room could be placed/relocated to `cell` - boss
## content must actually be assigned (see set_boss_room), the cell
## must be in bounds, empty of a player-built room, not already where
## the boss room is, and adjacent to something already connected.
func can_place_boss_at(cell: Vector2i) -> bool:

	if boss_room == null:
		return false

	if not is_in_bounds(cell):
		return false

	if grid.has(cell):
		return false

	if cell == boss_cell:
		return false

	for neighbor: Vector2i in get_adjacent_cells(cell):
		if is_passable(neighbor):
			return true

	return false


func room_count() -> int:
	return grid.size()


func get_room(cell: Vector2i) -> RoomData:
	return grid.get(cell, null)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y


## True for any cell a hero can actually stand in/walk through - the
## entrance, the boss room, or a player-built room. An empty grid cell
## is not part of the dungeon at all. NOTE: this does NOT mean two
## passable neighbors necessarily have a door between them - see
## has_connection() and the class doc.
func is_passable(cell: Vector2i) -> bool:
	return cell == entrance_cell or cell == boss_cell or grid.has(cell)


## The entrance and boss room are hubs - the two points branches are
## explicitly allowed to reconverge at. See class doc.
func _is_hub(cell: Vector2i) -> bool:
	return cell == entrance_cell or cell == boss_cell


## Whether `a` and `b` are already reachable from each other via the
## CURRENT connection graph (plain BFS - the grid is small enough that
## this is cheap even called repeatedly). Used to stop an accidental
## adjacency between two regular rooms that are already connected some
## other way from silently closing a loop.
func _same_component(a: Vector2i, b: Vector2i) -> bool:

	if a == b:
		return true

	var visited: Dictionary = {a: true}
	var frontier: Array[Vector2i] = [a]

	while not frontier.is_empty():

		var current: Vector2i = frontier.pop_front()

		if current == b:
			return true

		for neighbor: Vector2i in connections.get(current, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)

	return false


## Whether cell `a` has an actual established doorway to cell `b` -
## the authoritative check for door rendering AND pathfinding. Two
## grid-adjacent passable cells do NOT necessarily have a connection -
## see class doc.
func has_connection(a: Vector2i, b: Vector2i) -> bool:
	return connections.get(a, []).has(b)


## The (up to 4) orthogonal neighbors of `cell`, filtered to in-bounds
## cells only. Order is fixed (N, E, S, W) so connection assignment
## and pathfinding are both deterministic.
func get_adjacent_cells(cell: Vector2i) -> Array[Vector2i]:

	var candidates: Array[Vector2i] = [
		cell + Vector2i(0, -1),
		cell + Vector2i(1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(-1, 0),
	]

	var result: Array[Vector2i] = []

	for candidate: Vector2i in candidates:
		if is_in_bounds(candidate):
			result.append(candidate)

	return result


## Whether a NEW room could be placed at `cell` right now - in bounds,
## currently empty, not the reserved entrance/boss cells, under the
## room cap, and adjacent to something already connected.
func can_place_at(cell: Vector2i) -> bool:

	if not is_in_bounds(cell):
		return false

	if cell == entrance_cell or cell == boss_cell:
		return false

	if grid.has(cell):
		return false

	if grid.size() >= max_rooms:
		return false

	for neighbor: Vector2i in get_adjacent_cells(cell):
		if is_passable(neighbor):
			return true

	return false


func place_room(cell: Vector2i, room_data: RoomData) -> bool:

	if room_data == null or not can_place_at(cell):
		return false

	grid[cell] = room_data
	_connect_cell(cell)

	room_placed.emit(cell, room_data)

	return true


func remove_room(cell: Vector2i) -> bool:

	if not grid.has(cell):
		return false

	grid.erase(cell)
	_disconnect_cell(cell)

	room_removed.emit(cell)

	return true


func upgrade_room(cell: Vector2i) -> bool:

	var current: RoomData = grid.get(cell, null)

	if current == null or current.upgrade_path == null:
		return false

	grid[cell] = current.upgrade_path

	room_upgraded.emit(cell, grid[cell])

	return true


## Establishes doorways between a just-placed `cell` and every
## geometrically eligible neighbor - skipping a connection between two
## REGULAR rooms only if they're already reachable from each other via
## some other existing chain (see _same_component / class doc).
## Connections involving the entrance or boss room are never skipped
## this way. Scan order is fixed (N/E/S/W) - see the KNOWN LIMITATION
## note in the class doc for what that does and doesn't guarantee.
func _connect_cell(cell: Vector2i) -> void:

	connections[cell] = connections.get(cell, [])

	for neighbor: Vector2i in get_adjacent_cells(cell):

		if not is_passable(neighbor):
			continue

		var involves_hub: bool = _is_hub(cell) or _is_hub(neighbor)

		if not involves_hub and _same_component(cell, neighbor):
			continue

		_add_connection(cell, neighbor)


func _add_connection(a: Vector2i, b: Vector2i) -> void:

	var a_links: Array = connections.get(a, [])
	if not a_links.has(b):
		a_links.append(b)
	connections[a] = a_links

	var b_links: Array = connections.get(b, [])
	if not b_links.has(a):
		b_links.append(a)
	connections[b] = b_links


## Removes `cell` from the connection graph entirely - used when
## selling a room or relocating the boss room away from its old spot.
## Frees up capacity on every neighbor it was connected to.
func _disconnect_cell(cell: Vector2i) -> void:

	for neighbor: Vector2i in connections.get(cell, []):
		var neighbor_links: Array = connections.get(neighbor, [])
		neighbor_links.erase(cell)
		connections[neighbor] = neighbor_links

	connections.erase(cell)


## BFS shortest path (in cell steps) from entrance_cell to boss_cell,
## walking only through ESTABLISHED CONNECTIONS (see has_connection) -
## i.e. respecting the actual doorway graph, not raw grid adjacency.
## Returns an empty array if no path currently exists yet (nothing
## built, boss not placed, or a bridging room was sold). Deterministic:
## ties are broken by connection scan order, so an unchanged layout
## always produces the same path.
func get_shortest_path() -> Array[Vector2i]:

	if entrance_cell == boss_cell:
		return [entrance_cell]

	var frontier: Array[Vector2i] = [entrance_cell]
	var came_from: Dictionary = {entrance_cell: entrance_cell}

	while not frontier.is_empty():

		var current: Vector2i = frontier.pop_front()

		if current == boss_cell:
			return _reconstruct_path(came_from, boss_cell)

		for neighbor: Vector2i in connections.get(current, []):

			if came_from.has(neighbor):
				continue

			came_from[neighbor] = current
			frontier.append(neighbor)

	return []


func _reconstruct_path(came_from: Dictionary, end: Vector2i) -> Array[Vector2i]:

	var path: Array[Vector2i] = [end]
	var current: Vector2i = end

	while current != entrance_cell:
		current = came_from[current]
		path.append(current)

	path.reverse()

	return path


func has_connected_path() -> bool:
	return not get_shortest_path().is_empty()
