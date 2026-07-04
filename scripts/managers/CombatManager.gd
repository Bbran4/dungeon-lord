extends Node

signal combat_started(attacker: CombatEntity, defender: CombatEntity)
signal combat_finished(winner: CombatEntity, loser: CombatEntity)


func begin_combat(attacker: CombatEntity, defender: CombatEntity) -> void:

	combat_started.emit(attacker, defender)

	while attacker.current_health > 0 and defender.current_health > 0:

		attacker.attack(defender)

		if defender.current_health <= 0:
			break

		defender.attack(attacker)

	var winner: CombatEntity
	var loser: CombatEntity

	if attacker.current_health > 0:
		winner = attacker
		loser = defender
	else:
		winner = defender
		loser = attacker

	combat_finished.emit(winner, loser)
