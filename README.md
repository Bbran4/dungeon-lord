# 🏰 DUNGEON LORD

*A dungeon-building roguelite where you don't defend a dungeon — you cultivate an infamous evil kingdom.*

Design deadly dungeons, draft powerful upgrades, and outthink every party of adventurers sent to end you.

---

## 🎯 CORE VISION

Dungeon Lord is not about building the strongest dungeon.

It's about building the **smartest** one.

Heroes aren't moving HP bars — they're expeditions with goals, fears, and strategies of their own. They scout, they remember what worked against you last time, and they adapt. Your job isn't to stack bigger numbers; it's to stay one step ahead of the next party that thinks it can clear you.

> "The poison softened them up, then my spiders cocooned the healer before my skeletons overwhelmed the tank."

That's the sentence a good run produces. Not "I bought another +15% trap damage." Every system in this document exists to make that sentence more likely.

**Success isn't measured by how much damage your traps deal. It's measured by how cleverly you outwit the next expedition.**

---

## 🧱 DESIGN PILLARS

**Every run tells a story.**
Players should remember what happened, not just what wave they reached.

**Heroes fight intelligently.**
Heroes are adventurers, not spawns. Each has a class, and — as the game grows — goals, fears, and a personality that changes how they play against you.

**Everything interacts.**
Rooms, monsters, traps, bosses, heroes, and (eventually) status effects and resources should combo off each other rather than sit in isolation.

**Adapt or die.**
If one strategy dominates, the world should eventually respond to it. Nothing should stay solved forever.

These pillars are the target. The **Current Implementation Status** section below is an honest account of how far the actual codebase has gotten toward them — some pillars are load-bearing today, others are still just the plan.

---

## 👑 CORE CONCEPT

You are not the hero. You are the Dungeon Lord.

Heroes invade your dungeon in organized expeditions, battling through your monsters and traps in an attempt to defeat your boss.

* Build your dungeon
* Outwit every hero party
* Grow your reputation
* Conquer new regions

---

## 🧠 CORE GAMEPLAY LOOP

