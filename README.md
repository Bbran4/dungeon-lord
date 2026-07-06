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
> bonus scaled off the party's combined value. Both a hero's stats AND
> their `gold_value` scale together with the current wave tier (see
> Wave Progression below), so the gold-per-damage-point rate stays
> constant as waves get tougher rather than degrading. See
> `EconomyManager.gd` and `Dungeon.send_wave()`.

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

> **Status (Utility rooms):** implemented. `RoomData.room_type` includes
> `"Utility"` alongside a `heal_party_on_entry` flag and
> `gold_multiplier` / `trap_damage_multiplier` fields, applied once when
> the party arrives (`Dungeon._apply_utility_room`). Multiple utility
> rooms in one run stack multiplicatively. Effects only apply from that
> point in the path onward — nothing retroactive. See
> `resources/rooms/sanctuary_room.tres` (full heal + 1.5x gold) for a
> working example; a "poison resistance, but weaker elsewhere" room is
> the same fields with different numbers and hasn't been authored yet.

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

> **Status:** implemented, with two distinct trap behaviors sharing one
> `TrapData` resource (`trap_type` picks which): **INSTANT** traps (e.g.
> Spike Corridor) resolve as a single probabilistic damage instance the
> moment the party arrives — no counter-attack, no spawned entity, no
> `CombatManager` involvement. **PROJECTILE** traps (e.g. Poison Arrow
> Corridor) spawn a `PoisonArrowTrapController` at wave start that fires
> pooled `TrapArrow` visuals continuously for the WHOLE wave, entirely
> independent of where the party currently is — arriving at the room
> doesn't trigger anything, since it's already been firing the whole
> time. Each trap can run `max_concurrent_arrows` independent firing
> "slots" at once. An arrow that connects deals an initial hit plus a
> damage-over-tick DoT (`tick_damage` × `tick_count`, spaced
> `tick_interval` apart); an arrow that reaches the far wall (or a
> hero) is recycled, not freed. The party also moves at a reduced speed
> while approaching any room with a monster or a trap
> (`Dungeon.room_danger_speed_multiplier`), which is what gives a
> projectile trap more exposure time to land a hit. A room can have a
> trap, a monster, or both. See `resources/traps/spike_trap.tres` /
> `resources/rooms/spike_corridor.tres` (instant) and
> `resources/traps/poison_arrow_trap.tres` /
> `resources/rooms/poison_arrow_corridor.tres` (projectile) for working
> examples.

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
> dungeon independently. All five classes now have real kits — see
> Combat System for the full breakdown.

---

### Wave Progression

> **Status:** implemented, outcome-driven rather than a manual counter.
> `WaveManager` tracks a difficulty **tier** that only advances when the
> Dungeon Lord fully wipes an incoming party — if any hero escapes, the
> next wave sent is the exact same strength again, so "the wave restarts
> until the player can defeat it" is a direct mechanical consequence
> rather than separately implemented. The stat multiplier increases
> **linearly** per tier survived (1.0x, 1.1x, 1.2x, 1.3x, ...), applied
> to a spawned hero's max health, damage, armor, attack speed, *and*
> gold value all at once — `HeroData` resources themselves are never
> mutated, since they're shared assets (see `Dungeon.send_wave()`).
> Monsters and traps are **not** scaled by wave tier — only heroes get
> stronger as the Dungeon Lord holds the line.

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
> `resources/` — a 3-tier room upgrade chain, a trap room, a utility
> room, and a full hero roster (Tank/Healer/Ranger/Mage/Rogue) — rather
> than constructed in code. `TestHarness.gd` just wires those files in
> via `@export` fields — adding a new monster, room, trap, ability, or
> hero variant no longer requires touching any script. Enum-like fields
> (`AbilityData.ability_type`/`target_rule`, `TrapData.trap_type`) are
> centralized as real enums on `GameEnums` rather than each resource
> declaring its own `@export_enum` string — `RoomData.room_type` and
> `HeroData.class_type`/`CardData.rarity` are still their own
> independent string enums and haven't been converted yet.

---

## 📂 PROJECT STRUCTURE

