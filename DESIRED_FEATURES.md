# PrimusUI: Desired Features & Advanced Innovations (DESIRED_FEATURES.md)

> **Document Type:** Innovation Specification & Feature Blueprint  
> **Target:** Vanilla WoW 1.12.1 (Interface `11200` | Lua 5.0.2)  
> **Repository:** `Interface/AddOns/PrimusUI`  
> **Status:** Approved for Implementation  

---

## 1. PUIHud: Precision Vertical HUD & Dual-Swing Timing Suite

### Conceptual Vision
**PUIHud** provides a razor-sharp, distraction-free combat heads-up display anchored to the center of the camera. Instead of distorted radial curves, it uses **pixel-perfect vertical status wings** for player and target vitals, paired with a **centralized combat timing rail** across the bottom.

```
  [ LEFT WING BAR: DEFENSIVE ]                                                      [ RIGHT WING BAR: OFFENSIVE ]
  ┌────┐                                                                                                 ┌────┐
  │ 🧪 │ [Major Healing Potion]                                                         [DPS Trinket 1]   │ 💍 │
  ├────┤                                                                                                 ├────┤
  │ 💚 │ [Healthstone]             [ 🚨 ACTIVE-ASSIST: NON-TANK ]   [ ⚔️ ACTIVE-ASSIST: MT ] [DPS Trinket 2]   │ 💍 │
  ├────┤                           ┌────────────────────────────┐   ┌──────────────────────────┐         ├────┤
  │ 🛡️ │ [Shield Wall/Defensive]   │ [Peel/Rescue: Aggro Alert] │   │ [Focus Fire: Target MT]  │ [Sapper Charge] │ 💣 │
  ├────┤                           └────────────────────────────┘   └──────────────────────────┘         ├────┤
  │ 🌿 │ [Tubers/Racial/WotF]      [ LEFT: PLAYER VERTICAL WING ]   [ RIGHT: TARGET WING ]       [Burst Cooldown]│ ⚡ │
  └────┘                           ┌──────────────┬─────────────┐   ┌─────────────┬────────────┐         └────┘
                                   │ Player HP    │ Player Power│   │ Target HP   │ Target Pwr │
                                   │ (Vertical)   │ (Mana/Rage) │   │ (Vertical)  │ (Mana/Rage)│
                                   │              │             │   │             │            │
                                   │              │             │   │             │            │
                                   │              │             │   │             │            │
                                   └──────────────┴─────────────┘   └─────────────┴────────────┘

    ┌────────────────────────────┐ ┌───────────────────────────┬───────────────────────────┐ ┌────────────────────────────┐
    │         PLAYER GCD         │ │    Player Swing Timer     │     Enemy Swing Timer     │ │     ENEMY COOLDOWNS &      │
    │   & Active Cooldowns (ACD) │ │   (Main Hand / Ranged)    │     (Melee White Hits)    │ │      INTERRUPT TIMERS    │
    └────────────────────────────┘ └───────────────────────────┴───────────────────────────┘ └────────────────────────────┘
```

### Core Specifications:
1. **Vertical Status Wings (Left & Right):**
   - **Left Wing (Player):** Vertical Player Health (Class-colored) & Vertical Player Power (Mana Blue / Energy Yellow / Rage Red) with exact percentages and numeric values.
   - **Right Wing (Target):** Vertical Target Health & Vertical Target Power with target classification, level, and name headers.
   - Native 1-pixel borders and flat statusbar textures for 100% pixel clarity on any resolution.
2. **Dual ActiveAssist Smart Action Buttons:**
   - **Left ActiveAssist (Above Left Wing - Peel & Protect / 2-Click "Claim & Execute"):**
     - Monitors group threat and combat log damage for aggro breaks on non-tanks / healers.
     - **The 2-Click "Claim & Execute" Protocol:**
       - **Click 1 ("Claim / Lockout"):** Immediately claims the rescue. Broadcasts a high-priority message over `Primus.Comm` (`CLAIM:<PlayerName>:<ThreatTarget>`). For all other PrimusUI users in the raid/party, the alert instantly dims/clears or displays `[Claimed by <Name>]`, preventing overlapping Taunts, wasted BoPs, or duplicate CC cooldowns.
       - **Click 2 ("Execute"):** Snaps target to the attacker and casts the class rescue spell (Warrior **Taunt/Intervene**, Paladin **BoP**, Mage **Polymorph/Nova**, Rogue **Kick/Gouge**, Druid **Growl**).
       - **Safety Timeout:** If Click 2 is not completed within 1.5s, the claim lock auto-releases.
     - **3-Stage Visual State Machine & Dynamic Color Coding:**
       - **🔴 Stage 1 (Alert / Unclaimed): Transparent Red** (`RGBA: 0.9, 0.15, 0.15, 0.45` backdrop with pulsing red border). Indicates an active threat has appeared and is waiting to be claimed.
       - **🟡 Stage 2 (Claimed / Timeout Window): Glowing Amber** (`RGBA: 1.0, 0.75, 0.10, 0.65` backdrop with amber border). The button is armed on your screen, indicating you have claimed the rescue and have a 1.5s window to execute Click 2.
       - **🟢 Stage 3 (Resolved / Success): Vibrant Emerald Green** (`RGBA: 0.20, 0.85, 0.20, 0.75` backdrop with bright green border). Fires upon successful spellcast/peel, holds solid green for **1.0 second**, and then smoothly fades out to 0% alpha and disappears.
   - **Right ActiveAssist (Above Right Wing - Focus Fire):**
     - Monitors the Main Tank / Raid Main Assist.
     - Displays the tank's active combat target.
     - **Action:** 1-Click instantly assists the tank and snaps target to the tank's primary focus target for unified raid DPS.
