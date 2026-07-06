extends Resource
class_name AbilityData

@export var ability_name : String

@export var ability_type : GameEnums.AbilityType = GameEnums.AbilityType.ATTACK

## Only relevant for Heal/ChainHeal/Buff/Taunt - Attack-type abilities
## always target using CombatManager's built-in enemy-targeting rules
## (random for heroes, highest-threat-with-taunt-override for monsters).
@export var target_rule : GameEnums.AbilityTargetRule = GameEnums.AbilityTargetRule.SELF

@export var cooldown : float = 4.0

## Damage/heal amount (Attack/DotAttack/ChainAttack/Heal/ChainHeal), or
## armor bonus (Buff). Unused by Taunt.
@export var magnitude : int = 0

## How long the effect lasts - armor bonus duration (Buff), or forced-
## target window (Taunt). Unused by everything else.
@export var duration : float = 0.0

## Extra targets beyond the primary: additional lowest-HP allies healed
## (ChainHeal) or additional random enemies hit (ChainAttack).
@export var chain_count : int = 0

## Attack/DotAttack/ChainAttack only - whether this ability's damage
## bypasses armor entirely (e.g. poison, explosive, backstab).
@export var ignore_armor : bool = false

## DotAttack only - damage-over-time applied after the initial hit.
@export var tick_damage : int = 0
@export var tick_count : int = 0
@export var tick_interval : float = 1.0

@export var icon : Texture2D
