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

> **Status:** implemented, with a hard cap. `DungeonManager.max_rooms`
> (6) limits how many rooms a dungeon can hold at once — once at cap,
> every `RoomGapZone` locks itself (`DungeonGrid._update_gap_zone_lock_state`),
> refusing to even show itself during a card drag, let alone accept a
> drop. Selling a room re-opens a slot immediately.

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

> **Status:** not yet implemented as designed. A **post-wave shop**
> (see Post-Wave Shop System below) currently fills this slot in the
> loop instead — it offers rooms and permanent passives for gold rather
> than a drafted card choice. `CardData.rarity` exists as a field but
> is unused; the actual draft system is Milestone 3.

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
> constant as waves get tougher rather than degrading. A `PassiveManager`
> gold multiplier (see Passives below) is applied on top of both, as a
> separate multiplicative layer. See `EconomyManager.gd` and
> `Dungeon.send_wave()`.

### Dark Essence

Permanent progression currency earned after each run.

Used to unlock:

* New rooms
* New monsters
* New cards
* New bosses
* New biomes
* Starting bonuses

> **Status:** not started. No `DarkEssence`-equivalent resource or
> unlock system exists yet — this is Milestone 7.

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

Victory (Full Wipe) / Retry (Escape)

↓

Earn Gold

↓

Post-Wave Shop (rooms, passives, packs) — substitutes for Card Drafting for now

↓

Upgrade Dungeon

↓

Next Wave (tier scales up only after a full wipe)

↓

Wave 10 Full Wipe → RUN VICTORY

↓

Biome Boss (not yet implemented)

↓

Next Biome (not yet implemented)

↓

Spend Dark Essence (not yet implemented)

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

> **Status (room cap):** implemented. `DungeonManager.max_rooms = 6` is
> a hard ceiling — `DungeonGrid` locks every gap zone once at cap so no
> drop is even accepted, and unlocks them again the moment a room is
> sold.

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
> dungeon independently. All five classes have real kits — Tank
> (Shield Wall + Taunt), Healer (Heal + Chain Heal), Mage (Fireball +
> Chain Lightning + Ice Spike), Ranger (Poison Arrow + Explosive Arrow),
> Rogue (Poison Strike + Backstab) — with melee/ranged distinction,
> per-monster threat/aggro tables, a Tank taunt hard-override, and an
> opening beat where support abilities (heals/buffs/taunt) fire once
> before the tick loop begins. Heroes still pick a random living enemy
> to attack rather than any priority-based targeting — see Milestone 4.

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
>
> **Victory condition:** `WaveManager.max_wave` (10) is a real win
> condition, not just "tier 11." Fully wiping the party at tier 10
> triggers `GameManager.start_victory()` — the run ends in VICTORY
> rather than looping to another shop/wave, and all building/wave
> controls lock permanently until a full reset.

---

### Post-Wave Shop System

The shop opens automatically after every full-wipe wave clear (an
escape sends the player straight back to Building to retry the same
wave — no shop, since nothing was actually won).

* **Room offers:** 3 random base-tier rooms per visit. Buying one
  doesn't insert it directly — it grants a free placement credit,
  redeemed by dragging a dynamically-created card onto the dungeon
  (`ShopManager.consume_free_room`). Buying (or pack-winning) the same
  room type twice stacks additional credits/cards rather than
  overwriting anything.
* **Passive offers:** 3 random permanent passives per visit (see
  Passives below). Passives that have hit their stack cap are filtered
  out of the offer pool entirely.
* **Per-slot purchase limit:** each of the 6 offer slots (3 room + 3
  passive) can only be bought once per visit — buying one room offer
  does not block buying a different room or any passive.
* **Reroll:** limited to once per visit. Reshuffles every slot except
  whichever one currently holds the discount, and resets every slot's
  bought status back to available.
* **Discount:** one random slot (room or passive) each visit is
  discounted (`discount_ratio`, currently 50%) and survives a reroll
  unchanged.
* **Card packs:** unlimited purchases at a flat cost, unaffected by
  reroll or the per-slot limit. Each pack randomly rewards gold, a free
  room credit, or a passive; a roll that can't be granted (empty pool,
  or a maxed-out passive) refunds the pack's cost instead of wasting it.

See `ShopManager.gd`.

---

### Passives

Permanently-owned upgrades purchased in the shop, tracked for the
whole run (reset only on a full reset, not between waves). Stacking is
**additive**, not compounding — two +15% passives of the same effect
type give +30%, not +32.25%. Some passives cap how many times they can
ever be owned (`PassiveData.max_stacks`, 0 = unlimited).

Currently authored (`resources/passives/`):