3. **HUD Wing Mini-Bars (Bar 10 Native Action Slot Allocation):**
   - **Dedicated Bar 10 Allocation (`Slots 109..120`):** Backed by Blizzard's native Bar 10 backend action slots rather than custom scripting, providing 100% native drag-and-drop from Spellbook/Bags, native range tinting (`IsActionInRange`), native mana usability (`IsUsableAction`), and instant cooldown updates without stance collisions.
   - **4 Buttons Per Wing (8 Total "HUD-Worthy" Slots):**
     - **HUD Left Wing Mini-Bar (4 Buttons):** Slots `109, 110, 111, 112` anchored vertically alongside the Left HUD Wing.
     - **HUD Right Wing Mini-Bar (4 Buttons):** Slots `113, 114, 115, 116` anchored vertically alongside the Right HUD Wing.
     - Slots `117..120` reserved for ActiveAssist / Emergency execution widgets.
   - **Player Decision Philosophy:** The player decides which 8 crucial rotational or emergency abilities/items are "HUD worthy". Players wanting extra full-sized bars stacked near the HUD can move any standard hotbar (Bar 1–5) anywhere using **`PUIMover`**.
   - **Drag & Drop Support:** Full native dragging and dropping directly from the Spellbook, Bags, or Macro frame.
   - **Contextual State-Aware Visibility:** Option to illuminate **only in combat** (`PLAYER_REGEN_DISABLED`) and fade out of combat alongside the HUD.
4. **Bottom Dual-Swing / Auto-Attack Timing Bar:**
   - **Player Swing Timer:** Real-time Main Hand, Off-Hand, and Hunter Auto-Shot cadence indicator for perfect Slam / Aimed Shot / Heroic Strike swing resets.
   - **Enemy Swing Timer:** Real-time enemy white-hit attack cadence tracker for timing Shield Block, Gouge, Parries, and Kiting windows before enemy melee hits land.
5. **Symmetric GCD & Cooldown Rails:**
   - **Left Rail (Player):** 1.5s / 1.0s Global Cooldown ticker + sweeping active cooldown icons (ACD) for primary rotational spells.
   - **Right Rail (Enemy):** Enemy interrupt lockouts (Kick, Pummel, Counterspell) and enemy major defensive/offensive cooldown timers.
6. **Situational Opacity & Scale:**
   - Fully customizable Center Gap (negative space) so the central field of view remains unobstructed.
   - Dynamic situational alpha: **20% (Idle)** &rarr; **80% (Target Selected)** &rarr; **100% (In Combat / Low Health)**.

---

## 2. Tactical Reaction Engine & Emergency Action Widgets ("Smart HUD Pilot")

### Conceptual Vision
Utilizing the unique freedom of Vanilla WoW 1.12.1—where combat actions and targeting are unconstrained by post-2.0 combat lockdown—PrimusUI transforms from a passive status display into an **intelligent tactical combat assistant**.

```
   🔴 STAGE 1: ALERT (UNCLAIMED)
   ┌────────────────────────────────────────────────────────┐
   │ [TRANSPARENT RED]: Aggro Alert (Click 1 to Claim)      │
   └────────────────────────────────────────────────────────┘
                              ▼
   🟡 STAGE 2: ARMED & CLAIMED (1.5s TIMEOUT WINDOW)
   ┌────────────────────────────────────────────────────────┐
   │ [GLOWING AMBER]: "I Got This" (Click 2 to Execute)     │
   └────────────────────────────────────────────────────────┘
                              ▼
   🟢 STAGE 3: RESOLVED / SUCCESS (1.0s HOLD -> FADE OUT)
   ┌────────────────────────────────────────────────────────┐
   │ [EMERALD GREEN]: Rescued! Aggro Peeled (Auto-Dismiss)   │
   └────────────────────────────────────────────────────────┘
```

### Core Mechanics:
1. **Real-Time Threat & Damage Detection:**
   - Monitors `CHAT_MSG_SPELL_CREATURE_VS_PARTY_*` and `CHAT_MSG_COMBAT_CREATURE_VS_PARTY_*`.
   - Detects when a non-tank party member (especially designated Healers or squishy cloth wearers) takes direct hits from un-tanked mobs.

2. **Aggro vs. AoE Discrimination Engine (Zero False-Positive Pipeline):**
   - **Layer 1 (Melee White Hit Guarantee - 100% Certainty):**
     - Mobs *never* swing melee auto-attacks at a unit unless that unit is top of threat.
     - Any event from `CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS` or `CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES` (hits, crits, parries, dodges, blocks, absorbs) triggers immediate aggro alert.
   - **Layer 2 (Unit Target-of-Target Validation):**
     - Cross-references `partyXtarget` / `raidXtarget` without combat lockdown.
     - If `UnitIsUnit(mobUnit .. "target", victimUnit)` is true &rarr; Verified single-target threat lock.
     - If the mob's target is still the **Tank** while a healer takes spell/cleave damage &rarr; Flagged as collateral/AoE and ignored.
   - **Layer 3 (Temporal Multi-Victim Deduplication / 150ms Window):**
     - When spell damage arrives via `CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE`, timestamps are recorded per `[MobName .. SpellName]`.
     - If 2+ party members take damage from the same mob spell within `0.15s`, the event is classified as AoE (`Inferno`, `Rain of Fire`, `Arcane Explosion`, `Lava Bomb`) and suppressed.
   - **Layer 4 (Ability Blacklist & Periodic Channel Filtering):**
     - Automatically discards all ticks from `CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE` (DoTs and ground hazard auras).
     - Blacklists known frontal cones, cleaves, and PBAoE pulses (`Cleave`, `Sweeping Strikes`, `Tail Sweep`, `Dragon Breath`, `Wing Buffet`, `Whirlwind`, `War Stomp`, `Fire Nova`, `Thunder Clap`).

3. **Dynamic Contextual Response Buttons:**
   - A high-visibility, micro-action alert widget immediately animates into the lower peripheral of the PUIHud.
   - One-click / keybindable response executing target switching and spellcasting simultaneously.

### Class-Specific Tactical Modules:

