extends Button
class_name RoomCard

## A build-palette entry that can be dragged onto a RoomGapZone (to insert)
## or a RoomUpgradeZone (to upgrade a matching room).

signal drag_started(room_data: RoomData)
signal drag_ended

@export var room_data: RoomData


func set_room_data(data: RoomData) -> void:
	room_data = data
	text = "%s\n%dg" % [data.room_name, data.cost] if data != null else ""


func _get_drag_data(_at_position: Vector2) -> Variant:

	if room_data == null:
		return null

	var preview: Label = Label.new()
	preview.text = room_data.room_name
	set_drag_preview(preview)

	drag_started.emit(room_data)

	return room_data


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_ended.emit()
