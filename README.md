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

---

## 🧠 DATA-DRIVEN ARCHITECTURE

**Resources = Data**

**Scenes = Visual Representation**

**Scripts = Behavior**

Everything should be data-driven using Godot Resources.

---

## 📂 PROJECT STRUCTURE

```
res://

scripts/
	dungeon/
	combat/
	heroes/
	monsters/
	rooms/
	cards/
	bosses/
	managers/

resources/
	rooms/
	monsters/
	heroes/
	bosses/
	cards/
	biomes/

scenes/
	dungeon/
	rooms/
	heroes/
	monsters/
	ui/
```

---

## 🧩 CORE DATA OBJECTS

### RoomData

Defines a dungeon room.

```
name
cost
room_type
monster
trap
health
upgrade_path
icon
rarity
```

---

### MonsterData

Defines monsters.

```
health
damage
armor
speed
abilities
sprite
```

---

### HeroData

Defines hero classes.

```
health
damage
armor
abilities
priority
class_type
```

---

### BossData

Defines dungeon bosses.

```
health
damage
phases
abilities
summons
```

---

### CardData

Defines upgrade cards.

```
title
description
rarity
effects
icon
```

---

### BiomeData

Defines biome progression.

```
background
music
room_pool
hero_pool
boss
wave_count
special_rules
```

---

## ⚔️ COMBAT SYSTEM

Combat is fully automated.

Heroes and monsters fight using AI.

The player's decisions happen between battles through:

* Room placement
* Upgrades
* Cards
* Economy management

The focus is strategy rather than micro-management.

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

1. Dungeon Grid
2. Placeable Rooms
3. Hero Movement
4. Basic Combat
5. Gold Economy
6. Room Upgrades
7. Wave System
8. Card Drafting
9. Hero Parties
10. Boss Room
11. Biomes
12. Meta Progression

---

# 🗺️ DEVELOPMENT ROADMAP

The project follows a **vertical slice approach**, completing one fully playable layer before expanding.

---

## ✅ MILESTONE 1 — Playable Dungeon Prototype

### Goal

Create a complete playable dungeon loop.

### Tasks

* Dungeon grid
* Placeable rooms
* Skeleton room
* Hero movement
* Basic combat
* Hero death
* Victory/Defeat
* Gold rewards

### Success Criteria

* A hero can enter the dungeon
* Combat resolves automatically
* Gold is earned
* New rooms can be purchased

---

## 🔴 MILESTONE 2 — Dungeon Progression

### Goal

Expand the player's choices.

### Tasks

* Multiple room types
* Room upgrades
* Economy balancing
* Dungeon expansion
* Multiple waves

### Success Criteria

* Every wave offers meaningful spending decisions
* Different room combinations become viable

---

## 🟠 MILESTONE 3 — Card System

### Goal

Introduce build variety.

### Tasks

* Card rewards
* Draft system
* Card rarities
* Synergies
* Card packs

### Success Criteria

* Every run feels different
* Cards significantly influence strategy

---

## 🟡 MILESTONE 4 — Hero Parties

### Goal

Increase tactical depth.

### Tasks

* Multiple hero classes
* Party AI
* Hero abilities
* Elite heroes
* Party compositions

### Success Criteria

* Different parties require different dungeon builds

---

## 🟢 MILESTONE 5 — Boss Encounters

### Goal

Create memorable finales.

### Tasks

* Boss room
* Boss AI
* Multiple boss phases
* Boss upgrades
* Raid mechanics

### Success Criteria

* Boss fights become the climax of each biome

---

## 🔵 MILESTONE 6 — Biomes

### Goal

Create complete runs.

### Tasks

* Mountain biome
* Dwarven Mine
* Haunted Crypt
* Additional bosses
* Unique mechanics

### Success Criteria

* Players progress through multiple distinct regions

---

## 🟣 MILESTONE 7 — Meta Progression

### Goal

Long-term replayability.

### Tasks

* Dark Essence
* Unlock system
* New rooms
* New heroes
* New monsters
* New cards

### Success Criteria

* Every run contributes to future progress

---

# 📌 DEVELOPMENT STRATEGY

* Build vertically
* Use placeholder art until systems are fun
* Everything should be data-driven
* Avoid hardcoding content
* Test constantly
* Prioritize gameplay feel over visuals

> **If defending your dungeon isn't fun with simple colored squares, adding beautiful art won't fix it.**