| Class | Tactical Trigger | Left-Click Action | Right-Click / Keybind Action |
| :--- | :--- | :--- | :--- |
| **Warrior** | Party member taking aggro | Assist member & cast **Taunt** / **Mocking Blow** | Target party member & cast **Intervene** |
| **Paladin** | Healer taking burst damage | Cast **Blessing of Protection (BoP)** on healer | Assist member & cast **Righteous Defense** / **Judgment of Justice** |
| **Mage** | Uncontrolled add loose in group | Target loose add & cast **Polymorph** | Cast **Frost Nova** / **Cone of Cold** |
| **Rogue** | Uncontrolled caster/add | Target add & cast **Kick** / **Gouge** | Cast **Blind** on secondary add |
| **Priest** | Tank/Healer taking spike damage | Emergency **Power Word: Shield** on target | Instant **Nature's Swiftness / Flash Heal** |
| **Druid** | Non-tank taking aggro | Shift Bear & cast **Growl** / **Taunt** | Cast **Barkskin** + **Rejuvenation** on member |
| **Warlock** | Loose demon/elemental | Target & cast **Banish** / **Enslave** | Cast **Fear** or use **Healthstone Feed** on target |
| **Hunter** | Add charging healer | Cast **Distracting Shot** on add | Cast **Concussive Shot** / **Freezing Trap** |
| **Shaman** | Caster add casting big spell | Target add & cast **Earth Shock** (Rank 1 interrupt) | Drop **Grounding Totem** / **Tremor Totem** |

---

## 3. Central Triage & Decurse Array ("Healer / Decurser HUD Mode")

### Conceptual Vision
In high-stakes raiding and 5-man dungeons, a healer or decurser's primary optical focus is the vital health and debuff status of the raid. Instead of forcing healers to look away from the action into a corner raid grid, **PUIHud** transforms its central optical gap into an **integrated Emergency Triage & Decurse Array**.

```
                      [ 🚨 ACTIVE-ASSIST ]
                      
  [ LEFT WING: SELF ]       [ TOP PINS: PRIORITY TARGETS ]       [ RIGHT WING: TARGET ]
  ┌────┬────┐             ┌────────────────────────────────┐            ┌────┬────┐
  │ HP │ MP │             │ 🛡️ MT1: Main Tank  [88%] [🛡️] │            │ HP │ MP │
  │    │    │             │ 🛡️ MT2: Off-Tank   [95%] [🛡️] │            │    │    │
  │    │    │             │ 🎯 MA:  Main Assist[72%] [  ] │            │    │    │
  │    │    │             └────────────────────────────────┘            │    │    │
  │    │    │                                                           │    │    │
  │    │    │             [ DYNAMIC EMERGENCY / DECURSE QUEUE ]         │    │    │
  │    │    │             ┌────────────────────────────────┐            │    │    │
  │    │    │             │ 🟣 [CURSE] Healer1  (Lucifron) │            │    │    │
  │    │    │             │ 🟡 [MAGIC] Mage2    (Ignite)   │            │    │    │
  │    │    │             │ 🔴 [CRIT HP] Rogue1 [24%]      │            │    │    │
  │    │    │             │ 🔴 [CRIT HP] Warlock[31%]      │            │    │    │
  │    │    │             └────────────────────────────────┘            │    │    │
  └────┴────┘                                                           └────┴────┘
               [ TIMING RAILS: SWING TIMERS & COOLDOWNS ]
```

### Core Specifications:
1. **Priority Top Pins (Static Anchor):**
   - **Always Visible in Center:** Main Tank 1, Main Tank 2, Off-Tanks, and Main Assist / Priority targets.
   - Displays real-time health %, incoming heal prediction bars, and active mitigation buffs (Shield Block, Stoneskin, Last Stand).
   - Instant click-casting target without losing central situational awareness.
2. **Dynamic Triage & Decurse Queue (Appears on Demand):**
   - **Zero Clutter when Quiet:** Stays completely transparent when no members are afflicted or below danger thresholds.
   - **Prioritized Cleanse Matching:** Automatically queries player's dispel abilities (Mage *Remove Curse*, Priest *Dispel Magic / Abolish Disease*, Paladin *Cleanse*, Druid *Remove Curse / Abolish Poison*, Shaman *Purge / Poison Cleansing*).
   - **Smart Sort Hierarchy:** Afflicted Tanks &rarr; Afflicted Healers &rarr; Afflicted DPS &rarr; Critical Health Deficits (`< 40% HP`).
   - **1-Click Decurse / 1-Key Decurse:** Clicking the afflicted bar or pressing the Decurse Keybind immediately targets and cleanses the top prioritized unit.
3. **Incoming Heal Telemetry & Target Feedback ("The Calming Green Flash"):**
   - **Peer-to-Peer Heal Sync (`HEAL_INC`):** When a healer begins casting or clicks a triage target, a high-speed packet is broadcast over `Primus.Comm` (`HEAL_INC:<Target>:<Spell>:<Amount>:<CastTime>`).
   - **Raid Frame Prediction:** All other PrimusUI healers see an incoming heal bar overlay, preventing duplicate mana waste and overheal snipes.
   - **Target-Side Reassurance ("Green HUD Flash"):** When a player (e.g. Tank at 20% HP or low DPS) is targeted by an incoming heal:
     - Their PUIHud emits a gentle, reassuring **Emerald Green HUD Pulse / Peripheral Glow**.
     - A micro-toast displays `[✨ Incoming Heal: Flash of Light from <HealerName>]`.
     - Prevents panic reactions (such as wasting a 30-minute *Shield Wall* or *Last Stand* when a massive heal is already 0.5s from landing).

---

## 4. Contextual State Machine & Combat Focus Engine ("Zen")

### Conceptual Vision
When exploring cities, questing, or organizing inventory, a player benefits from full interface information (Minimap, Chat, Quest Tracker, Bags, MicroMenu). However, upon engaging in combat, peripheral clutter distracts from encounter mechanics. The **Zen Engine** provides state-driven visibility transitions that automatically strip away non-essential UI elements during combat while keeping rotational action bars and the PUIHud front and center.