```
Start Run

↓

Receive Starting Hand (3 cards) + Starting Gold

↓

Build Dungeon (drag cards from hand into gaps)

↓

Hero Party Enters

↓

Heroes Fight Through Dungeon

↓

Victory (Full Wipe) / Retry (Escape)

↓

Earn Gold

↓

Post-Wave Shop (buy cards into your hand, buy passives, buy packs)

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

## ⚔️ WHAT'S BUILT TODAY

This section describes systems that exist and run in `scenes/test/TestHarness.tscn`. The section after it, **The Bigger Vision**, describes where the game is headed — none of that is implemented yet, and it's kept clearly separate so the two never get confused.

### 🏰 Dungeon Building

Build rooms, upgrade them, expand your dungeon mid-run, and create combinations that work well together.

> **Status:** implemented, with a hard cap. `DungeonManager.max_rooms`
> (6) limits how many rooms a dungeon can hold at once — once at cap,
> every `RoomGapZone` locks itself (`DungeonGrid._update_gap_zone_lock_state`),
> refusing to even show itself during a card drag, let alone accept a
> drop. Selling a room re-opens a slot immediately.

### 🃏 Card Hand System

Rooms and traps **are** the cards — there's no separate ability-modifier card type (yet).

* **`CardHandManager`** (autoload) is the single source of truth for
  which `RoomData` cards the player currently holds
  (`CardHandManager.hand`).
* **Starting hand:** 3 cards, dealt out at run reset
  (`TestHarness.starting_hand_cards`).
* **Acquiring more cards:** buying a room in the post-wave shop
  (`ShopManager.buy_room`) or winning one from a card pack
  (`ShopManager.buy_pack`) adds straight to the hand via
  `CardHandManager.add_card`.
* **Placing a card:** dragging a card out of the hand onto a
  `RoomGapZone` calls `DungeonGrid.request_insert`, which consumes the
  matching card from the hand instead of charging gold at drop time —
  the cost was already paid when the card was acquired. A failed
  insert refunds the card back to the hand.
* **Upgrade cards are separate.** The two upgrade palette entries
  remain fixed, always-available, gold-delta-charged slots — only
  base-tier room/trap acquisition moved to the hand.
* **Visual presentation** (`CardHandUI` + `RoomCard.gd`): real visual
  cards with a rarity-tinted border (`GameEnums.Rarity`), a gold-cost
  badge, room icon/art, and description text. The hand fans out
  poker/Yu-Gi-Oh-style, peeking above the bottom of the screen and
  rising fully into view on hover via an unclipped overlay layer.

> **Status:** implemented for base-tier room/trap cards. Still missing
> from the original card-drafting vision: the shop lets you **buy**
> any/all of its offered cards rather than forcing a single drafted
> choice, and there's no ability-modifier ("+15% trap damage", hero
> debuff) card type. See Milestone 3 below.

### 🧱 Dungeon Rooms

Rooms contain monsters, traps, utility effects, or a boss encounter, and are meant to work together.

> **Status (Utility rooms):** implemented. `RoomData.room_type` includes
> `"Utility"` alongside a `heal_party_on_entry` flag and
> `gold_multiplier` / `trap_damage_multiplier` fields, applied once when
> the party arrives (`Dungeon._apply_utility_room`). Multiple utility
> rooms in one run stack multiplicatively, and effects only apply from
> that point in the path onward. See `resources/rooms/sanctuary_room.tres`.
>
> **Status (room cap):** implemented, `DungeonManager.max_rooms = 6`.
>
> **Status (card-facing fields):** `RoomData` carries a
> `description` field for card flavor text, and `rarity` is a real
> `GameEnums.Rarity` value that drives a card's border color in
> `RoomCard.gd` (Common/Rare/Epic/Legendary each get a distinct tint).

### 👹 Monsters

Each monster belongs to a room, with health, damage, armor, attack speed, and special abilities defined on data resources.

### 🪤 Traps

Two distinct trap behaviors share one `TrapData` resource (`trap_type` picks which):

* **INSTANT** traps (e.g. Spike Corridor) resolve as a single
  probabilistic damage instance the moment the party arrives — no
  counter-attack, no spawned entity, no `CombatManager` involvement.
* **PROJECTILE** traps (e.g. Poison Arrow Corridor) spawn a
  `PoisonArrowTrapController` at wave start that fires pooled
  `TrapArrow` visuals continuously for the whole wave, independent of
  where the party currently is. Each trap can run
  `max_concurrent_arrows` independent firing slots at once. A landed
  arrow deals an initial hit plus a damage-over-tick DoT; a missed
  arrow is recycled, not freed.

> **Status:** implemented. A room can have a trap, a monster, or both.
> The party also moves at reduced speed approaching any room with a
> monster or trap (`Dungeon.room_danger_speed_multiplier`), giving
> projectile traps more exposure time to land a hit. See
> `resources/traps/spike_trap.tres` (instant) and
> `resources/traps/poison_arrow_trap.tres` (projectile).

### 🛡️ Hero Parties

> **Status:** implemented as a real group. Parties of 3–4 (Tank,
> Healer, a random Mage/Ranger DPS, plus a random 4th class) move and
> fight together via `Dungeon.gd`, positioned in a class-based
> formation and resolved as one shared encounter per room via
> `CombatManager.begin_group_combat()`. All five classes have real
> kits — Tank (Shield Wall + Taunt), Healer (Heal + Chain Heal), Mage
> (Fireball + Chain Lightning + Ice Spike), Ranger (Poison Arrow +
> Explosive Arrow), Rogue (Poison Strike + Backstab) — with
> melee/ranged distinction, per-monster threat/aggro tables, a Tank
> taunt hard-override, and an opening beat where support abilities
> fire once before the tick loop begins. Heroes still pick a random
> living enemy to attack rather than any priority-based targeting —
> see Milestone 4.

### 📈 Wave Progression

> **Status:** implemented, outcome-driven rather than a manual
> counter. `WaveManager` tracks a difficulty **tier** that only
> advances when the Dungeon Lord fully wipes an incoming party — if
> any hero escapes, the next wave sent is the exact same strength
> again. The stat multiplier increases linearly per tier survived
> (1.0x, 1.1x, 1.2x, ...), applied to a spawned hero's max health,
> damage, armor, attack speed, and gold value all at once —
> `HeroData` resources themselves are never mutated. Monsters and
> traps are **not** scaled by wave tier.
>
> **Victory condition:** `WaveManager.max_wave` (10) is a real win
> condition. Fully wiping the party at tier 10 triggers
> `GameManager.start_victory()` — the run ends in VICTORY and all
> building/wave controls lock permanently until a full reset.

### 💰 Gold Economy

> **Status:** implemented. Gold is earned per-hero based on how much
> damage they took relative to their effective max health (base max
> health plus any healing received) — killing monsters or reaching
> the exit alive earns nothing on its own. A full party wipe pays an
> additional bonus scaled off the party's combined value. Both a
> hero's stats and their `gold_value` scale together with the current
> wave tier, so the gold-per-damage-point rate stays constant as
> waves get tougher. A `PassiveManager` gold multiplier is applied on
> top, as a separate multiplicative layer. See `EconomyManager.gd`.

### 🛒 Post-Wave Shop System

The shop opens automatically after every full-wipe wave clear (an escape sends the player straight back to Building to retry the same wave).

* **Room offers:** 3 random base-tier rooms per visit, added directly
  to the hand as cards. Buying the same room type twice adds another
  copy.
* **Passive offers:** 3 random permanent passives per visit; passives
  at their stack cap are filtered out of the offer pool.
* **Per-slot purchase limit:** each of the 6 offer slots can only be
  bought once per visit — this is deliberately **not** a forced
  single choice yet (see Milestone 3).
* **Reroll:** once per visit, reshuffles every slot except the
  discounted one, and resets bought status.
* **Discount:** one random slot each visit is discounted (50%) and
  survives a reroll unchanged.
* **Card packs:** unlimited flat-cost purchases, unaffected by reroll
  or the per-slot limit. Each pack randomly rewards gold, a room
  card, or a passive; a roll that can't be granted refunds the
  pack's cost instead.

> **Status:** implemented. See `ShopManager.gd`.

### 🌟 Passives

Permanently-owned upgrades purchased in the shop, tracked for the whole run. Stacking is **additive**, not compounding.

Currently authored (`resources/passives/`): **Golden Touch** (gold multiplier), **Reinforced Minions** (monster health multiplier), **Sharpened Claws** (monster damage multiplier), **Venomous Traps** (trap damage multiplier), **Haggler** (flat reroll-cost discount, capped at 2 stacks).

> **Status:** implemented. See `PassiveManager.gd` / `PassiveData.gd`.

### 👑 Bosses

> **Status:** `BossData` exists as a data resource, but there is no
> boss room encounter logic, phase handling, or summon spawning yet.

---

## 🌌 THE BIGGER VISION (not yet implemented)

Everything below this line is design intent, not shipped functionality. It's kept here deliberately — separate from the section above — so the README never overstates what the game currently does. Treat this as the north star the roadmap is working toward, one milestone at a time.

### Give Heroes Personalities

Beyond class, individual heroes could carry traits that change their behavior mid-run: a Coward who flees below 30% HP, a Treasure Hunter who ignores monsters and rushes gold, a Pyromancer weak to water, a Necromancer whose kills join his side. This turns "a Mage" into a character the player has to read and react to.

### Room Families & Resource Interactions

Instead of rooms only producing stat buffs, rooms could belong to families (Undead, Beast, Mechanical, Arcane, Infernal) and produce resources — corpses, webs, heat, poison — that other rooms consume. A Spider Nest leaves webs; webs slow heroes; a Fire Trap burns the webs; the smoke blinds Rangers. Chains like this create emergent combos instead of hand-picked synergy text.

### Reputation System

The dungeon builds a reputation the world reacts to — "The Poison Dungeon," "The Undead Fortress." Lean on poison too often and expeditions start arriving with antidotes; lean on skeletons and priests become common. This is the single mechanic most likely to keep a dominant strategy from calcifying into "the" build, and is the standout idea from early design discussions on the project.

### A Living, Evolving Dungeon

Rooms could gain experience and branch on upgrade (Skeleton Barracks → Veteran Barracks → Royal Crypt → Bone Cathedral) rather than just getting bigger numbers. The dungeon itself could visibly change over a run — blood stains, spreading webs, corrupted rooms.

### Bosses as Characters

A boss that's "alive" through the run — reacting to what the Dungeon Lord builds, gaining traits, eventually joining the final fight — turns the boss room from a stat check into a relationship.

### Evil Choices

Meaningful decisions with consequences: capture heroes alive vs. sacrifice them, execute prisoners for fear vs. release them for trust, corrupt a hero into joining the dungeon. Each choice could ripple into what future expeditions look like.

### Risk vs. Reward Rooms

Rooms that are a genuine gamble — a Treasure Room that pays out big but makes heroes who reach it stronger, a Dragon Egg that's harmless now but a huge loss if destroyed before it hatches.

---

## 🧠 DATA-DRIVEN ARCHITECTURE

**Resources = Data. Scenes = Visual Representation. Scripts = Behavior.**

> **Status:** implemented. `Resource` classes drive gameplay, and
> content is authored as real `.tres` files under `resources/` — a
> 3-tier room upgrade chain, trap rooms, a utility room, five
> passives, and a full hero roster — rather than constructed in code.
> `TestHarness.gd` wires those files in via `@export` fields — adding
> a new monster, room, trap, ability, hero, or passive no longer
> requires touching any script. Enum-like fields
> (`AbilityData.ability_type`/`target_rule`, `TrapData.trap_type`,
> `PassiveData.effect_type`, and `RoomData.rarity`) are centralized as
> real enums on `GameEnums`. `RoomData.room_type`, `HeroData.class_type`,
> and `CardData.rarity` are still independent string enums and haven't
> been converted yet.

---

## 🛡️ STABILITY: HERO LIFECYCLE SAFETY

A recurring class of crash (`Invalid type in function — previously freed object`) was traced to `queue_free()` deferring deletion to end-of-frame — `is_instance_valid()` alone stays `true` within the same frame a hero is queued for deletion.

**Fix:** a combined `_is_alive()` helper (`is_instance_valid()` + `not is_queued_for_deletion()`) now guards every read of a possibly-freed hero/monster reference across call boundaries — `Dungeon.gd`'s movement, trap resolution, death/escape handling, and `CombatManager`'s taunt tracking and living-group checks all route through it. `HeroManager.remove_hero()` only updates tracking and never calls `queue_free()` itself, so it's safe to call even on an already-freed entry.

---

## 🧭 CURRENT IMPLEMENTATION STATUS

What's actually playable today, via `scenes/test/TestHarness.tscn`:

* ✅ Linear dungeon path (entrance → rooms → exit), capped at 6 rooms with gap-zone locking at the cap
* ✅ **Card hand system:** starting hand of 3 cards, dragged from a fanned hand into a `RoomGapZone` to place for free
* ✅ **Visual cards:** rarity-tinted border, gold-cost badge, room icon/art, description
* ✅ **Hand presentation:** peek-and-rise fan via an unclipped overlay layer
* ✅ Drag a matching upgrade card onto a room's upgrade prompt to upgrade it; 3+ tier chains work correctly
* ✅ Click a room to select it and sell it for a half-cost refund
* ✅ Rooms visually display their occupying monster's name
* ✅ Trap rooms: INSTANT single-hit and PROJECTILE continuous-DoT variants
* ✅ Utility rooms: one-time heal on entry plus stacking gold/trap-damage multipliers
* ✅ Reduced party movement speed approaching danger rooms
* ✅ Multi-hero parties (Tank/Healer/Ranger/Mage + random 4th) move and fight as a real group
* ✅ Heroes spawn one at a time with a small random stagger
* ✅ Class-based formation with a melee-charge visual beat at combat start
* ✅ Monsters spawn visibly up front, not lazily on arrival
* ✅ Tick-based group combat: threat/aggro tables, ability cooldowns, Tank taunt hard-override, opening support beat
* ✅ Full class kits for all five hero classes
* ✅ Outcome-driven wave tiers: only a full wipe advances the tier; an escape retries the same-strength wave
* ✅ **10-wave victory condition:** a real run-level VICTORY state, not just an infinite tier counter
* ✅ **Post-wave shop:** 3 room + 3 passive offers, once-per-visit reroll, unlimited card packs, one discounted slot per visit
* ✅ **Passives:** 5 authored passives, additive stacking, per-passive stack caps
* ✅ **Hero lifecycle safety:** `_is_alive()` guards at every relevant call boundary
* ✅ Gold economy, wave counter, scrolling event log
* ✅ Pan (WASD/arrows or middle-mouse drag) and zoom (mouse wheel) camera
* ✅ `GameManager` gates building actions by phase; Send Wave → COMBAT → REWARD/VICTORY or back to BUILDING on escape
* ✅ `HeroManager` backs `Dungeon.gd`'s hero tracking directly
* ✅ Room/monster/trap/ability/hero/passive content authored as real `.tres` resources
* ✅ Enum-like data centralized on `GameEnums` (except the three fields noted above)

Notably **not yet wired up**, despite the underlying scripts existing:

* ⬜ No forced single-choice draft — the shop lets the player buy any/all of its offered cards; `CardData` (the original standalone card resource) is unused
* ⬜ `BossData` has no room encounter, phase, or summon logic
* ⬜ `RoomData.room_type`, `HeroData.class_type`, and `CardData.rarity` still aren't centralized on `GameEnums`
* ⬜ No hero-side targeting AI — heroes pick a random living enemy rather than anything priority-based
* ⬜ No economy/gold-cost tuning pass yet — numbers are functional placeholders
* ⬜ Hand size is uncapped — no overflow handling yet
* ⬜ Everything in **The Bigger Vision** above — hero personalities, room families, resource chains, reputation, living dungeon, room evolution, boss characters, evil choices — is design intent only, with no code behind it yet

> **Architecture note:** the original plan called this a "Dungeon
> Grid," but what's implemented is a **linear ordered path**
> (`DungeonManager` stores a flat, always-contiguous `Array[RoomData]`),
> not a 2D grid. Worth flagging in case a true grid layout is still
> the long-term intent.

---

## 🎲 DESIGN PRINCIPLES

* Easy to understand, difficult to master
* High replayability, strong build variety
* Small decisions every wave, meaningful progression
* Powerful synergies over raw stat increases
* Every run should produce a story worth telling, not just a bigger number

> **If defending your dungeon isn't fun with simple colored squares, adding beautiful art won't fix it.**

---

# 🔥 DEVELOPMENT PRIORITY

The order below changed from earlier drafts of this document. Biomes and
Meta Progression are pure content-scaling — more regions, more unlocks —
and they're only worth building once there's a dungeon worth scaling.
The systems that actually deliver on the "outsmart the heroes" pillars
(intelligent expeditions, reputation, interacting rooms) are pulled
forward ahead of them, right after the two milestones already in
progress.

1. ✅ Dungeon Grid *(implemented as a linear path, capped at 6 rooms)*
2. ✅ Placeable Rooms
3. ✅ Hero Movement
4. ✅ Basic Combat
5. ✅ Gold Economy
6. ✅ Room Upgrades
7. ✅ Wave System *(outcome-driven tier, 10-wave victory condition)*
8. 🟡 Card Drafting *(rooms/traps are real cards in a real hand; still missing a forced single-choice draft and ability-modifier cards)*
9. 🟡 Hero Parties *(class formation, aggro/taunt, full kits done; no targeting AI yet)*
10. ⬜ Hero Expeditions & Reputation *(the core "outsmart the heroes" differentiator — makes heroes intelligent adversaries instead of moving HP bars)*
11. ⬜ Room Families & Living Dungeon *(the "everything interacts" pillar — rooms combo instead of just stacking stats)*
12. ⬜ Boss Encounters *(now includes boss-as-character beats from The Bigger Vision, not just a stat-check fight)*
13. ⬜ Biomes
14. ⬜ Meta Progression

---

# 🗺️ DEVELOPMENT ROADMAP

The project follows a vertical slice approach, completing one fully playable layer before expanding. Milestones 5–7 were reordered ahead of Biomes and Meta Progression so the roadmap builds toward the core vision (outsmarting intelligent heroes) before it builds toward *more content* to outsmart them with.

---

## ✅ MILESTONE 1 — Playable Dungeon Prototype (COMPLETE)

* ✅ Dungeon grid (linear path)
* ✅ Placeable rooms
* ✅ Skeleton room
* ✅ Hero movement
* ✅ Basic combat
* ✅ Hero death
* ✅ Victory/Defeat
* ✅ Gold rewards

---

## ✅ MILESTONE 2 — Dungeon Progression (COMPLETE)

* ✅ Multiple room types (trap + utility)
* ✅ Room upgrades (multi-tier chains)
* 🟡 Economy balancing (real levers exist; no tuning pass yet)
* ✅ Dungeon expansion, capped at 6 rooms
* ✅ Multiple waves (outcome-driven tiers, 10-wave victory)

*(Called complete per project decision — real room/trap/utility variety, full class kits, outcome-driven scaling, and a post-wave shop with passives together clear the original bar. Success criteria stay 🟡 in the spirit of staying honest about remaining build-variety and tuning work.)*

---

## 🟠 MILESTONE 3 — Card System (IN PROGRESS)

* ✅ Card rewards (shop purchase / pack win → hand)
* ⬜ Draft system (currently a shop, not a forced single pick)
* ✅ Card rarities (real enum, drives border color)
* ⬜ Synergies *(will mature once Milestone 6's room families and resource chains exist — a real synergy needs something to synergize with)*
* 🟡 Card packs (functional lucky-dip, not the originally-envisioned drafted pack)

---

## 🟡 MILESTONE 4 — Hero Parties (IN PROGRESS)

* ✅ Multiple hero classes
* 🟡 Party AI (aggro/threat + taunt done, no targeting AI)
* ✅ Hero abilities (all five kits)
* ⬜ Elite heroes
* ⬜ Party compositions

---

## ⚫ MILESTONE 5 — Hero Expeditions & Reputation (NOT STARTED)

### Goal

Make heroes intelligent adversaries instead of moving HP bars — this is the
core differentiator of the "outsmart the heroes" vision, so it's built
before any further content-scaling.

### Tasks

* ⬜ Per-hero personality traits (Coward, Treasure Hunter, Pyromancer, etc.)
* ⬜ Expedition objectives beyond "reach the boss"
* ⬜ Scout report shown before a wave
* ⬜ Reputation system that shifts future expedition composition based on the player's dominant strategy
* ⬜ Heroes that "remember" and counter-pick overused strategies
* ⬜ Evil-choice decision points (capture / sacrifice / corrupt / release) that feed reputation

### Success Criteria

* ⬜ Different heroes require genuinely different dungeon responses
* ⬜ Leaning on one strategy visibly changes what future expeditions look like

---

## ⚪ MILESTONE 6 — Room Families & Living Dungeon (NOT STARTED)

### Goal

Make the dungeon itself feel alive and interconnected — the "everything
interacts" pillar — rather than a rack of independent stat boxes.

### Tasks

* ⬜ Room families (Undead, Beast, Mechanical, Arcane, Infernal)
* ⬜ Produced/consumed resources (corpses, webs, heat, poison, etc.)
* ⬜ Room-to-room chain reactions
* ⬜ Room evolution branches (not just bigger numbers)
* ⬜ Visible dungeon-state changes over a run (blood, webs, corruption)
* ⬜ Risk vs. reward rooms (e.g. a Treasure Room that also strengthens heroes who reach it)

### Success Criteria

* ⬜ Rooms combo with each other without needing a hand-authored "synergy" card
* ⬜ No two 6-room dungeons play identically

---

## 🟢 MILESTONE 7 — Boss Encounters (NOT STARTED)

### Goal

Make the boss room the climax of a biome — and, per The Bigger Vision, a
character the player forms a relationship with, not just a bigger stat
check.

### Tasks

* ⬜ Boss room encounter logic
* ⬜ Boss AI
* ⬜ Multiple boss phases
* ⬜ Boss upgrades
* ⬜ Raid mechanics
* ⬜ Boss reacts to and comments on what's been built over the run
* ⬜ Boss gains traits, or joins the final fight, based on run history

### Success Criteria

* ⬜ Boss fights become the climax of each biome
* ⬜ Players form an actual sense of relationship with their boss across a run

---

## 🔵 MILESTONE 8 — Biomes (NOT STARTED)

* ⬜ Mountain biome
* ⬜ Dwarven Mine
* ⬜ Haunted Crypt
* ⬜ Additional bosses
* ⬜ Unique mechanics

---

## 🟣 MILESTONE 9 — Meta Progression (NOT STARTED)

* ⬜ Dark Essence
* ⬜ Unlock system
* ⬜ New rooms
* ⬜ New heroes
* ⬜ New monsters
* ⬜ New cards
* ⬜ Unlocks informed by a run's reputation history

---

# 📌 DEVELOPMENT STRATEGY

* Build vertically
* Use placeholder art until systems are fun
* Everything should be data-driven, avoid hardcoding content
* Test constantly
* Prioritize gameplay feel over visuals
* Keep this README honest — mark milestones complete by judgment, not by every box being ticked, but never claim a system exists before it does
