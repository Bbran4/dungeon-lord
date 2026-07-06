extends Control
class_name RoomGapZone

## Drop target sitting between two rooms (or before the entrance / after
## the last room). Highlights while a RoomCard is dragged over it and
## asks DungeonGrid to insert the dropped room there.

signal drop_requested(gap_index: int, room_data: RoomData)

@export var gap_index: int = -1

var _highlight: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_hide_highlight)

	_highlight = ColorRect.new()
	_highlight.color = Color(0.3, 1.0, 0.3, 0.35)
	_highlight.anchor_right = 1.0
	_highlight.anchor_bottom = 1.0
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.visible = false
	add_child(_highlight)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:

	var can_drop: bool = data is RoomData

	_highlight.visible = can_drop

	return can_drop


func _drop_data(_at_position: Vector2, data: Variant) -> void:

	_hide_highlight()

	if data is RoomData:
		drop_requested.emit(gap_index, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_highlight()


func _hide_highlight() -> void:
	if _highlight != null:
		_highlight.visible = false