```
  OUT OF COMBAT (Town / Exploration Mode)
  ┌─────────────────────────────────────────────────────────────┐
  │ [Minimap]  [Buffs]                    [Quest Log Tracker]   │
  │ [Chat Box]                                                  │
  │                                                             │
  │                     [ PUIHud: 20% Idle ]                    │
  │                                                             │
  │ [Action Bars] [Bags] [MicroMenu]                            │
  └─────────────────────────────────────────────────────────────┘
                              ▼  (PLAYER_REGEN_DISABLED / Combat Pull)
  IN COMBAT (Tactical Cockpit / Zen Mode)
  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │                                                             │
  │                   [ 🎯 PUIHUD: 100% COMBAT ]                │
  │             [ Wings + Timers + ActiveAssist ]               │
  │                                                             │
  │                  [ ⚔️ ACTION BARS: LOCKED ]                  │
  └─────────────────────────────────────────────────────────────┘
```

### Core Specifications:
1. **Action Bar Permanence Rule:**
   - Primary action bars and key rotational bars **remain permanently anchored and visible at all times**. Zen never hides a player's ability bars.
2. **Selective Combat Blackout Checklist (`/pui config`):**
   - [x] **Minimap & Zone Header:** Fades to 0% alpha upon combat entry.
   - [x] **Quest Objective Tracker:** Automatically hides during combat encounters.
   - [x] **Corner Unit Frames:** Suppresses redundant Blizzard/corner Player & Target frames in combat, redirecting focus to PUIHud.
   - [x] **Micro Menu & Bag Bar:** Fades out to eliminate bottom-right corner clutter.
   - [x] **Chat Frame Inactive Dimming:** Fades chat frame to 0% opacity unless an incoming whisper, party chat, or raid warning arrives.
3. **Smooth Alpha Transitions:**
   - Uses smooth 0.25s exponential fades (`UIFrameFadeOut` / `UIFrameFadeIn`) to prevent jarring visual pops.
4. **Hover-to-Peek & Emergency Overrides:**
   - **Hover-to-Peek:** Moving the mouse cursor over the corner of the screen temporarily wakes up the hidden Minimap or Chat box for 3.0s.
   - **Low Health / Critical Threat Override:** Emergency warnings and low-health alerts always punch through regardless of state.

---

## 5. Categorized Mover Engine & Floating Control Dock (Goodbye "Wall of Green")

### The Problem Solved:
Replaces the chaotic, all-or-nothing 33-frame green overlay with an organized, category-driven layout orchestrator.

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│  PRIMUS UI MOVER   [ALL] [BARS] [UNITS] [HUD] [PLAYER] [CLASS] [UTIL]   [GRID] [NUDGE] [LOCK]│
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Core Specifications:
1. **Categorized Frame Registration:**
   - Signature: `PUIMover:Register(frame, key, friendlyName, category)`
   - Categories: `BARS`, `UNITS`, `HUD`, `PLAYER`, `CLASS`, `SOCIAL`, `UTILITY`.
2. **Selective CLI Unlocking:**
   - `/pui move bars` &rarr; Unlocks only action bars.
   - `/pui move units` &rarr; Unlocks only unit frames.
   - `/pui move hud` &rarr; Unlocks only PUIHud & Player Auras.
   - `/pui move class` &rarr; Unlocks only class-specific tickers/widgets.
   - `/pui move player` &rarr; Unlocks Bags, Bank, and Character frames.
3. **Floating Mover Filter Dock:**
   - Displays an elegant control toolbar at the top of the screen during unlock mode.
   - Interactive category pill buttons toggling visibility of drag overlays per category.
   - 1-pixel precision nudge buttons (`[▲] [▼] [◄] [►]`) and magnetic grid overlay toggle.

---

## 6. Centralized Console Architecture & Slash Command Sanitation

### The Problem Solved:
Eliminates rogue global `SLASH_*` declarations that pollute the global namespace and overwrite Blizzard default commands (`/inspect`, `/chat`, `/talents`, etc.).

### Core Specifications:
1. **Single Entry Point (`/pui`):**
   - All modules register sub-commands via `Primus.Console:RegisterSubCommand(command, handler, helpText)`.
   - Universal command structure:
     - `/pui config` &rarr; Opens master options GUI.
     - `/pui move [category]` &rarr; Unlocks frame mover.
     - `/pui bind` &rarr; Toggles Hover-to-Bind mode.
     - `/pui memory` &rarr; Diagnostics and table pool GC.
     - `/pui errors` &rarr; In-game error trace log.
     - `/pui hud` &rarr; Dual-wing HUD configuration.
     - `/pui bags` / `/pui bank` / `/pui hotbars` / `/pui professions` / `/pui gathering` &rarr; Module shortcuts.
2. **Zero Global Overwrites:**
   - Modules are strictly forbidden from declaring top-level `SLASH_*` variables directly in their source files.

---

## 7. PUISpellbook: Traditional 2-Page Spellbook & Custom Color Theming

### Conceptual Vision
While modern list views can be compact, the classic **Two-Page Book layout** represents the soul of World of Warcraft's spellbook experience. **PUISpellbook** combines the authentic 2-page book feel with high-performance modern upgrades: rank flyouts, instant search filtering, and full **customizable background & frame color theming**.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│  PUISPELLBOOK                         [ 🔍 Search Spells... ]                      [X] │
├──────────────────────────────────────────┬─────────────────────────────────────────────┤
│  [ LEFT PAGE ]                           │  [ RIGHT PAGE ]                             │
│                                          │                                             │
│  [✨] Flash Heal [Rank 7 ▼]              │  [✨] Prayer of Healing [Rank 4 ▼]          │
│      380 Mana | 1.5s cast                │      720 Mana | 3.0s cast                   │
│                                          │                                             │
│  [🛡️] Power Word: Shield [Rank 10 ▼]      │  [✨] Renew [Rank 9 ▼]                       │
│      500 Mana | Instant                  │      365 Mana | Instant                     │
│                                          │                                             │
│  [💫] Dispel Magic [Rank 2 ▼]             │  [✨] Holy Nova [Rank 6 ▼]                  │
│      200 Mana | Instant                  │      675 Mana | Instant                     │
│                                          │                                             │
├──────────────────────────────────────────┴─────────────────────────────────────────────┤
│  [◄ Prev Page]                     Page 1 of 3                            [Next Page ►]│
└────────────────────────────────────────────────────────────────────────────────────────┘
 [Tabs on Right: 🌟 Holy | 🛡️ Discipline | 🔮 Shadow | ⚔️ General ]
