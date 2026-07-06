# 🏰 DUNGEON LORD

A 2D dungeon-building roguelite with incremental progression, built in Godot.

Design deadly dungeons, draft powerful upgrades, and defend your Dungeon Lord against relentless parties of heroes attempting to clear your lair.

---

## 🎯 CORE VISION

Dungeon Lord is about building an evolving machine of death.

The player should always have interesting choices between waves.

The fun comes from discovering synergies between rooms, monsters, traps, cards, and bosses.

Combat is automatic.
Strategy is everything.

Every run should feel different.
Every upgrade should feel impactful.
Every biome should introduce new mechanics.

## 👑 CORE CONCEPT

You are not the hero.

You are the Dungeon Lord.

Heroes invade your dungeon in organized expeditions, battling through your monsters and traps in an attempt to defeat your boss.

Your goal is simple:

* Build your dungeon
* Defeat every hero party
* Strengthen your dungeon
* Conquer new regions

Every run is about creating increasingly powerful synergies between rooms, monsters, traps, cards, and bosses.

---

## 🎮 GAME STRUCTURE

### 🏰 Dungeon Building

* Build rooms using gold
* Upgrade existing rooms
* Expand your dungeon during a run
* Create powerful room combinations

### ⚔️ Hero Raids

* Heroes spawn in organized parties
* Each hero has a unique class and abilities
* Hero parties fight through your dungeon automatically
* If they reach the boss room, a final battle begins

### 🃏 Card Drafting

After every successful wave choose one upgrade card.

Cards modify:

* Traps
* Monsters
* Bosses
* Economy
* Hero debuffs
* Dungeon-wide effects

Every run becomes a unique build.

### 🌍 Biome Progression

Complete all waves in a biome to unlock the next region.

Example biomes:

* Mountain Caves
* Dwarven Mines
* Haunted Crypts
* Jungle Temple
* Infernal Fortress

Each biome introduces:

* New rooms
* New monsters
* New heroes
* New boss
* Unique mechanics

---

## 💰 CORE ECONOMY

### Gold

Primary resource used during runs.

Spend gold to:

* Build rooms
* Upgrade rooms
* Expand dungeon
* Purchase card packs
* Improve your boss

> **Status:** implemented. Gold is earned per-hero based on how much
> damage they took relative to their effective max health (base max
> health plus any healing received), not from winning fights or clearing
> rooms — killing monsters or reaching the exit alive earns nothing on
> its own. A full party wipe (zero heroes escape) pays an additional
> bonus scaled off the party's combined value. See `EconomyManager.gd`.

### Dark Essence

Permanent progression currency earned after each run.

Used to unlock:

* New rooms
* New monsters
* New cards
* New bosses
* New biomes
* Starting bonuses

---

## 🧠 CORE GAMEPLAY LOOP

```
Start Run

↓

Receive Starting Gold

↓

Build Dungeon

↓

Hero Party Enters

↓

Heroes Fight Through Dungeon

↓

Victory

↓

Earn Gold

↓

Choose Card

↓

Upgrade Dungeon

↓

Next Wave

↓

Biome Boss

↓

Next Biome

↓

Run Ends

↓

Spend Dark Essence

↓

Start New Run
```

---

## 🧱 CORE SYSTEMS

### Dungeon Rooms

Rooms contain either:

* Monsters
* Traps
* Utility effects
* Buffs
* Boss encounters

Rooms work together to create powerful synergies.

Examples:

* Skeleton Barracks
* Spider Nest
* Poison Chamber
* Spike Corridor
* Arrow Gallery
* Treasure Vault
* Boss Chamber

---

### Monsters

Each monster belongs to a room.

Examples:

* Skeletons
* Goblins
* Slimes
* Orcs
* Ghosts
* Spiders

Monsters have:

* Health
* Damage
* Armor
* Attack Speed
* Special Abilities

---

### Traps

Examples:

* Spikes
* Poison Gas
* Arrow Turrets
* Fire Jets
* Ice Traps
* Boulder Traps

Traps become stronger through upgrades and card synergies.

> **Status:** implemented. `TrapData` is a real resource
> (`trap_name`, `damage`, `trigger_chance`, `ignores_armor`, `abilities`).
> `Dungeon.gd` resolves a room's trap as a single probabilistic damage
> instance — no counter-attack, no spawned entity, no `CombatManager`
> involvement — fundamentally distinct from a monster fight, which
> always happens and always trades blows. A room can have a trap, a
> monster, or both. See `resources/traps/spike_trap.tres` and
> `resources/rooms/spike_corridor.tres` for a working example.

