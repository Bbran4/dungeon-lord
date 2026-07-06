extends Control
class_name RoomGapZone

## Drop target sitting on the seam between two rooms (or before the
## entrance / after the last room) - the dungeon-building equivalent of
## the transition control a video editor shows between two clips. A
## subtle highlight strip with a centered "+" is always visible so the
## insert point is discoverable, and both brighten while a RoomCard is
## dragged over them.

signal drop_requested(gap_index: int, room_data: RoomData)

@export var gap_index: int = -1

const IDLE_COLOR: Color = Color(1, 1, 1, 0.06)
const HOVER_COLOR: Color = Color(0.35, 1.0, 0.45, 0.4)
const IDLE_PLUS_ALPHA: float = 0.55
const HOVER_PLUS_ALPHA: float = 1.0

var _highlight: ColorRect
var _plus_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)

	_highlight = ColorRect.new()
	_highlight.color = IDLE_COLOR
	_highlight.anchor_right = 1.0
	_highlight.anchor_bottom = 1.0
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight)

	_plus_label = Label.new()
	_plus_label.text = "+"
	_plus_label.add_theme_font_size_override("font_size", 36)
	_plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plus_label.anchor_left = 0.5
	_plus_label.anchor_right = 0.5
	_plus_label.anchor_top = 0.5
	_plus_label.anchor_bottom = 0.5
	_plus_label.offset_left = -18.0
	_plus_label.offset_right = 18.0
	_plus_label.offset_top = -18.0
	_plus_label.offset_bottom = 18.0
	_plus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plus_label.modulate.a = IDLE_PLUS_ALPHA
	add_child(_plus_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:

	var can_drop: bool = data is RoomData

	_set_hovered(can_drop)

	return can_drop


func _drop_data(_at_position: Vector2, data: Variant) -> void:

	_set_hovered(false)

	if data is RoomData:
		drop_requested.emit(gap_index, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_hovered(false)


func _on_mouse_exited() -> void:
	_set_hovered(false)


func _set_hovered(hovered: bool) -> void:

	if _highlight == null:
		return

	_highlight.color = HOVER_COLOR if hovered else IDLE_COLOR
	_plus_label.modulate.a = HOVER_PLUS_ALPHA if hovered else IDLE_PLUS_ALPHA
