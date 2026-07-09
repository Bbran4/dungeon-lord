extends Control
class_name RoomGapZone

## Represents one EMPTY grid cell as a card-drop target. Visible only
## while a RoomCard is being dragged, and only accepts a drop if the
## dragged RoomData could actually go here right now - checked fresh
## at drag-start and at drop, rather than cached, so the valid-cell
## set stays correct as the player builds mid-drag-sequence.
##
## BOSS ROOM AWARE: the boss room is presented to the player as an
## always-available RoomCard too (see TestHarness - it's never
## consumed/removed, just re-drag it to relocate). It's identified by
## REFERENCE - if the dragged RoomData IS DungeonManager.boss_room,
## this routes through can_place_boss_at()/DungeonManager.set_boss_cell()
## instead of the normal can_place_at()/place_room() path. Everything
## else about the drag interaction (highlighting, drop handling) is
## identical either way.

signal drop_requested(cell: Vector2i, room_data: RoomData)

@export var cell: Vector2i = Vector2i(-1, -1)

const IDLE_COLOR: Color = Color(1, 1, 1, 0.06)
const HOVER_COLOR: Color = Color(0.35, 1.0, 0.45, 0.4)
const IDLE_PLUS_ALPHA: float = 0.55
const HOVER_PLUS_ALPHA: float = 1.0

var _highlight: ColorRect
var _plus_label: Label


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


## True if `data` could actually be dropped on this cell right now -
## the boss room via can_place_boss_at, any other RoomData via the
## normal can_place_at.
func _accepts(data: Variant) -> bool:

	if not (data is RoomData):
		return false

	if data == DungeonManager.boss_room:
		return DungeonManager.can_place_boss_at(cell)

	return DungeonManager.can_place_at(cell)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var can_drop: bool = _accepts(data)
	_set_hovered(can_drop)
	return can_drop


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hovered(false)
	if _accepts(data):
		drop_requested.emit(cell, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		visible = _accepts(get_viewport().gui_get_drag_data())
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