---

### Hero Parties

Heroes invade in groups rather than individually.

Typical party:

* Tank
* Healer
* Ranger
* Mage

Each class requires different strategies to defeat.

Elite raids may contain:

* Champions
* Paladins
* Assassins
* Clerics
* Legendary Heroes

> **Status:** implemented as a real group. Parties of 3-4 (Tank, Healer,
> a random Mage/Ranger DPS, plus a random 4th class) move and fight
> together via `Dungeon.gd`, positioned in a class-based formation and
> resolved as one shared encounter per room via
> `CombatManager.begin_group_combat()` rather than each hero soloing the
> dungeon independently. The Tank draws aggro via `Taunt` and
> self-buffs armor; the Healer keeps the party topped up. Ranger, Mage,
> and Rogue don't have kits yet — see Combat System.

---

### Bosses

Each dungeon ends with a boss encounter.

Bosses can gain upgrades throughout the run.

Possible upgrades:

* More Health
* More Damage
* New Abilities
* Additional Phases
* Summons
* Enrage Mechanics

Every biome features a unique boss.

Examples:

* Cave Troll
* Ancient Dragon
* Lich King
* Hydra
* Demon Lord

> **Status:** `BossData` exists as a data resource, but there is no boss
> room encounter logic, phase handling, or summon spawning yet.

---

## 🧠 DATA-DRIVEN ARCHITECTURE

**Resources = Data**

**Scenes = Visual Representation**

**Scripts = Behavior**

Everything should be data-driven using Godot Resources.

> **Status:** implemented. The `Resource` classes below all drive
> gameplay, and content is now authored as real `.tres` files under
> `resources/` — a 3-tier room upgrade chain, a trap room, and a full
> hero roster (Tank/Healer/Ranger/Mage/Rogue) — rather than constructed
> in code. `TestHarness.gd` just wires those files in via `@export`
> fields — adding a new monster, room, trap, or hero variant no longer
> requires touching any script.

---

## 📂 PROJECT STRUCTURE

Reflects the structure as it exists today (not the original target layout):

```
res://

scripts/
	core/          # GameEnums, CombatEntity, PanZoomCamera
	dungeon/       # Dungeon, DungeonGrid
	rooms/         # Room, RoomData, RoomCard, RoomGapZone, RoomUpgradeZone
	heroes/        # HeroData
	monsters/      # MonsterData
	traps/         # TrapData
	abilities/     # AbilityData
	bosses/        # BossData
	biomes/        # BiomeData
	cards/         # CardData
	managers/      # GameManager, EconomyManager, WaveManager,
	               # DungeonManager, CombatManager, HeroManager
	test/          # TestHarness (manual playtest scene driver)

resources/
	rooms/         # skeleton_den (3 tiers), spike_corridor.tres
	monsters/      # skeleton, elite_skeleton, skeleton_champion
	traps/         # spike_trap.tres
	abilities/     # tank_shield_wall, tank_taunt, cleric_heal, cleric_chain_heal
	heroes/        # test_adventurer, tank_knight, cleric_healer,
	               # ranger_scout, battle_mage, shadow_rogue

scenes/
	dungeons/      # Dungeon.tscn, DungeonGrid.tscn
	rooms/         # Room.tscn
	test/          # TestHarness.tscn, TestHeroEntity.tscn, TestMonsterEntity.tscn
```

`resources/` is now real, authored content covering a 3-tier room
upgrade chain, a trap room, and a full hero roster (Tank/Healer/
Ranger/Mage/Rogue). A dedicated `combat/` script folder from the
original plan doesn't exist yet — combat logic still lives in
`managers/CombatManager.gd` and `core/CombatEntity.gd`.

---

## 🧩 CORE DATA OBJECTS

All of the following are implemented as `Resource` subclasses.

### RoomData

```
room_name : String
cost : int
room_type : String ("Empty" | "Monster" | "Trap" | "Boss")
monster : MonsterData
trap : TrapData
health : int
upgrade_path : RoomData
icon : Texture2D
rarity : String ("Common" | "Rare" | "Epic" | "Legendary")
```

---

### TrapData

```
trap_name : String
damage : int
trigger_chance : float     # 0.0-1.0 chance the trap fires when entered
ignores_armor : bool       # traps classically bypass armor entirely
abilities : Array[String]
icon : Texture2D
```

