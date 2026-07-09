extends Button
class_name RoomUpgradeZone

## Floating prompt shown above a room while a matching RoomCard is being
## dragged. Dropping the card here (or clicking it directly) upgrades the
## room at `cell` - but only if the dragged card is the room's actual
## next upgrade tier, not just any card sharing the same name.

signal upgrade_requested(cell: Vector2i)

@export var cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	text = "Upgrade"
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	upgrade_requested.emit(cell)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is RoomData and _is_expected_upgrade(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is RoomData and _is_expected_upgrade(data):
		upgrade_requested.emit(cell)


func _is_expected_upgrade(data: RoomData) -> bool:
	var current: RoomData = DungeonManager.get_room(cell)
	return current != null and current.upgrade_path == data