Reflects the structure as it exists today (not the original target layout):

```
res://

scripts/
	core/          # GameEnums, CombatEntity, CircleVisual, CombatProjectile, PanZoomCamera
	dungeon/       # Dungeon, DungeonGrid
	rooms/         # Room, RoomData, RoomCard, RoomGapZone, RoomUpgradeZone
	heroes/        # HeroData
	monsters/      # MonsterData
	traps/         # TrapData, TrapArrow, PoisonArrowTrapController
	abilities/     # AbilityData
	bosses/        # BossData
	biomes/        # BiomeData
	cards/         # CardData
	managers/      # GameManager, EconomyManager, WaveManager,
				   # DungeonManager, CombatManager, HeroManager
	test/          # TestHarness (manual playtest scene driver)

resources/
	rooms/         # skeleton_den (3 tiers), spike_corridor.tres,
				   # poison_arrow_corridor.tres, sanctuary_room.tres
	monsters/      # skeleton, elite_skeleton, skeleton_champion
	traps/         # spike_trap.tres, poison_arrow_trap.tres
	abilities/     # tank_shield_wall, tank_taunt, cleric_heal, cleric_chain_heal,
				   # ranger_poison_arrow, ranger_explosive_arrow, mage_fireball,
				   # mage_chain_lightning, mage_ice_spike, rogue_poison_strike,
				   # rogue_backstab
	heroes/        # test_adventurer, tank_knight, cleric_healer,
				   # ranger_scout, battle_mage, shadow_rogue

scenes/
	dungeons/      # Dungeon.tscn, DungeonGrid.tscn
	rooms/         # Room.tscn
	traps/         # TrapArrow.tscn
	effects/       # CombatProjectile.tscn
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
room_type : String ("Empty" | "Monster" | "Trap" | "Boss" | "Utility")
monster : MonsterData
trap : TrapData
health : int
upgrade_path : RoomData
icon : Texture2D
rarity : String ("Common" | "Rare" | "Epic" | "Legendary")
heal_party_on_entry : bool      # Utility rooms - full-heals the living party on arrival
gold_multiplier : float         # Utility rooms - stacks multiplicatively, applies for rest of wave
trap_damage_multiplier : float  # Utility rooms - same stacking, affects trap damage taken
```

---

### TrapData

```
trap_name : String
damage : int                    # initial hit - both trap types
trigger_chance : float          # INSTANT only - 0.0-1.0 chance the trap fires when entered
ignores_armor : bool            # traps classically bypass armor entirely
trap_type : GameEnums.TrapType ("Instant" | "Projectile")
tick_damage : int                # Projectile only - damage-over-time per tick
tick_count : int                 # Projectile only - number of DoT ticks
tick_interval : float             # Projectile only - seconds between ticks
projectile_speed : float          # Projectile only - arrow travel speed
projectile_cooldown : float       # Projectile only - per-slot cooldown between shots
max_concurrent_arrows : int        # Projectile only - independent firing "slots"
abilities : Array[String]
icon : Texture2D
```

---

### AbilityData