---

### AbilityData

```
ability_name : String
ability_type : String ("Attack" | "Heal" | "ChainHeal" | "Buff" | "Taunt")
target_rule : String ("LowestHpAlly" | "Self")   # only used by Heal/ChainHeal/Buff/Taunt
cooldown : float
magnitude : int        # damage/heal amount, or armor bonus for Buff
duration : float        # buff/taunt duration; unused by instant effects
chain_count : int       # ChainHeal only - extra lowest-HP allies healed
icon : Texture2D
```

---

### MonsterData

```
monster_name : String
max_health : int
damage : int
armor : int
attack_speed : float
abilities : Array[AbilityData]
sprite : Texture2D
```

---

### HeroData

```
hero_name : String
max_health : int
damage : int
armor : int
attack_speed : float
abilities : Array[AbilityData]
class_type : String ("Tank" | "Healer" | "Mage" | "Ranger" | "Rogue")
priority : int
sprite : Texture2D
gold_value : int           # gold earned if 100% of effective max HP is dealt to this hero
```

---

### BossData

```
boss_name : String
max_health : int
damage : int
armor : int
phases : int
summons : Array[MonsterData]
abilities : Array[String]
sprite : Texture2D
```

---

### CardData

```
title : String
description : String
rarity : String ("Common" | "Rare" | "Epic" | "Legendary")
icon : Texture2D
effects : Array[String]
```

---

### BiomeData

```
biome_name : String
background : Texture2D
music : AudioStream
room_pool : Array[RoomData]
hero_pool : Array[HeroData]
boss : BossData
wave_count : int
special_rules : Array[String]
```

---

## ⚔️ COMBAT SYSTEM

Combat is fully automated: `CombatManager.begin_group_combat()` runs a
tick-based simulation where every hero and monster in a room fight
together as groups, not 1v1. Each combatant acts independently whenever
their own ability cooldowns allow it - `attack_speed` now genuinely
matters, since it sets the cooldown of the implicit basic attack.

Each combatant has an `abilities` list (`AbilityData` resources) on top
of an auto-generated basic attack. When multiple abilities are off
cooldown at once, one is chosen **at random** among the ready ones - no
priority order, no role logic.

**Aggro:** monsters target using a per-monster threat table (whoever has
dealt that monster the most cumulative damage). **Taunt is a hard
override** on top of that - while active, every monster's targeting is
forced onto the taunting hero(es), completely ignoring threat, for the
ability's duration.

**Formation:** party members are positioned by `class_type` rather than
spawn order - Tank at the front, Ranger/Mage in the middle, Healer at
the back, Rogue past the monster line entirely. This is currently
positional only, layered on top of the aggro system above.

**Visual feedback:** attacks lunge the attacker toward their target and
back; overlapping combatants gently push apart (`SeparationArea`); a
taunting entity turns blood red for the taunt's duration; a healed
entity flashes green for 0.5s.

The player's decisions happen between battles through:

* Room placement
* Upgrades
* Cards
* Economy management

The focus is strategy rather than micro-management.

> **Implemented kits:** Tank (`Shield Wall` self-buff armor, `Taunt`
> hard-override aggro) and Healer (`Heal` lowest-HP ally, `Chain Heal`
> splashing to 2 additional allies at reduced effectiveness). Mage,
> Ranger, and Rogue currently have no special abilities and only use
> their basic attack - their class-specific kits (fireball/chain
> lightning/ice spike, arrow types, poison/backstab) are the next step.
>
> **Known simplification:** hero-side Attack-type targeting (both the
> basic attack and any future Attack-type hero ability) is a random
> living monster - there's no hero-side targeting AI yet (e.g. a Rogue
> preferring an untaunted target for a backstab-style bonus).

---

## 🧭 CURRENT IMPLEMENTATION STATUS

What's actually playable today, via `scenes/test/TestHarness.tscn`:

