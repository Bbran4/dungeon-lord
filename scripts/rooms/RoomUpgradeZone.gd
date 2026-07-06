extends Button
class_name RoomUpgradeZone

## Floating prompt shown above a room while a matching RoomCard is being
## dragged. Dropping the card here (or clicking it directly) upgrades the
## room at `room_index` - but only if the dragged card is the room's
## actual next upgrade tier, not just any card sharing the same name.
## This matters once a room has more than one upgrade tier: dragging the
## base-tier card onto an already-upgraded room must not silently trigger
## a further upgrade it wasn't meant to cause.

signal upgrade_requested(room_index: int)

@export var room_index: int = -1


func _ready() -> void:
	text = "Upgrade"
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	upgrade_requested.emit(room_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is RoomData and _is_expected_upgrade(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is RoomData and _is_expected_upgrade(data):
		upgrade_requested.emit(room_index)


func _is_expected_upgrade(data: RoomData) -> bool:
	var current: RoomData = DungeonManager.get_room(room_index)
	return current != null and current.upgrade_path == data
