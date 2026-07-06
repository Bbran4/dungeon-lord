extends Node2D
class_name CircleVisual

## Minimal circle-drawing placeholder visual. Exposes `color` as a real
## property (not just a paint call) specifically so CombatEntity's
## existing taunt-red / heal-flash code (`_visual.color = ...`) keeps
## working unchanged regardless of whether the visual is this circle,
## the old ColorRect, or eventually a real sprite - swapping in actual
## art later just means replacing this node, not touching CombatEntity.

@export var radius: float = 16.0

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