```
ability_name : String
ability_type : GameEnums.AbilityType ("Attack" | "Heal" | "ChainHeal" | "Buff" | "Taunt" | "DotAttack" | "ChainAttack")
target_rule : GameEnums.AbilityTargetRule ("LowestHpAlly" | "Self")   # only used by Heal/ChainHeal/Buff/Taunt
cooldown : float
magnitude : int        # damage/heal amount, or armor bonus for Buff
duration : float        # buff/taunt duration; unused by instant effects
chain_count : int       # ChainHeal/ChainAttack - extra targets hit/healed
ignore_armor : bool     # Attack/DotAttack/ChainAttack - bypasses armor entirely
tick_damage : int       # DotAttack only - damage-over-time per tick
tick_count : int        # DotAttack only - number of DoT ticks
tick_interval : float   # DotAttack only - seconds between ticks
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
is_melee : bool               # charges into melee range vs. holds and fires a projectile
projectile_color : Color      # tint for ranged attacks; unused if is_melee
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
is_melee : bool             # charges into melee range vs. holds formation and fires a projectile
projectile_color : Color    # tint for ranged attacks/heals; unused if is_melee
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

**Opening actions:** the instant a room fight begins, every living
combatant gets one immediate chance to fire a ready support ability
(Buff/Taunt/Heal/ChainHeal) before the normal random-tick loop takes
over - this is the "party stops in formation and applies buffs, then
the fight begins" beat, rather than leaving a Tank's Taunt or a
Healer's Heal to a random dice roll sometime mid-fight.

**Melee vs. ranged:** every hero/monster is flagged `is_melee`. The
instant a fight begins, melee combatants (Tank, Rogue, and all current
monsters) visually charge partway toward the opposing line; ranged
combatants (Healer, Mage, Ranger) hold their formation position and
fire a small tinted `CombatProjectile` at their target instead of
lunging. Both are purely cosmetic - `CombatManager`'s targeting/damage
never reads position, and survivors are smoothly tweened back into
formation once the room is resolved.

**Aggro:** monsters target using a per-monster threat table (whoever has
dealt that monster the most cumulative damage, including DoT ticks and
chain-attack splash). **Taunt is a hard override** on top of that -
while active, every monster's targeting is forced onto the taunting
hero(es), completely ignoring threat, for the ability's duration.

**Formation:** party members are positioned by `class_type` rather than
spawn order - Tank at the front, Ranger/Mage in the middle, Healer at
the back, Rogue past the monster line entirely.

**Visual feedback:** heroes/monsters render as small filled circles
(`CircleVisual`); melee attacks lunge the attacker toward their target
and back, ranged attacks/heals fire a projectile instead; overlapping
combatants gently push apart (`SeparationArea`); a taunting entity
turns blood red for the taunt's duration; a healed entity flashes green
for 0.5s. Heroes spawn at the entrance one at a time with a small
random stagger rather than all at once, and room-to-room movement (plus
the melee charge-in) eases in/out rather than moving at constant linear
speed.

The player's decisions happen between battles through:

* Room placement
* Upgrades
* Cards
* Economy management

The focus is strategy rather than micro-management.

> **Implemented kits (all five classes):**
> * **Tank** — `Shield Wall` (self-buff armor), `Taunt` (hard-override aggro)
> * **Healer** — `Heal` (lowest-HP ally), `Chain Heal` (splashes to 2 more allies at reduced effectiveness)
> * **Mage** — `Fireball` (big single hit), `Chain Lightning` (primary + 2 additional random enemies), `Ice Spike` (another single-target bolt)
> * **Ranger** — `Poison Arrow` (initial hit + DoT, ignores armor), `Explosive Arrow` (big armor-ignoring hit)
> * **Rogue** — `Poison Strike` (initial hit + DoT, ignores armor), `Backstab` (big armor-ignoring hit)
>
> **Known simplification:** hero-side Attack-type targeting (basic
> attacks and any Attack/DotAttack/ChainAttack hero ability) is a
> random living monster - there's no hero-side targeting AI yet (e.g. a
> Rogue preferring an untaunted target for a bonus, or Chain Lightning
> preferring clustered targets over random ones).
>
> **Known simplification:** DoT ticks and Chain Attack's extra hits
> don't get their own log line per tick/target beyond the opening hit -
> kept quiet deliberately so a multi-tick poison doesn't spam the event
> log.
>
> **Known simplification:** projectiles are cosmetic-after-the-fact -
> damage applies instantly and the projectile is spawned as a visual
> flourish, not a delay before the hit registers (same simplification
> the melee lunge already made).

---

## 🧭 CURRENT IMPLEMENTATION STATUS

What's actually playable today, via `scenes/test/TestHarness.tscn`:

* ✅ Linear dungeon path (entrance → rooms → exit) rendered by `DungeonGrid`
* ✅ Drag a `RoomCard` from the palette into a `RoomGapZone` to build a room (spends gold)
* ✅ Drag a matching card onto a room's upgrade prompt to upgrade it (spends the cost delta); upgrade chains of 3+ tiers work correctly, matched by exact resource rather than by room name
* ✅ Click a room to select it and reveal a Sell button (refunds half cost)
* ✅ Rooms visually display their occupying monster's name, not just the room name
* ✅ Trap rooms: INSTANT traps resolve as a single probabilistic damage instance (no counter-attack, no `CombatManager`); PROJECTILE traps fire pooled `TrapArrow` visuals continuously for the whole wave regardless of party position, dealing an initial hit plus a multi-tick DoT, with configurable concurrent arrow count
* ✅ Utility rooms (`RoomData.room_type == "Utility"`): one-time party heal on entry, plus stacking gold/trap-damage multipliers for the rest of the wave
* ✅ Party moves at a reduced speed approaching any room with a monster or trap (`Dungeon.room_danger_speed_multiplier`), giving projectile traps more exposure time to land hits
* ✅ Multi-hero parties (Tank/Healer/Ranger/Mage, plus a random 4th class) move and fight together as a real group via `Dungeon.send_wave()` + `CombatManager.begin_group_combat()` — not solo runs anymore
* ✅ Heroes spawn at the entrance one at a time with a small random stagger, rather than all appearing at once
* ✅ Class-based formation (Tank front, Ranger/Mage mid, Healer back, Rogue flanking past the monster line)
* ✅ Monsters spawn visibly in their room up front (not lazily on arrival) and stay put until fought or the wave ends
* ✅ Melee vs. ranged distinction: melee combatants (Tank, Rogue, all current monsters) visually charge partway toward the opposing line when a fight begins; ranged combatants (Healer, Mage, Ranger) hold formation and fire a projectile instead — purely cosmetic, doesn't affect targeting/damage
* ✅ Opening-actions beat: every combatant gets one immediate chance to fire a ready support ability (Buff/Taunt/Heal/ChainHeal) the instant a fight starts, instead of waiting on a random tick roll
* ✅ Aggro via a per-monster threat table (highest cumulative damage dealt, including DoT ticks and chain-attack splash); Tank `Taunt` is a hard override that forces monster targeting onto the taunting hero for its duration, and is correctly cleared the instant its owner dies rather than only on timeout
* ✅ Ability/cooldown system (`AbilityData`) with all five class kits implemented — Tank (Shield Wall, Taunt), Healer (Heal, Chain Heal), Mage (Fireball, Chain Lightning, Ice Spike), Ranger (Poison Arrow, Explosive Arrow), Rogue (Poison Strike, Backstab) — each combatant picks randomly among whichever abilities are off cooldown
* ✅ Two additional ability types beyond plain Attack: `DotAttack` (initial hit + ticking damage, e.g. poison) and `ChainAttack` (primary target + N additional random enemies at reduced damage, e.g. Chain Lightning)
* ✅ Heroes/monsters render as small filled circles (`CircleVisual`, 20% smaller than the original placeholder squares) instead of squares
* ✅ Visual combat feedback: melee attack lunge toward target and back, ranged attacks/heals fire a tinted `CombatProjectile`, overlap-based separation push between combatants, taunting entities turn red, healed entities flash green
* ✅ Room-to-room movement and the melee charge-in both ease in/out (`TRANS_SINE`/`EASE_IN_OUT`) rather than moving at constant linear speed
* ✅ Ability usage narrates itself into the event log (`CombatManager.ability_used`) — every attack, heal, buff, and taunt (plus taunt expiry) is a readable log line, which is also how a mismatched `.tres` enum value was caught and fixed during testing
* ✅ Wave difficulty is outcome-driven, not a manual counter: `WaveManager`'s tier only advances on a full party wipe; escaping heroes send the same-strength party again. The stat multiplier scales **linearly** per tier (1.0x, 1.1x, 1.2x, ...) and applies to a spawned hero's health/damage/armor/attack-speed *and* gold value together, so the gold-per-damage rate stays constant as waves get tougher. Monsters and traps are not scaled by tier
* ✅ Gold economy, wave counter, and a scrolling event log
* ✅ Pan (WASD/arrows or middle-mouse drag) and zoom (mouse wheel) camera
* ✅ `GameManager` gates building actions by phase (insert/upgrade/sell only succeed during BUILDING, enforced in `DungeonGrid`); "Send Wave" transitions to COMBAT, `Dungeon.wave_cleared` transitions to REWARD, which currently loops straight back to BUILDING (no card draft yet)
* ✅ `HeroManager.spawn_hero`/`remove_hero`/`active_heroes` backs `Dungeon.gd`'s hero tracking directly — no more private hero counter
* ✅ Room/monster/trap/ability/hero content authored as real `.tres` resources under `resources/`, wired into `TestHarness` via `@export` fields
* ✅ Gold is earned per-hero based on damage taken vs. effective max health, plus a full-wipe bonus — not from winning fights or clearing rooms (see `EconomyManager.gd`)
* ✅ Enum-like data (`AbilityData.ability_type`/`target_rule`, `TrapData.trap_type`) centralized on `GameEnums` rather than duplicated as independent `@export_enum` strings per resource

Notably **not yet wired up**, despite the underlying scripts existing:

* ⬜ No reward-phase content yet — `_on_reward_phase_started` immediately loops back to building since there's no card draft system
* ⬜ `BossData` has no room encounter, phase, or summon logic
* ⬜ `RoomData.room_type`, `HeroData.class_type`, and `CardData.rarity` are still independent `@export_enum` strings, not yet centralized on `GameEnums` like `AbilityData`/`TrapData` were
* ⬜ No hero-side targeting AI — heroes (and their abilities) still pick a random living enemy rather than anything priority-based

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
7. ✅ Wave System *(outcome-driven tier: only advances on a full wipe; linear stat + gold scaling per tier — see Wave Progression)*
8. ⬜ Card Drafting
9. 🟡 Hero Parties *(parties move and fight together with class formation, aggro/taunt, melee-vs-ranged, and all five class kits implemented; still no hero-side targeting AI — see Milestone 4)*
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

## ✅ MILESTONE 2 — Dungeon Progression (COMPLETE)

### Goal

Expand the player's choices.

### Tasks

* ✅ Multiple room types *(Trap rooms — both INSTANT and PROJECTILE/DoT variants — and Utility rooms are all implemented; see `TrapData`/`spike_corridor.tres`/`poison_arrow_corridor.tres` and `sanctuary_room.tres`)*
* ✅ Room upgrades *(multi-tier chains work end-to-end — validated with a 3-tier Skeleton Den; `RoomUpgradeZone` now matches the exact upgrade resource rather than by room name, fixing a bug that would've misfired once a room had 2+ upgrade tiers)*
* 🟡 Economy balancing *(the original blocker is gone — all five classes now have real kits — but the actual gold/cost number-tuning pass itself hasn't happened yet; carrying forward rather than blocking the milestone on it)*
* ✅ Dungeon expansion (insert/remove rooms mid-run)
* ✅ Multiple waves *(outcome-driven tier progression with linear stat/gold scaling — see Wave Progression; no per-wave CONTENT variation yet, e.g. new room/monster pools unlocking at higher tiers)*

### Success Criteria

* 🟡 Every wave offers meaningful spending decisions
* 🟡 Different room combinations become viable

*(Called complete per project decision — there's now genuine room/trap/utility variety, full class kits with distinct melee/ranged behavior, and outcome-driven difficulty scaling, which together clear the original bar for this milestone. Both success criteria are marked 🟡 rather than ✅ in the spirit of staying honest: there are a handful of room types, not yet the deep build variety the vision calls for, and the economy still hasn't had a real tuning pass. That deeper variety is explicitly Milestone 3 (cards) and further room content territory.)*

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

* ✅ Multiple hero classes *(`class_type` drives formation position AND melee/ranged behavior; all five classes have real kits)*
* 🟡 Party AI *(aggro/threat table + Tank taunt hard-override implemented in `CombatManager`; no hero-side targeting AI yet - heroes still pick a random enemy)*
* ✅ Hero abilities *(`AbilityData` + cooldown system implemented for all five classes - Tank: Shield Wall + Taunt, Healer: Heal + Chain Heal, Mage: Fireball + Chain Lightning + Ice Spike, Ranger: Poison Arrow + Explosive Arrow, Rogue: Poison Strike + Backstab)*
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
