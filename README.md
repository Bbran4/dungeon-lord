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

> **Status:** not yet implemented. `RoomData.trap` currently holds a bare
> `Resource` placeholder rather than a real `TrapData` class, and there is
> no trap-specific combat behavior yet — see Next Steps.

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

> **Status:** the `Resource` classes below are all implemented and drive
> gameplay. However, actual content (the skeleton room, the test hero,
> etc.) is still being constructed procedurally in `TestHarness.gd`
> rather than authored as `.tres` files — see Next Steps.

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
	bosses/        # BossData
	biomes/        # BiomeData
	cards/         # CardData
	managers/      # GameManager, EconomyManager, WaveManager,
				   # DungeonManager, CombatManager, HeroManager
	test/          # TestHarness (manual playtest scene driver)

scenes/
	dungeons/      # Dungeon.tscn, DungeonGrid.tscn
	rooms/         # Room.tscn
	test/          # TestHarness.tscn, TestHeroEntity.tscn
```

`resources/` (authored `.tres` content) and a dedicated `combat/` script
folder from the original plan don't exist yet — combat logic currently
lives in `managers/CombatManager.gd` and `core/CombatEntity.gd`.

---

## 🧩 CORE DATA OBJECTS

All of the following are implemented as `Resource` subclasses.

### RoomData

```
room_name : String
cost : int
room_type : String ("Empty" | "Monster" | "Trap" | "Boss")
monster : MonsterData
trap : Resource            # placeholder — no TrapData class yet
health : int
upgrade_path : RoomData
icon : Texture2D
rarity : String ("Common" | "Rare" | "Epic" | "Legendary")
```

---

### MonsterData

```
monster_name : String
max_health : int
damage : int
armor : int
attack_speed : float
abilities : Array[String]
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
abilities : Array[String]
class_type : String ("Tank" | "Healer" | "Mage" | "Ranger" | "Rogue")
priority : int
sprite : Texture2D
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

Combat is fully automated: `CombatManager.begin_combat()` alternates
`attack()` calls between two `CombatEntity` nodes until one reaches 0
health.

The player's decisions happen between battles through:

* Room placement
* Upgrades
* Cards
* Economy management

The focus is strategy rather than micro-management.

> **Known simplification:** `attack_speed` is exported on `CombatEntity`,
> `HeroData`, and `MonsterData`, but the current combat loop ignores it —
> turns strictly alternate attacker/defender regardless of speed. Speed
> as a mechanic isn't wired up yet.
>
> **Known simplification:** each hero fights a *freshly spawned* monster
> instance per room (`Dungeon._spawn_monster_entity`), so a room's
> monster is never worn down or permanently defeated across a wave —
> every hero that reaches an occupied room gets a full-health fight.

---

## 🧭 CURRENT IMPLEMENTATION STATUS

What's actually playable today, via `scenes/test/TestHarness.tscn`:

* ✅ Linear dungeon path (entrance → rooms → exit) rendered by `DungeonGrid`
* ✅ Drag a `RoomCard` from the palette into a `RoomGapZone` to build a room (spends gold)
* ✅ Drag a matching card onto a room's upgrade prompt to upgrade it (spends the cost delta)
* ✅ Click a room to select it and reveal a Sell button (refunds half cost)
* ✅ Send a hero (or test combat sandbox) through the dungeon; combat auto-resolves room by room
* ✅ Gold economy, wave counter, and a scrolling event log
* ✅ Pan (WASD/arrows or middle-mouse drag) and zoom (mouse wheel) camera

Notably **not yet wired up**, despite the underlying scripts existing:

* ⬜ `GameManager`'s building/combat/reward phase signals aren't connected to anything — the test harness doesn't gate actions by phase
* ⬜ `HeroManager` (spawn/remove/clear tracking) isn't used by `Dungeon.gd`, which tracks its own active-hero count independently
* ⬜ No `.tres` authored resources — all test data (`skeleton_room_data`, `test_hero_data`, etc.) is built in code inside `TestHarness.gd`

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
9. ⬜ Hero Parties *(multi-hero API exists in `Dungeon.send_wave`, untested with >1 hero)*
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

* ⬜ Multiple room types (trap rooms, utility rooms)
* 🟡 Room upgrades *(single upgrade tier working; upgrade chains untested)*
* ⬜ Economy balancing
* ✅ Dungeon expansion (insert/remove rooms mid-run)
* 🟡 Multiple waves *(wave counter exists; no content or party scaling per wave)*

### Success Criteria

* ⬜ Every wave offers meaningful spending decisions
* ⬜ Different room combinations become viable

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

## 🟡 MILESTONE 4 — Hero Parties (NOT STARTED)

### Goal

Increase tactical depth.

### Tasks

* ⬜ Multiple hero classes *(`HeroData.class_type` exists, unused in behavior)*
* ⬜ Party AI
* ⬜ Hero abilities
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