```

### Core Specifications:
1. **Classic Two-Page Book Layout:**
   - 2-column, 2-page spread (6 spells per page / 12 spells per view) with authentic page turn buttons and audio (`igSpellBookOpen`, `igSpellBookClose`).
   - Side skill-line tabs for class talent disciplines (*Holy, Discipline, Shadow, General, Pet*).
2. **Integrated Multi-Rank Flyout / Downranking Selector:**
   - Groups all learned ranks of the same spell into a single master card (highest learned rank displayed by default).
   - Clicking the `[Rank ▼]` dropdown reveals all learned ranks for instant 1-click downranking and drag-to-bar.
3. **Instant Search & Filter Header:**
   - Real-time search bar at the top filtering spells across all pages and disciplines.
4. **Full Color Customization Suite (`/pui config`):**
   - **Pickable Background Color & Alpha:** Full RGBA color picker (Default: Sleek Obsidian Dark `RGBA: 0.1, 0.1, 0.12, 0.92`, Classic Parchment, Midnight Blue, or Semi-Transparent Glassmorphic).
   - **Pickable Frame Border & Accent Colors:** Custom RGB/Hex picker with 1-click presets (Classic Gold, Class Color, Crimson, Emerald, Cyan).
5. **Drag-and-Drop Interoperability:**
   - Seamless dragging directly onto action bars or PUIHud virtual HUD widgets with zero action slot conflicts.

---

## 8. All-In-One Unified Bags Suite & Interactive Inventory Engine

### Conceptual Vision
Transforms Vanilla's fragmented, multi-bag interface into a **high-efficiency unified inventory hub**. Offers total freedom in layout presentation: from continuous clean grids to bag-grouped containers and smart category sorting, complete with interactive bag highlighting and flexible bag bar triggers.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│  INVENTORY  [ 🔍 Search Items... ]                   [ 34 / 80 Free ]  [SORT] [X]     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  [ PRESET A: CONTINUOUS ] | [ PRESET B: BY BAG ] | [ PRESET C: BY CATEGORY ]           │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                                     │
│  │🗡️│ │🛡️│ │🧪│ │🧪│ │🌿│ │🌿│ │📜│ │💰│ │  │ │  │                                     │
│  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘                                     │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                                     │
│  │  │ │  │ │  │ │  │ │  │ │  │ │  │ │  │ │  │ │  │                                     │
│  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘                                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  [▲ HIDE BAGS]  [🎒 Backpack] [👝 Bag 1] [👝 Bag 2] [👝 Bag 3] [👝 Bag 4]   💰 142g 50s 12c│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Core Specifications:
1. **Bag Bar Display Modes (Global UI Bar):**
   - **Full Bag Bar Mode:** Displays all 5 individual container slots (Backpack + Bags 1–4 + Keyring) for classic visibility.
   - **Single-Button Master Bag Bar:** Replaces the 5-button footprint with a single ultra-compact master bag button featuring a live free/total slot counter badge (`[34/80]`).
2. **Unified Single-Window Master Container:**
   - Unifies all equipped bags (Bags 0–4) into a single cohesive, movable inventory window with 1-pixel borders and quality-colored item borders.
3. **Collapsible Bottom Bag Bar & Interactive Bag Highlight Filter:**
   - A collapsible/hidable bottom dock displaying equipped bag icons.
   - **Interactive Bag Highlighting:** Clicking on any bag in the dock activates a visual spotlight filter:
     - Item slots belonging to that specific bag remain fully illuminated.
     - Item slots from all other bags are dimmed to 20% opacity.
     - Clicking again or clicking "All" clears the filter back to 100% visibility.
4. **Customizable Grid Sizing & Dimensions (`/pui config`):**
   - Configurable column count (8 to 16 columns) and dynamic row wrapping.
   - Adjustable slot size (28px–42px) and slot spacing sliders.
5. **Three Layout Presentation Presets:**
   - **Preset 1 (Unified Continuous Grid):** Single seamless stream of slots flowing left-to-right, top-to-bottom.
   - **Preset 2 (Grouped by Bag):** Single unified window divided into labeled container sub-sections (*Backpack [16/16]*, *Mooncloth Bag 1 [16/16]*, *Herb Pouch [20/20]*, etc.).
   - **Preset 3 (Categorized / Smart Auto-Sort):** Single unified window dynamically grouping items under category headers:
     - ⚔️ *Equipable Weapons & Armor*
     - 🧪 *Consumables (Potions, Elixirs, Food, Bandages)*
     - 🌿 *Trade Goods, Herbs & Crafting Reagents*
     - 📜 *Quest Items & Keys*
     - 🪙 *Junk & Gray Items (1-Click Auto-Vendor)*
     - 🔲 *Empty / Free Slots*
---

## 9. PUIMMButtons: Minimap Button Collector & Organizer

### Conceptual Vision
In Vanilla WoW, installing multiple addons inevitably results in a chaotic ring of messy, overlapping circular buttons ringing the Minimap. **PUIMMButtons** automatically scans the minimap hierarchy, captures scattered addon buttons, strips their archaic circular frames, and docks them into a sleek, unified, collapsible utility bar.

```
  CHAOTIC DEFAULT MINIMAP                      PUIMMBUTTONS DOCKED & ORGANIZED
  ┌─────────────────────────┐                  ┌─────────────────────────┐
  │ 🔘  [MINIMAP]       🔘  │                  │       [MINIMAP]         │
  │🔘                     🔘│                  │                         │
  │ 🔘      (Clutter)     🔘│                  │                         │
  │   🔘                🔘  │                  └─────────────────────────┘
  └─────────────────────────┘                  [ 📦 PUIMMBUTTONS DOCK ]
                                               ┌────┬────┬────┬────┬────┬────┐
                                               │ 🛡️ │ 📊 │ 🗺️ │ 🧪 │ ⚙️ │ ◀️ │
                                               └────┴────┴────┴────┴────┴────┘
