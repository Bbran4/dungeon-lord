extends Button
class_name RoomUpgradeZone

## Floating prompt shown above a room while a matching RoomCard is being
## dragged. Dropping the card here (or clicking it directly) upgrades the
## room at `room_index`.

signal upgrade_requested(room_index: int)

@export var room_index: int = -1
@export var expected_room_name: String = ""


func _ready() -> void:
	text = "Upgrade"
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	upgrade_requested.emit(room_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is RoomData and data.room_name == expected_room_name


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is RoomData and data.room_name == expected_room_name:
		upgrade_requested.emit(room_index)