* **Golden Touch** — gold multiplier
* **Reinforced Minions** — monster health multiplier
* **Sharpened Claws** — monster damage multiplier
* **Venomous Traps** — trap damage multiplier
* **Haggler** — flat reroll-cost discount (capped at 2 stacks)

See `PassiveManager.gd` / `PassiveData.gd`.

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
> `resources/` — a 3-tier room upgrade chain, trap rooms, a utility
> room, five passives, and a full hero roster (Tank/Healer/Ranger/Mage/
> Rogue) — rather than constructed in code. `TestHarness.gd` just wires
> those files in via `@export` fields — adding a new monster, room,
> trap, ability, hero, or passive no longer requires touching any
> script. Enum-like fields (`AbilityData.ability_type`/`target_rule`,
> `TrapData.trap_type`, `PassiveData.effect_type`) are centralized as
> real enums on `GameEnums` rather than each resource declaring its own
> `@export_enum` string — `RoomData.room_type`, `HeroData.class_type`,
> and `CardData.rarity` are still their own independent string enums
> and haven't been converted yet.

---

## 🛡️ STABILITY: HERO LIFECYCLE SAFETY

A recurring class of crash (`Invalid type in function — previously
freed object`) was traced to `queue_free()` deferring deletion to
end-of-frame — `is_instance_valid()` alone stays `true` within the same
frame a hero is queued for deletion, so code reading a "dead" hero back
out of `Dungeon._party` later in that frame could still crash passing
it into a `CombatEntity`-typed slot.

**Fix:** a combined `_is_alive()` helper (`is_instance_valid()` +
`not is_queued_for_deletion()`) now guards every read of a
possibly-freed hero/monster reference across call boundaries —
`Dungeon.gd`'s movement, trap resolution, death/escape handling, and
`CombatManager`'s taunt tracking and living-group checks all route
through it (or the untyped-Variant equivalent) rather than checking
`is_instance_valid()` alone. `HeroManager.remove_hero()` only updates
tracking and never calls `queue_free()` itself, so it's safe to call
even on an already-freed entry.

---

## 🧭 CURRENT IMPLEMENTATION STATUS

What's actually playable today, via `scenes/test/TestHarness.tscn`:

* ✅ Linear dungeon path (entrance → rooms → exit) rendered by `DungeonGrid`, capped at 6 rooms with gap-zone locking at the cap
* ✅ Drag a `RoomCard` from the palette into a `RoomGapZone` to build a room (spends gold)
* ✅ Drag a matching card onto a room's upgrade prompt to upgrade it (spends the cost delta); upgrade chains of 3+ tiers work correctly, matched by exact resource rather than by room name
* ✅ Click a room to select it and reveal a Sell button (refunds half cost)
* ✅ Rooms visually display their occupying monster's name, not just the room name
* ✅ Trap rooms: INSTANT traps resolve as a single probabilistic damage instance (no counter-attack, no `CombatManager`); PROJECTILE traps fire pooled `TrapArrow` visuals continuously for the whole wave regardless of party position, dealing an initial hit plus a multi-tick DoT, with configurable concurrent arrow count
* ✅ Utility rooms (`RoomData.room_type == "Utility"`): one-time party heal on entry, plus stacking gold/trap-damage multipliers for the rest of the wave
* ✅ Party moves at a reduced speed approaching any room with a monster or trap (`Dungeon.room_danger_speed_multiplier`), giving projectile traps more exposure time to land hits
* ✅ Multi-hero parties (Tank/Healer/Ranger/Mage, plus a random 4th class) move and fight together as a real group via `Dungeon.send_wave()` + `CombatManager.begin_group_combat()` — not solo runs anymore
* ✅ Heroes spawn at the entrance one at a time with a small random stagger, rather than all appearing at once
* ✅ Class-based formation (Tank front, Ranger/Mage mid, Healer back, Rogue flanking past the monster line) with a melee-charge visual beat at combat start
* ✅ Monsters spawn visibly in their room up front (not lazily on arrival) and stay put until fought or the wave ends
* ✅ Tick-based group combat with per-monster threat/aggro tables, ability cooldowns, a Tank taunt hard-override, and an opening beat where support abilities (heal/buff/taunt) fire once before the tick loop starts
* ✅ Full class kits for all five hero classes, including melee/ranged distinction and projectile visuals
* ✅ Outcome-driven wave tiers: only a full wipe advances the tier (linear stat + gold scaling per tier survived); an escape retries the same-strength wave
* ✅ **10-wave victory condition:** fully wiping tier 10 triggers a real run-level VICTORY state (`GameManager.start_victory()`), locking all controls — not just an infinite tier counter
* ✅ **Post-wave shop:** opens on every full-wipe clear — 3 room + 3 passive offers (each slot buyable once per visit), a once-per-visit reroll, unlimited card packs, and a per-visit discounted slot; purchased rooms are placed via free-credit cards rather than direct insertion
* ✅ **Passives:** 5 authored passives (gold/monster-damage/monster-health/trap-damage multipliers, reroll discount), additive stacking, with per-passive stack caps enforced at purchase time
* ✅ **Hero lifecycle safety:** the freed-object crash class is resolved via `_is_alive()` guards at every call boundary that reads a hero/monster reference after `begin_combat`/movement/trap resolution — see Stability section above
* ✅ Gold economy, wave counter, and a scrolling event log
* ✅ Pan (WASD/arrows or middle-mouse drag) and zoom (mouse wheel) camera
* ✅ `GameManager` gates building actions by phase (insert/upgrade/sell only succeed during BUILDING, enforced in `DungeonGrid`); "Send Wave" transitions to COMBAT, a full wipe transitions to REWARD (opening the shop) or VICTORY at tier 10, an escape returns to BUILDING to retry
* ✅ `HeroManager.spawn_hero`/`remove_hero`/`active_heroes` backs `Dungeon.gd`'s hero tracking directly — no more private hero counter
* ✅ Room/monster/trap/ability/hero/passive content authored as real `.tres` resources under `resources/`, wired into `TestHarness` via `@export` fields
* ✅ Gold is earned per-hero based on damage taken vs. effective max health, plus a full-wipe bonus and a passive gold multiplier layered on top — not from winning fights or clearing rooms (see `EconomyManager.gd`)
* ✅ Enum-like data (`AbilityData.ability_type`/`target_rule`, `TrapData.trap_type`, `PassiveData.effect_type`) centralized on `GameEnums` rather than duplicated as independent `@export_enum` strings per resource

