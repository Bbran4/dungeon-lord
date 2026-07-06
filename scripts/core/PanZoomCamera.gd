extends Camera2D
class_name PanZoomCamera

## Mouse-wheel zoom and middle-mouse-drag (or WASD/arrow key) pan for
## viewing the dungeon. Godot's Camera2D.zoom is a view-size multiplier,
## so a bigger value shows more of the world (zoomed out) and a smaller
## value shows less (zoomed in).

@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.4
@export var max_zoom: float = 4.0
@export var pan_speed: float = 900.0

var _dragging: bool = false


func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventMouseButton:

		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-zoom_step)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(zoom_step)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed

	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative * zoom.x


func _process(delta: float) -> void:

	var move: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0

	if move != Vector2.ZERO:
		position += move.normalized() * pan_speed * zoom.x * delta


func _zoom_by(delta_amount: float) -> void:

	var new_zoom: float = clampf(zoom.x + delta_amount, min_zoom, max_zoom)

	zoom = Vector2(new_zoom, new_zoom)
