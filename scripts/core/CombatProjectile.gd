extends Node2D
class_name CombatProjectile

## A generic tinted-circle visual that travels from one point to
## another and frees itself. Purely cosmetic - spawned AFTER damage has
## already been applied (same simplification the melee lunge already
## makes), not before, to avoid restructuring CombatManager's
## synchronous ability execution into something awaited per-hit.

const TRAVEL_DURATION: float = 0.18

@onready var _visual: CircleVisual = $Visual as CircleVisual


func launch(from: Vector2, to: Vector2, color: Color) -> void:

	global_position = from

	if _visual != null:
		_visual.color = color

	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", to, TRAVEL_DURATION)
	tween.finished.connect(queue_free)
