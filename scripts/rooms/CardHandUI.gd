extends Control
class_name CardHandUI

## Renders CardHandManager.hand as a fanned hand of RoomCard views,
## adapted from the fan-layout/hover-lift pattern in the dice-combat
## prototype's CombatUI._do_refresh_hand. Positioning is manual (this
## is a plain Control, not a layout container) because a fanned hand
## needs individually rotated/offset cards, which no built-in Container
## arranges on its own.
##
## Cards are rebuilt from scratch every time CardHandManager.hand
## changes (add or remove) - simpler than diffing, and the hand is
## small enough (single digits) that this is cheap. A card is only
## ever removed from the hand AFTER a drop already succeeded (see
## DungeonGrid.request_insert -> CardHandManager.remove_card), so a
## rebuild never interrupts a drag in progress.

signal card_drag_started(room_data: RoomData)
signal card_drag_ended

@export var card_view_scene: PackedScene

const FAN_ARC_MAX: float = 20.0
const CARD_SPREAD: float = 95.0
const FAN_SINK: float = 1.5
const HOVER_LIFT: float = 120.0
const HAND_BOTTOM_CROP: float = 40.0
const CARD_WIDTH: float = 160.0
const CARD_HEIGHT: float = 240.0

var _cards: Array[RoomCard] = []
var _enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	CardHandManager.hand_changed.connect(_on_hand_changed)
	_rebuild()


## Called by TestHarness on every phase change - toggles every current
## hand card's interactivity without needing to know about individual
## cards itself.
func set_enabled(value: bool) -> void:

	_enabled = value

	for card: RoomCard in _cards:
		if is_instance_valid(card):
			card.disabled = not _enabled
			card.mouse_filter = Control.MOUSE_FILTER_STOP if _enabled else Control.MOUSE_FILTER_IGNORE


func all_cards() -> Array[RoomCard]:
	return _cards


func _on_hand_changed() -> void:
	_rebuild()


func _rebuild() -> void:

	for card: RoomCard in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()

	var hand: Array[RoomData] = CardHandManager.hand
	var n: int = hand.size()

	if n == 0 or card_view_scene == null:
		return

	var container_width: float = size.x

	if container_width <= 0.0:
		call_deferred("_rebuild")
		return

	var arc: float = minf(FAN_ARC_MAX, n * 9.0)
	var angle_step: float = arc / maxf(n - 1, 1)
	var start_angle: float = -arc / 2.0

	var center_x: float = container_width * 0.5
	var bottom_y: float = size.y - HAND_BOTTOM_CROP

	for i: int in n:

		var room_data: RoomData = hand[i]

		var card: RoomCard = card_view_scene.instantiate()
		add_child(card)
		card.set_room_data(room_data)
		card.disabled = not _enabled
		card.mouse_filter = Control.MOUSE_FILTER_STOP if _enabled else Control.MOUSE_FILTER_IGNORE

		var angle_deg: float = start_angle + angle_step * i
		var offset_x: float = (i - (n - 1) / 2.0) * CARD_SPREAD
		var rest_x: float = center_x + offset_x - CARD_WIDTH / 2.0
		var rest_y: float = bottom_y + absf(angle_deg) * FAN_SINK - CARD_HEIGHT

		card.position = Vector2(rest_x, rest_y)
		card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT * 1.4)
		card.rotation_degrees = angle_deg
		card.scale = Vector2.ONE
		card.z_index = i

		var rest_position: Vector2 = card.position
		var rest_angle: float = angle_deg
		var rest_z: int = i

		card.mouse_entered.connect(func() -> void:
			_hover_lift(card, rest_position, rest_angle)
		)
		card.mouse_exited.connect(func() -> void:
			_hover_unlift(card, rest_position, rest_angle, rest_z)
		)
		card.drag_started.connect(func(dragged_room_data: RoomData) -> void:
			card_drag_started.emit(dragged_room_data)
		)
		card.drag_ended.connect(func() -> void:
			card_drag_ended.emit()
		)

		_cards.append(card)


func _hover_lift(card: RoomCard, rest_position: Vector2, rest_angle: float) -> void:

	if card.hover_tween != null:
		card.hover_tween.kill()

	card.z_index = 200

	card.hover_tween = card.create_tween()
	card.hover_tween.set_parallel(true)
	card.hover_tween.tween_property(card, "position:y", rest_position.y - HOVER_LIFT, 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	card.hover_tween.tween_property(card, "rotation_degrees", rest_angle * 0.12, 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	card.hover_tween.tween_property(card, "scale", Vector2(1.18, 1.18), 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _hover_unlift(card: RoomCard, rest_position: Vector2, rest_angle: float, rest_z: int) -> void:

	if card.hover_tween != null:
		card.hover_tween.kill()

	card.z_index = rest_z

	card.hover_tween = card.create_tween()
	card.hover_tween.set_parallel(true)
	card.hover_tween.tween_property(card, "position", rest_position, 0.10).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	card.hover_tween.tween_property(card, "rotation_degrees", rest_angle, 0.10).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	card.hover_tween.tween_property(card, "scale", Vector2.ONE, 0.10).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