```

### Core Specifications:
1. **Automated Non-Blizzard Addon Button Detection:**
   - On load and dynamic addon initialization, iterates over child frames and known button templates (`*_MinimapButton`, `*MinimapFrame`, `LibDBIcon*`, Atlas, DBM, KTM, etc.).
   - Re-parents discovered buttons to the `PUIMMButtons` container frame without breaking their underlying click handlers or tooltips.
2. **Selective Blizzard Button Inclusion (`/pui config`):**
   - Option to capture standard Blizzard minimap icons as well:
     - ✉️ MiniMapMailFrame (Mail indicator)
     - 🔍 MiniMapTrackingFrame (Tracking icon)
     - ⚔️ MiniMapBattlefieldFrame (PvP queue icon)
     - 🔍 MinimapZoomIn / MinimapZoomOut (Zoom buttons)
     - ⏰ GameTimeFrame (Day/Night clock icon)
3. **Flexible Dock Layouts & Styles:**
   - **Horizontal Bar:** Clean strip docked below or above the minimap.
   - **Vertical Bar:** Compact sidebar attached to either edge of the minimap.
   - **Pop-out Drawer:** Hidden by default; smoothly slides out on mouseover or toggle click (`◀️`).
4. **Clean 1-Pixel Styling & Icon Normalization:**
   - Strips legacy curved brass borders and normalizes icon size to crisp 20x20px or 24x24px squares with 1-pixel borders.
   - Repositions mouseover tooltips to anchor cleanly away from the dock.

---

## 10. PUIMinimapper: Minimap Shaper, Sizer & Coordinate Engine

### Conceptual Vision
Transforms the default round Blizzard Minimap into a modern, customizable navigation centerpiece. Gives players complete control over map geometry (Square, Hexagonal, Octagonal, Round), dimension scaling, situational alpha, and integrated coordinate overlays, with full positioning handled directly via **`PUIMover`**.

```
┌────────────────────────────────────────────────────────┐
│  [Zone Header: Ironforge - The Great Forge]       [100%]│
├────────────────────────────────────────────────────────┤
│                                                        │
│                                                        │
│                    MODERN SQUARE                       │
│                       MINIMAP                          │
│                                                        │
│                                                        │
├────────────────────────────────────────────────────────┤
│ [ 📍 Player: 48.2, 52.6 ]      [ 🎯 Cursor: 50.1, 51.4 ]│
└────────────────────────────────────────────────────────┘
```

### Core Specifications:
1. **Multi-Geometry Minimap Masking:**
   - **Modern Square:** Crisp square viewport eliminating wasted circular corner dead-space.
   - **Sleek Hexagon / Octagon:** Geometric sci-fi / fantasy aesthetic masks.
   - **Classic Round:** Enhanced round map with modern 1-pixel border.
   - **Frameless Minimalist:** Edge-to-edge borderless map blending into the HUD.
2. **Dynamic Sizing, Scaling & Alpha:**
   - Slider-based width/height adjustment (120px to 260px) and global scale multipliers.
   - Situational alpha control (e.g. 100% in exploration, customizable fading in combat via Zen Engine).
3. **Integrated Coordinate HUD:**
   - High-precision Player coordinates (`XX.X, YY.Y`) and real-time Cursor coordinates.
   - Custom font selection and position snapping (Top, Bottom, or Inside-Overlay).
4. **Convenience & Navigation Controls:**
   - **Mouse Wheel Zoom:** Zoom in/out smoothly using the mouse scroll wheel over the minimap.
   - **Auto-Zoom Reset:** Automatically resets zoom back to default outer view after 10s of inactivity.
   - **Clean Element Stripping:** Hides redundant Blizzard artwork (compass ring, zone header bar) for a clean modern look.
5. **Full PUIMover Integration:**
   - Registered under the `HUD` / `UTILITY` category in `PUIMover` for visual frame dragging, magnetic grid snapping, and coordinate nudging.

---

## 11. PUIHotbars: Virtualized Action Bar Engine, ID Reuse & Paging Tunnels

### Conceptual Vision
Transforms the rigid, hardcoded Blizzard action bar system into a modern, fully virtualized action bar engine (inspired by Bongos and Bartender). Instead of locking visual buttons to fixed backend slots or clumsily stacking Blizzard frames (`BonusActionBarFrame` on top of `MainMenuBar`), `PUIHotbars` treats Blizzard's 120 backend action slots as an open pool of recycled resources, mediated through dynamic **Paging Tunnels**.

```
  VISUAL BUTTON ARRAY (Screen Layout)
  ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
  │ 1  │ 2  │ 3  │ 4  │ 5  │ 6  │ 7  │ 8  │ 9  │ 10 │ 11 │ 12 │
  └─┬──┴─┬──┴─┬──┴─┬──┴─┬──┴─┬──┴─┬──┴─┬──┴─┬──┴─┬──┴─┬──┴─┬──┘
    │    │    │    │    │    │    │    │    │    │    │    │
    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼    ▼
  ┌───────────────────────────────────────────────────────────┐
  │                 DYNAMIC PAGING TUNNEL                     │
  │  Evaluates: [stance], [stealth], [bonusbar], [mod], [page]│
  └─────────────────────────────┬─────────────────────────────┘
                                │
    ┌───────────────────────────┼───────────────────────────┐
    │ Normal Caster/Battle      │ Stealth / Cat Form        │ Defensive Stance / Bear
    ▼                           ▼                           ▼