Notably **not yet wired up**, despite the underlying scripts existing:

* ⬜ No card draft system — the post-wave shop currently fills this role instead; `CardData.rarity` exists but is unused
* ⬜ `BossData` has no room encounter, phase, or summon logic
* ⬜ `RoomData.room_type`, `HeroData.class_type`, and `CardData.rarity` are still independent `@export_enum` strings, not yet centralized on `GameEnums` like `AbilityData`/`TrapData`/`PassiveData` were
* ⬜ No hero-side targeting AI — heroes (and their abilities) still pick a random living enemy rather than anything priority-based
* ⬜ No economy/gold-cost tuning pass yet — numbers are functional placeholders, not balanced

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

1. ✅ Dungeon Grid *(implemented as a linear path, capped at 6 rooms)*
2. ✅ Placeable Rooms
3. ✅ Hero Movement
4. ✅ Basic Combat
5. ✅ Gold Economy
6. ✅ Room Upgrades
7. ✅ Wave System *(outcome-driven tier: only advances on a full wipe; linear stat + gold scaling per tier; 10-wave victory condition — see Wave Progression)*
8. 🟡 Card Drafting *(post-wave shop with rooms/passives/packs substitutes for this today; the actual draft system is still Milestone 3)*
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
* ✅ Victory/Defeat *(escape vs. death per wave, plus a real run-level VICTORY at wave 10)*
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
* 🟡 Economy balancing *(all five classes have real kits, a post-wave shop, and 5 passives now exist, giving the economy real levers to pull — but the actual gold/cost number-tuning pass itself still hasn't happened; carrying forward rather than blocking the milestone on it)*
* ✅ Dungeon expansion (insert/remove rooms mid-run, capped at 6 rooms)
* ✅ Multiple waves *(outcome-driven tier progression with linear stat/gold scaling, plus a 10-wave victory condition — see Wave Progression; no per-wave CONTENT variation yet, e.g. new room/monster pools unlocking at higher tiers)*

### Success Criteria

* 🟡 Every wave offers meaningful spending decisions
* 🟡 Different room combinations become viable

*(Called complete per project decision — there's now genuine room/trap/utility variety, full class kits with distinct melee/ranged behavior, outcome-driven difficulty scaling, and a post-wave shop with passives, which together clear the original bar for this milestone. Both success criteria are marked 🟡 rather than ✅ in the spirit of staying honest: there are a handful of room types, not yet the deep build variety the vision calls for, and the economy still hasn't had a real tuning pass. That deeper variety is explicitly Milestone 3 (cards) and further room content territory.)*

---

## 🟠 MILESTONE 3 — Card System (NOT STARTED)

### Goal

Introduce build variety.

### Tasks

* ⬜ Card rewards
* ⬜ Draft system
* ⬜ Card rarities *(`CardData.rarity` exists, unused in gameplay)*
* ⬜ Synergies
* ⬜ Card packs *(a shop "card pack" already exists as a gold/room/passive lucky-dip — see Post-Wave Shop System — but it isn't a drafted-card pack in the originally designed sense)*

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
