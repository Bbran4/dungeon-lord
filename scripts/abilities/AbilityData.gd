extends Resource
class_name AbilityData

@export var ability_name : String

@export var ability_type : GameEnums.AbilityType = GameEnums.AbilityType.ATTACK

## Only relevant for Heal/ChainHeal/Buff/Taunt - Attack-type abilities
## always target using CombatManager's built-in enemy-targeting rules
## (random for heroes, highest-threat-with-taunt-override for monsters).
@export var target_rule : GameEnums.AbilityTargetRule = GameEnums.AbilityTargetRule.SELF

@export var cooldown : float = 4.0

## Damage/heal amount (Attack/Heal/ChainHeal), or armor bonus (Buff).
## Unused by Taunt.
@export var magnitude : int = 0

## How long the effect lasts - armor bonus duration (Buff), or forced-
## target window (Taunt). Unused by Heal/ChainHeal/Attack, which are
## instant.
@export var duration : float = 0.0

## ChainHeal only: how many ADDITIONAL lowest-HP allies (beyond the
## primary target) also get healed, at reduced effectiveness.
@export var chain_count : int = 0

@export var icon : Texture2D