[ Slots 1–12 ]              [ Slots 73–84 ]             [ Slots 85–96 ]
```

### Core Architectural Specifications:

1. **Pure Scaling (Zero Texture Cropping):**
   - **No Edge Clipping:** Action button icons must retain their complete, native texture coordinates (`0.0, 1.0, 0.0, 1.0`).
   - **Proportional Scaling:** Visual button dimensions are controlled purely via frame sizing (`btn:SetWidth(size)` / `btn:SetHeight(size)`) and clean 1-pixel borders, eliminating artificial zoom-in distortion.

2. **120-Slot ID Reuse Pool:**
   - Blizzard provides 120 global action slots (`1..120`):
     - `1–12`: Page 1 (Main Action Bar)
     - `13–24`: Page 2 (Main Action Bar Page 2)
     - `25–36`: Page 3 (Right Bar 1 / MultiBarRight)
     - `37–48`: Page 4 (Right Bar 2 / MultiBarLeft)
     - `49–60`: Page 5 (Bottom Right Bar)
     - `61–72`: Page 6 (Bottom Left Bar)
     - `73–84`: Bonus / Stance Page 1 (Stealth, Battle Stance, Cat Form)
     - `85–96`: Bonus / Stance Page 2 (Defensive Stance, Bear Form, Prowl)
     - `97–108`: Bonus / Stance Page 3 (Berserker Stance)
     - `109–120`: Possess / Mind Control / Special Overrides
   - **Decoupled Allocation:** Any visual bar can map to any block of backend IDs. If a player hides a bar (e.g. Bar 5), those 12 slots (`49–60`) are returned to the pool and can be recycled for custom paging pages or stance tunnels.

3. **Paging Tunnels (Dynamic Condition Gateways):**
   - **Eliminates Frame Stacking:** No overlapping `BonusActionBarFrame` on top of `MainMenuBar`. A single unified visual button array handles all stances and pages seamlessly.
   - **Dynamic Resolution:** Button clicks, icons, tooltips, cooldowns, and range checks pass through the Paging Tunnel to resolve the active action ID on the fly:
     ```lua
     function PUIHotbars:GetButtonActionID(barIndex, buttonIndex)
         local activePage = self:ResolveActivePage(barIndex)
         return (activePage - 1) * 12 + buttonIndex
     end
     ```
   - **Condition Support:** Evaluates class stances (Warrior, Druid, Rogue, Priest Shadowform), modifier keys (Shift, Ctrl, Alt), and manual action bar paging (`Shift+1..6` / mousewheel).

4. **Modular Sub-file Architecture:**
   - `PUIHotbars.lua`: Core coordinator, bar geometry layout (Bars 1–5, Stance, Pet), and lifecycle.
   - `Buttons.lua`: Button skinning, 1px border overlay, hotkey text formatting, and Range/Mana color ticker.
   - `XPBar.lua`: Integrated XP & Reputation status bar and hover tooltip.
   - `MicroBags.lua`: Dockable Micro Menu and Bag Bar virtualization.

5. **Dynamic Matrix Configuration (Rows & Columns Sliders per Bar):**
   - Each action bar (Bar 1..5, Stance Bar, Pet Bar) features dedicated **Rows** (1–12) and **Columns** (1–12) sliders in `/pui config`:
     - **Standard Horizontal:** 12 Columns x 1 Row (`12x1`).
     - **Stacked Compact Bottom:** 6 Columns x 2 Rows (`6x2`) or 4 Columns x 3 Rows (`4x3`).
     - **Vertical Side Strip:** 1 Column x 12 Rows (`1x12`) or 2 Columns x 6 Rows (`2x6`).
     - **Square Matrix:** 3 Columns x 4 Rows (`3x4`).
   - Frame container width, height, and button point offsets automatically compute dynamically based on `(row - 1)` and `(col - 1)` grid indices.

6. **HUD Mini-Bar Integration (Bar 10 Dedicated Allocation):**
   - The HUD receives **Bar 10 (`Slots 109..120`)** with 4 dedicated buttons on the Left Wing (`109..112`) and 4 buttons on the Right Wing (`113..116`).
   - The player decides which 8 spells/items are "HUD worthy".
   - Players wanting additional full-sized action bars stacked near or around the HUD can simply adjust their rows/columns and position them anywhere using **`PUIMover`**.

---

## 12. PUIUnitFrames: Built-in Click-Casting & Raid Cleansing Suite

### Conceptual Vision
Eliminates the need for external healing addons (HealBot, Clique, Decursive) by embedding native, hyper-responsive **Click-Casting** directly into Player, Target, Party, and 40-man Raid frames. Taking full advantage of Vanilla 1.12.1's unconstrained Lua execution in combat, players can bind any mouse-click combination to instantly cast spells and cleanse debuffs on group members with automatic previous-target preservation.

```
┌────────────────────────────────────────────────────────┐
│  PUIUNITFRAMES: CLICK-CAST CONFIGURATOR (/pui config)  │
├────────────────────────────────────────────────────────┤
│  [ Click Type ]         [ Action / Spell Name ]        │
│  • Left-Click           Target Unit                    │
│  • Right-Click          Unit Popup Menu                │
│  • Shift + Left-Click   Flash Heal (Rank 7)            │
│  • Ctrl + Left-Click    Dispel Magic (Rank 2)          │
│  • Alt + Left-Click     Power Word: Shield (Rank 10)   │
│  • Shift + Right-Click  Greater Heal (Rank 4)          │
│  • Middle-Click         Renew (Rank 9)                 │
│  • Button 4             Abolish Disease                │
└────────────────────────────────────────────────────────┘
```

### Core Specifications:
1. **Unprotected 1.12.1 Fast-Cast Execution (`CastOnUnit`):**
   - Direct execution via `TargetUnit(unit)` &rarr; `CastSpellByName(spell)` &rarr; `TargetLastTarget()`.
   - Executes instantaneously with zero combat taint, zero delay, and automatic preservation of the player's offensive target.
2. **Comprehensive Click Combinations:**
   - Supports Left, Right, Middle, Button 4, Button 5, and Wheel clicks combined with `Shift`, `Ctrl`, and `Alt` modifiers.
3. **Smart Range & Usability Dimming (40-Yard Engine):**
   - Integrates with `Primus.Range` to fade out-of-range units to 40% alpha, giving healers immediate visual clarity on who is within casting distance.
4. **Incoming Heal Sync Overlay:**
   - Seamlessly renders incoming heal prediction bars on the raid frames via `HealComm` telemetry.
5. **Aura & Debuff Highlight Borders:**
   - Frame borders automatically highlight in standard debuff colors (*Purple for Curse, Blue for Magic, Green for Poison, Brown for Disease*) when a cleansable affliction is detected.

---

## 13. PUISellValue: Hybrid Item Pricing & Vendor Sell Value Engine

### Conceptual Vision
In Vanilla WoW 1.12.1, Blizzard's game engine suppresses vendor sell prices from item tooltips whenever the player is away from a merchant window (`MERCHANT_SHOW`), and `GetItemInfo` only returns 9 values without price metadata. **PUISellValue** provides an instant, universal sell price engine utilizing a **Hybrid Resolution Architecture**: combining a compact built-in database (seeded from pfUI/pfQuest item records) with an autonomous, realm-partitioned **Live Auto-Learning Cache**.

```
┌────────────────────────────────────────────────────────┐
│               TOOLTIP HOVER / ITEM QUERY               │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
              ┌───────────────────────────┐
              │  Is Merchant Frame Open?  │
              └─────────────┬─────────────┘
                     NO     │     YES
             ┌──────────────┴──────────────┐
             ▼                             ▼
  ┌───────────────────────┐   ┌──────────────────────────┐
  │ Query PUISellValue    │   │ Let Blizzard Native Row  │
  │ Hybrid Price Engine   │   │ Render (Prevent Doubles) │
  └──────────┬────────────┘   └──────────────────────────┘
             │
   ┌─────────┴─────────┐
   ▼                   ▼
