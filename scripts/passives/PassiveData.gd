extends Resource
class_name PassiveData

@export var passive_name : String
@export var description : String
@export var cost : int = 30

@export var effect_type : GameEnums.PassiveEffectType = GameEnums.PassiveEffectType.GOLD_MULTIPLIER

## Interpretation depends on effect_type:
## GOLD_MULTIPLIER / TRAP_DAMAGE_MULTIPLIER / MONSTER_DAMAGE_MULTIPLIER /
## MONSTER_HEALTH_MULTIPLIER: added to 1.0 as a percentage (0.15 = +15%).
## REROLL_DISCOUNT: a flat gold amount subtracted from the shop's reroll cost.
@export var magnitude : float = 0.15

@export var icon : Texture2D
