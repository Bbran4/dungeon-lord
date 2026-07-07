extends RefCounted
class_name GameEnums

enum RoomState {
	EMPTY,
	OCCUPIED,
	CLEARED
}

enum RoomType {
	EMPTY,
	MONSTER,
	TRAP,
	BOSS
}

enum HeroState {
	IDLE,
	MOVING,
	FIGHTING,
	DEAD
}

enum MonsterState {
	IDLE,
	FIGHTING,
	DEAD
}

enum GameState {
	MENU,
	BUILDING,
	COMBAT,
	REWARD,
	GAME_OVER,
	VICTORY
}

enum AbilityType {
	ATTACK,
	HEAL,
	CHAIN_HEAL,
	BUFF,
	TAUNT,
	DOT_ATTACK,
	CHAIN_ATTACK
}

enum AbilityTargetRule {
	LOWEST_HP_ALLY,
	SELF
}

enum TrapType {
	INSTANT,
	PROJECTILE
}

enum PassiveEffectType {
	GOLD_MULTIPLIER,
	TRAP_DAMAGE_MULTIPLIER,
	MONSTER_DAMAGE_MULTIPLIER,
	MONSTER_HEALTH_MULTIPLIER,
	REROLL_DISCOUNT
}