[ Tier 1: Built-in ]  [ Tier 2: Realm Cache ]
(pfUI / pfQuest DB)   (Learned from Merchants)
```

### Core Specifications:
1. **Hybrid Resolution Hierarchy:**
   - **Tier 1 (Built-In Static DB):** Fast numeric key-value store (`itemID -> priceInCopper`) seeded with standard Vanilla 1.12.1 items and Turtle WoW/OctoWoW custom additions.
   - **Tier 2 (Realm Auto-Learning Cache):** Silently intercepts merchant inventories (`MERCHANT_SHOW`, `MERCHANT_UPDATE`) and container scans to learn and update prices dynamically into `PrimusGlobalDB.PUISellValue.realms[GetRealmName()].prices[itemID]`.
2. **Contextual Tooltip Formatting:**
   - Appends a clean, formatted footer line to item tooltips using Vanilla coin icons or colored abbreviations:
     - **Single Item:** `Sell: 1g 25s 40c`
     - **Stack (>1 items):** `Sell (x5): 7g 27s 00c (1g 25s 40c ea)`
3. **Universal Tooltip Hooks:**
   - Hooks `GameTooltip:SetBagItem`, `SetInventoryItem`, `SetHyperlink`, `SetAction`, `SetCraftItem`, `SetTradeSkillItem`, and `SetLootItem`.
   - Strictly suppresses injection when a merchant window is open to prevent duplicate rows.

---

## 14. PUIQuest: Integrated Quest Navigation & Database Engine

### Conceptual Vision
A fully integrated, zero-shim quest navigation and database engine cannibalized from `pfQuest` and `pfQuest-turtle`, natively integrated into PrimusUI. Eliminates external quest addon dependencies by embedding a complete multi-index query database (`PUIQuest.DB`), dynamic Turtle WoW delta-patching, pooled World Map pins, minimap radar and HUD directional arrow, QuestLog action buttons, and an in-game dark glassmorphic database browser (`/pui db`).

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      PUIQUEST: DATABASE & NAVIGATION                     │
├──────────────────────────────────────────────────────────────────────────┤
│  [ Database Content ]                                                    │
│  [x] Vanilla 1.12.1 Core        [x] Turtle WoW / Custom Additions        │
│                                                                          │
│  [ Navigation & Overlays ]                                               │
│  • World Map POI Pins: Active   • Minimap Radar & HUD Arrow: Active      │
│  • QuestLog Direct Map Link     • In-Game DB Browser (/pui db)           │
└──────────────────────────────────────────────────────────────────────────┘
```

### Core Specifications:
1. **Canonical Zero-Shim Architecture (`PUIQuest.DB`):**
   - Direct absorption of Vanilla 1.12.1 database (items, quests, units, objects, refloot, zones, areatriggers, minimap coordinates, meta, and locales) and Turtle WoW / Custom extensions into `Primus.PUIQuest.DB` without legacy `pfDB` globals or metatable shims.
2. **Dynamic Runtime Delta-Patching (`Patchtable.lua`):**
   - In-memory table patching over `PUIQuest.DB` allowing 1-click toggling between pure Vanilla 1.12.1 and Turtle WoW / custom content via `/pui config` or `/pui quest turtle`. Supports custom race bitmasks (`Goblin` [256], `BloodElf` [512]).
3. **Multi-Index Query Engine (`Database.lua`):**
   - Fast lookup indices for quests (by giver, turn-in, item drop, level), items (by vendor, drop, recipe), units (by spawn zone, coordinates), and objects.
4. **World Map POIs & Minimap Radar / HUD Arrow (`Map.lua` & `Tracker.lua`):**
   - Frame-pooled pins on `WorldMapButton` with level-difficulty colored headers, cluster peeking for dense locations, interactive tooltips, and custom icons (`!` available, `?` turn-in, numbered spawns).
   - Minimap radar pins and rotating 3D HUD directional navigation arrow (`ROTATING-MINIMAPARROW`).
5. **QuestLog & In-Game Database Browser (`Quest.lua` & `Browser.lua`):**
   - Embedded `[Show on Map]` and `[Clean Map]` buttons on `QuestLogFrame`.
   - Themed dark glassmorphic database browser UI (`/pui db` / `/pui quest show`) supporting live entity search.
6. **Cross-Module Handshakes:**
   - Seamless synergy with `PUIQuestWatch` (Alt-Click header / Left-Click auto-focus) and `PUISellValue` (supplying offline vendor baseline prices for 25,000+ items).

