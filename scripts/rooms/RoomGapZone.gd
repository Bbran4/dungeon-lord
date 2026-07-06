extends Control
class_name RoomGapZone

signal drop_requested(gap_index: int, room_data: RoomData)

@export var gap_index: int = -1

const IDLE_COLOR: Color = Color(1, 1, 1, 0.06)
const HOVER_COLOR: Color = Color(0.35, 1.0, 0.45, 0.4)
const IDLE_PLUS_ALPHA: float = 0.55
const HOVER_PLUS_ALPHA: float = 1.0

var _highlight: ColorRect
var _plus_label: Label

## When true, this gap zone is at the dungeon's room cap - it never
## shows itself during a drag and never accepts a drop, regardless of
## what's being dragged. Set by DungeonGrid whenever the room count
## changes (see DungeonGrid._update_gap_zone_lock_state).
var locked: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	visible = false  # hidden until a RoomCard drag starts

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


## Called by DungeonGrid whenever the room count crosses the cap in
## either direction. Locking forcibly hides the zone even mid-drag.
func set_locked(value: bool) -> void:
	locked = value
	if locked:
		visible = false
		_set_hovered(false)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if locked:
		return false
	var can_drop: bool = data is RoomData
	_set_hovered(can_drop)
	return can_drop


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if locked:
		return
	_set_hovered(false)
	if data is RoomData:
		drop_requested.emit(gap_index, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		if locked:
			return
		visible = get_viewport().gui_get_drag_data() is RoomData
	elif what == NOTIFICATION_DRAG_END:
		visible = false
		_set_hovered(false)


func _on_mouse_exited() -> void:
	_set_hovered(false)


func _set_hovered(hovered: bool) -> void:
	if _highlight == null:
		return
	_highlight.color = HOVER_COLOR if hovered else IDLE_COLOR
	_plus_label.modulate.a = HOVER_PLUS_ALPHA if hovered else IDLE_PLUS_ALPHA