* ✅ Linear dungeon path (entrance → rooms → exit) rendered by `DungeonGrid`
* ✅ Drag a `RoomCard` from the palette into a `RoomGapZone` to build a room (spends gold)
* ✅ Drag a matching card onto a room's upgrade prompt to upgrade it (spends the cost delta); upgrade chains of 3+ tiers work correctly, matched by exact resource rather than by room name
* ✅ Click a room to select it and reveal a Sell button (refunds half cost)
* ✅ Rooms visually display their occupying monster's name, not just the room name
* ✅ Trap rooms resolve as a single probabilistic damage instance, distinct from monster combat (no counter-attack, no `CombatManager`)
* ✅ Multi-hero parties (Tank/Healer/Ranger/Mage, plus a random 4th class) move and fight together as a real group via `Dungeon.send_wave()` + `CombatManager.begin_group_combat()` — not solo runs anymore
* ✅ Class-based formation (Tank front, Ranger/Mage mid, Healer back, Rogue flanking past the monster line)
* ✅ Monsters spawn visibly in their room up front (not lazily on arrival) and stay put until fought or the wave ends
* ✅ Aggro via a per-monster threat table (highest cumulative damage dealt); Tank `Taunt` is a hard override that forces monster targeting onto the taunting hero for its duration
* ✅ Ability/cooldown system (`AbilityData`): every combatant has an implicit basic attack (now genuinely paced by `attack_speed`) plus authored special abilities, chosen randomly among whichever are off cooldown. Tank kit (Shield Wall self-buff, Taunt) and Healer kit (Heal, Chain Heal) are implemented; Mage/Ranger/Rogue have no special abilities yet
* ✅ Visual combat feedback: attack lunge toward target and back, overlap-based separation push between combatants, taunting entities turn red, healed entities flash green
* ✅ Gold economy, wave counter, and a scrolling event log
* ✅ Pan (WASD/arrows or middle-mouse drag) and zoom (mouse wheel) camera
* ✅ `GameManager` gates building actions by phase (insert/upgrade/sell only succeed during BUILDING, enforced in `DungeonGrid`); "Send Wave" transitions to COMBAT, `Dungeon.wave_cleared` transitions to REWARD, which currently loops straight back to BUILDING (no card draft yet)
* ✅ `HeroManager.spawn_hero`/`remove_hero`/`active_heroes` backs `Dungeon.gd`'s hero tracking directly — no more private hero counter
* ✅ Room/monster/trap/ability/hero content authored as real `.tres` resources under `resources/`, wired into `TestHarness` via `@export` fields
* ✅ Gold is earned per-hero based on damage taken vs. effective max health, plus a full-wipe bonus — not from winning fights or clearing rooms (see `EconomyManager.gd`)

Notably **not yet wired up**, despite the underlying scripts existing:

* ⬜ No reward-phase content yet — `_on_reward_phase_started` immediately loops back to building since there's no card draft system
* ⬜ Utility rooms (buff/support rooms with no combat role) don't exist yet — deferred by design until after cards
* ⬜ Mage, Ranger, and Rogue have no special abilities yet (fireball/chain lightning/ice spike, arrow types, poison/backstab) — they currently only use their basic attack
* ⬜ `BossData` has no room encounter, phase, or summon logic

> **Architecture note:** the original plan called this a "Dungeon Grid,"
> but what's implemented is a **linear ordered path** (`DungeonManager`
> stores a flat, always-contiguous `Array[RoomData]`), not a 2D grid.
> This has been a deliberate simplification so far — worth flagging in
> case a true grid layout is still the long-term intent.

---

## 🎲 DESIGN PRINCIPLES

* Easy to understand
* Difficult to master
* High replayability
* Strong build variety
* Meaningful progression
* Small decisions every wave
* Powerful synergies over raw stat increases

Players should constantly think:

> "One more upgrade will make this build incredible."

---

# 🔥 DEVELOPMENT PRIORITY

1. ✅ Dungeon Grid *(implemented as a linear path)*
2. ✅ Placeable Rooms
3. ✅ Hero Movement
4. ✅ Basic Combat
5. ✅ Gold Economy
6. ✅ Room Upgrades
7. 🟡 Wave System *(counter exists; no auto-advance, scaling, or party spawning yet)*
8. ⬜ Card Drafting
9. 🟡 Hero Parties *(parties move and fight together with class formation, aggro/taunt, and Tank/Healer kits; Mage/Ranger/Rogue still only basic-attack — see Milestone 4)*
10. ⬜ Boss Room
11. ⬜ Biomes
12. ⬜ Meta Progression

---

# 🗺️ DEVELOPMENT ROADMAP

The project follows a **vertical slice approach**, completing one fully playable layer before expanding.

---

## ✅ MILESTONE 1 — Playable Dungeon Prototype (COMPLETE)

### Goal

Create a complete playable dungeon loop.

