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
	GAME_OVER
}