### Tasks

* ✅ Dungeon grid (linear path)
* ✅ Placeable rooms
* ✅ Skeleton room
* ✅ Hero movement
* ✅ Basic combat
* ✅ Hero death
* ✅ Victory/Defeat *(escape vs. death; no run-level game-over yet)*
* ✅ Gold rewards

### Success Criteria

* ✅ A hero can enter the dungeon
* ✅ Combat resolves automatically
* ✅ Gold is earned
* ✅ New rooms can be purchased

---

## 🔴 MILESTONE 2 — Dungeon Progression (IN PROGRESS)

### Goal

Expand the player's choices.

### Tasks

* 🟡 Multiple room types *(trap rooms done — see `TrapData`/`spike_corridor.tres`; utility rooms deliberately deferred until after the card system)*
* ✅ Room upgrades *(multi-tier chains work end-to-end — validated with a 3-tier Skeleton Den; `RoomUpgradeZone` now matches the exact upgrade resource rather than by room name, fixing a bug that would've misfired once a room had 2+ upgrade tiers)*
* ⬜ Economy balancing *(deliberately deferred until all classes behave like a real party — Tank/Healer now have real kits, but Mage/Ranger/Rogue are still basic-attack only, so tuning gold/cost numbers now would just need redoing once they're finished)*
* ✅ Dungeon expansion (insert/remove rooms mid-run)
* 🟡 Multiple waves *(wave counter exists; no content or party scaling per wave)*

### Success Criteria

* ⬜ Every wave offers meaningful spending decisions
* ⬜ Different room combinations become viable

*(Both success criteria are still honestly unmet — one trap type and a single room's upgrade chain isn't build variety yet. That's Milestone 3 (cards) and more room content territory.)*

---

## 🟠 MILESTONE 3 — Card System (NOT STARTED)

### Goal

Introduce build variety.

### Tasks

* ⬜ Card rewards
* ⬜ Draft system
* ⬜ Card rarities *(`CardData.rarity` exists, unused in gameplay)*
* ⬜ Synergies
* ⬜ Card packs

### Success Criteria

* ⬜ Every run feels different
* ⬜ Cards significantly influence strategy

---

## 🟡 MILESTONE 4 — Hero Parties (IN PROGRESS)

### Goal

Increase tactical depth.

### Tasks

* 🟡 Multiple hero classes *(`class_type` now drives formation position; Tank and Healer have real kits, Mage/Ranger/Rogue don't yet)*
* 🟡 Party AI *(aggro/threat table + Tank taunt hard-override implemented in `CombatManager`; no hero-side targeting AI yet - heroes still pick a random enemy)*
* 🟡 Hero abilities *(`AbilityData` + cooldown system implemented; Tank: Shield Wall + Taunt, Healer: Heal + Chain Heal; Mage/Ranger/Rogue kits not started)*
* ⬜ Elite heroes
* ⬜ Party compositions

### Success Criteria

* ⬜ Different parties require different dungeon builds

---

## 🟢 MILESTONE 5 — Boss Encounters (NOT STARTED)

### Goal

Create memorable finales.

### Tasks

* ⬜ Boss room
* ⬜ Boss AI
* ⬜ Multiple boss phases
* ⬜ Boss upgrades
* ⬜ Raid mechanics

### Success Criteria

* ⬜ Boss fights become the climax of each biome

---

## 🔵 MILESTONE 6 — Biomes (NOT STARTED)

### Goal

Create complete runs.

### Tasks

* ⬜ Mountain biome
* ⬜ Dwarven Mine
* ⬜ Haunted Crypt
* ⬜ Additional bosses
* ⬜ Unique mechanics

### Success Criteria

* ⬜ Players progress through multiple distinct regions

---

## 🟣 MILESTONE 7 — Meta Progression (NOT STARTED)

### Goal

Long-term replayability.

### Tasks

* ⬜ Dark Essence
* ⬜ Unlock system
* ⬜ New rooms
* ⬜ New heroes
* ⬜ New monsters
* ⬜ New cards

### Success Criteria

* ⬜ Every run contributes to future progress

---

# 📌 DEVELOPMENT STRATEGY

* Build vertically
* Use placeholder art until systems are fun
* Everything should be data-driven
* Avoid hardcoding content
* Test constantly
* Prioritize gameplay feel over visuals

> **If defending your dungeon isn't fun with simple colored squares, adding beautiful art won't fix it.**
