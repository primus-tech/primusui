# PrimusUI: Master Truth Document & Architectural Specification

> **Target Platform:** World of Warcraft: Vanilla 1.12.1 (Client Build 5875 | Interface 11200 | Lua 5.0.2)  
> **Repository Root:** `Interface/AddOns/PrimusUI`  
> **Global Namespace:** `_G.Primus`  
> **SavedVariables:** `PrimusGlobalDB` (Account-Wide) | `PrimusCharDB` (Per-Character)  
> **Slash Commands:** `/pui`, `/primus`  
> **Architecture Standard:** Strict `PUI<Name>` Canonical Nomenclature (Zero Aliasing / Zero Shims)

---

## 1. Project Mission & Core Principles

**PrimusUI** is an all-in-one, modular, and high-performance user interface suite for Vanilla World of Warcraft 1.12.1.

### Core Architectural Axioms:
1. **Monolithic Distribution, Modular Execution:** Players install a single clean addon folder (`PrimusUI`) that provides a cohesive visual aesthetic, unified settings, and a shared high-performance engine, while each feature executes as an isolated, toggleable sub-module.
2. **Canonical `PUI<Name>` Standardization (Zero Aliasing / Zero Shims):** All modular components, directories, file names, local tables, module registrations, and SavedVariables namespaces strictly use the `PUI<Name>` prefix. No temporary alias shims or proxy tables are permitted, eliminating technical debt at the root.
3. **Announce & Listen Micro-Kernel Handshake:** Core initializes a central registration desk. As files parse sequentially in `PrimusUI.toc`, each module announces itself. Core dynamically files modules into registries and provisions database namespaces and options flares without hardcoded dependencies.
4. **Strict Resource Ownership & Request-Driven Interaction:** Every interface domain has exactly **one owner module** (e.g. `PUIHotbars` owns action bars; `PUIBags` owns inventory; `PUIUnitFrames` owns unit frames). External modules must never reach into foreign frames directly; they submit requests via public APIs or broadcast decoupled signals on the Signal Bus (`Events:Fire`).
5. **Zero Waste (GC & CPU Efficiency in Lua 5.0.2):** Vanilla's Lua 5.0.2 environment uses a stop-the-world garbage collector. PrimusUI achieves zero-stutter combat via centralized object recycling pools (`Primus.Memory`), a single master `OnEvent` dispatcher (`Primus.Events`), and a unified master `OnUpdate` ticker (`Primus.Time`).
6. **100% Vanilla Engine Grounding:** Code strictly targets Vanilla 1.12.1 APIs, referencing `FrameXML` as the single source of truth (no taint, no secure action headers, no post-1.12 C functions).

---

## 2. The Complete Master Architecture Blueprint

```
========================================================================================
TIER 1: THE NON-NEGOTIABLE CORE & CONTROLLER RUNTIME (Core/)
========================================================================================
• Bootstrap & Handshake     : Master Controller Election, Flare Discovery, State Handover
• Lua Utility Engine        : Lua 5.0 Polyfills, Math/String/Table utils, Safe Invocation
• Memory & Recycling Pool   : Zero-allocation Table & Object Pool (No GC stutter)
• Time & Ticker Engine      : Central OnUpdate Ticker, Delays, Throttles, Debounces
• Event & Hook Manager      : Safe Event Routing, Function Hooks, Signal Bus
• SavedVariables / DB IO    : Profile Defaults, Schema Migration, Multi-character IO
• Widget Factory            : Fluent Encapsulated UI Builders (Frames, Sliders, Layouts)
• Media & Skinning Registry : Shared Fonts, Textures, Borders, Sounds
• Anim / Tween Engine       : Smooth Easing, Fades, Slide Transitions, Bar Sweeps
• Console & Slash Router    : Command parsing, aliases, formatted output (/pui, /primus)
• CommBus & Serializer      : Inter-addon data exchange via SendAddonMessage
• Localization (L10n)       : Regional text translation dictionaries
• Diagnostic / Debug Engine : SafeCall logging, stack traces, in-game error inspector
• Keybinding Manager        : Programmatic keybind registration without Bindings.xml
• State & Combat Zen Engine : Contextual combat focus transitions and action bar permanence
• Config & Flare Options Hub: Distributed options discovery with static left 25% command center (module dropdown, fast toggle scrollbox, profile manager) and dynamic right 75% LoD canvas

========================================================================================
TIER 2: WORLD, COMBAT & NAVIGATION ENGINES (Modules/Combat, HUD, Units, Bars, Navigation)
========================================================================================
• PUIHotbars                : Action Bars 1–5, Pet Bar, Stance Bar, PUIButtons, PUIXPBar, PUIMicroBags
• PUIHud                    : Vertical status wings (PUIWings), Bar 10 mini-bars (PUIMiniBars), 2-click ActiveAssist (PUIActiveAssist), dual swing/GCD timing rails (PUITimers), and Triage Array (PUITriage)
• PUIAuras                  : Player buff/debuff tracking and positioning
• PUIUnitBase               : Atomic unit frame builder, class-curated click-casting, and debuff highlighting
• PUIUnitFrames             : Player, Target, ToT, Pet, Party (1–4), and 40-man Raid Grid
• PUICombatLog              : Structured parsing of 1.12 combat log strings
• PUICombatAuras            : Target/boss aura duration scanning
• PUIThreat                 : Real-time threat calculation and raid sync (KTM compatible)
• PUIHealComm               : Incoming heal prediction and raid broadcast
• PUICastBar                : Smooth player & enemy spellcasting and channel detection
• PUICooldowns              : Cooldown sweeps, item ICDs, and internal trinket timers
• PUIRange                  : Distance calculation via interaction check distances
• PUITactical               : 4-layer aggro discrimination & 2-click Claim & Execute engine
• PUIMinimapper             : Minimap shaping, zoom, and coordinate HUD
• PUIMMButtons              : Addon button collector dock

========================================================================================
TIER 3: PLAYER & CHARACTER SUB-MODULES (Modules/Player, Professions, Gathering, Classes)
========================================================================================
• PUISpellbook              : Authentic 2-page book spread, rank dropdown flyouts, discipline tabs
• PUIBags                   : Single-window unified inventory for bags 0–4 with search and quality borders
• PUIBank                   : Unified bank container (main bank + bags 5–10) with offline persistent caching
• PUICharacterSheet         : Equipment slot durability percentages and item level display
• PUIItemStats              : Hidden tooltip stat scanner (+Spell Dmg, +Healing, Hit, Crit, MP5)
• PUIVendor                 : Grey junk vendor automation with wearability protection & auto-repair
• PUIReagents               : Consumable, ammo, and soul shard counter monitors
• PUITalents                : Talent tree viewer and spec calculation
• PUIProfessions            : Crafting windows, reagent calculation, recipe tracking
• PUIGathering              : Mining & herbalism node tracking with minimap pins
• Class Nuance Suite        : Dedicated sub-engines for all 9 Vanilla classes (PUIDruid, PUIHunter, PUIMage, PUIPaladin, PUIPriest, PUIRogue, PUIShaman, PUIWarlock, PUIWarrior)

========================================================================================
TIER 4: INTERACTION, SOCIAL & CONTENT SUB-MODULES (Modules/Social, Utility)
========================================================================================
• PUIMover                  : Categorized frame dragger, floating control dock, magnetic grid overlay (/pui move)
• PUIDock                   : Comprehensive Blizzard art stripper and dock organizer
• PUIMerchant               : Full Auction House scanner, statistical market pricing, and tooltip price injection
• PUIFastLoot               : Zero-delay instant auto-looting
• PUIAutoMechanics          : Auto-dismount on action and auto-stand on spell cast
• PUIItemCompare            : Side-by-side equipment comparison tooltips
• PUIMinimapOrbit           : Minimap button consolidation dock
• PUIMailbox                : Mass mail collection ("Open All") and recipient auto-fill
• PUIInspect                : Throttled inspect queue and gear overview cache
• PUIMessenger              : Tabbed instant messenger style chat interface with history
• PUIChat                   : Modernized chat frames with class colors, URLs, and editbox docking
• PUIMasterLoot             : Need/Greed popups, master looter roll tracking, and loot logs
========================================================================================
```

---

## 3. Load-Time Discovery: The "Announce & Listen" Handshake

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        THE 3-PHASE ENGINE BOOT SEQUENCE                                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. Phase 1: Core Provisioning (TOC Top)                                                │
│    • Core/Bootstrap.lua creates global _G.Primus anchor.                               │
│    • Sets up empty registry: registry.modules = {}, registry.addons = {}.              │
│    • Core enters DISCOVERY / LISTENING state.                                          │
│                                                                                        │
│ 2. Phase 2: Sequential Module Announcement (Parse Time)                                │
│    • As each module file executes, it announces itself:                                │
│      Primus:RegisterModule("PUI<Name>", moduleTable, "<Category>")                     │
│    • Core dynamically files the module, registers SavedVariables DB namespace,        │
│      and provisions Options Flare entry without hardcoded dependencies.               │
│                                                                                        │
│ 3. Phase 3: Staged Boot Handshake (PLAYER_LOGIN)                                       │
│    • Stage A (Initialize): Core executes OnInitialize() across all registered modules. │
│    • Stage B (Enable): Core executes OnEnable() on active/enabled modules.             │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Module Lifecycle Contract:
```lua
local PUI<Name> = Primus.PUI<Name> or {}
Primus.PUI<Name> = PUI<Name>
Primus:RegisterModule("PUI<Name>", PUI<Name>, "<Category>")

function PUI<Name>:OnInitialize()
    -- Build frames, create widget structures, register options flares.
end

function PUI<Name>:OnEnable()
    -- Register WoW events, attach tickers, show UI elements.
end

function PUI<Name>:OnDisable()
    -- Unregister events, cancel timers, hide frames cleanly.
end
```

---

## 4. Strict Resource Ownership & Request-Driven Interaction

To prevent frame-fighting, flickering, and cascading breakages, PrimusUI enforces **Single Domain Ownership**:

1. **Domain Isolation:**
   - `PUIHotbars` owns all action bars and action button art.
   - `PUIBags` owns all container and backpack interactions.
   - `PUIUnitFrames` owns player, target, party, and raid unit frames.
   - `PUIChat` owns chat frames and edit boxes.
2. **Zero Cross-Module Frame Mutation:**
   - External modules (e.g. `State.lua` Zen focus, `PUIDock`, `PUIHud`) **must never** directly alter, hide, or set the alpha of frames owned by another module.
3. **Request APIs & Signal Bus:**
   - When an external engine requires a change in another domain (e.g. Zen mode fading action bars out of combat), it submits a request via public methods (`PUIHotbars:SetCombatFade(alpha)`) or emits an event on the signal bus (`Events:Fire("UI_COMBAT_STATE_CHANGED", inCombat)`).
   - The owner module evaluates its own internal state machine (e.g. combat fade vs. mouseover peek vs. keybind hover) and applies the final visual update in one coherent place.

### 4.1 Canonical Domain Boundary Case Studies:

#### Case Study A: The Layout & Movement Boundary (`PUIMover` vs Feature Modules)
* **`PUIMover` Role:** The universal moving and layout engine. It owns the translucent blue drag overlays, the magnetic fullscreen grid (`[GRID]`), 1-pixel arrow nudging, and persistent position serialization (`(point, relativePoint, x, y)` in `PrimusCharDB`).
* **Feature Module Role:** `PUIHotbars`, `PUIUnitFrames`, `PUIHud`, and `PUIBags` build their frames and register them on startup:  
  `PUIMover:Register(frameHandle, "UniqueKey", "Human Readable Name", "CATEGORY")`
* **Interaction:** When a player wants to reposition bars (via `/pui move bars` or a button in Hotbars settings), `PUIHotbars` does **not** create custom drag scripts—it simply calls `PUIMover:Unlock("BARS")`. When locked, `PUIMover` restores and persists the coordinates automatically.

#### Case Study B: The Bag Bar vs. Inventory Window Boundary (`PUIHotbars` vs `PUIBags`)
* **`PUIHotbars` (`PUIMicroBags`):** Owns the **physical Bag Bar dock** on screen. Manages whether the bar renders in *Classic 5-Slot Mode* (Backpack + Bags 1–4 + Keyring) or *Single-Button Master Mode* with a live free/total badge (`[34 / 80]`).
* **`PUIBags`:** Owns the **Master Inventory Window** (the pop-up container displaying the item slot grid 0–4, search bar, quality borders, stack splitting, and auto-sorting).
* **Interaction:** 
  - Clicking the Single Bag Button on `PUIMicroBags` calls `PUIBags:Toggle()`.
  - When inventory changes (`BAG_UPDATE`), `PUIMicroBags` queries the slot counts to update its `[34 / 80]` badge text.
  - When the inventory window opens, `PUIBags` tells `PUIMicroBags` to highlight the button. Neither module touches the other's internal frame hierarchy.

#### Case Study C: The Combat Focus Boundary (`Core/State.lua` vs Visual Frame Owners)
* **`Core/State.lua` (Zen Engine):** Monitors player combat state (`PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`).
* **Interaction:** Instead of forcefully hiding `MainMenuBar` or `ChatFrame1`, `State.lua` emits `Events:Fire("UI_COMBAT_STATE_CHANGED", inCombat)` or calls owner methods. `PUIHotbars` and `PUIChat` handle their own out-of-combat fading and mouseover peeking internally.

#### Case Study D: The HUD Cockpit Mini-Bars vs Action Bars Boundary (`PUIHud` vs `PUIHotbars`)
* **`PUIHud` Ownership:** Claims exclusive domain ownership over **Bar 10 (Action Slots 109..120)** for the center-screen cockpit array:
  - **Left Wing Mini-Bar (Slots 109..112):** Defensives & consumables directly flanking the player vertical wing.
  - **Right Wing Mini-Bar (Slots 113..116):** Offensive cooldowns & trinkets flanking the target vertical wing.
  - **ActiveAssist / Emergency Array (Slots 117..120):** Contextual tactical smart action buttons.
* **`PUIHotbars` Ownership:** Owns standard screen action bars (Bars 1–5 / Slots 1..72), Stance Bar (Slots 73..108), Pet Bar, XP Bar, and MicroBags.
* **Why this is strictly decoupled:**
  - PUIHud action buttons are parented directly to the HUD frame and obey HUD dynamic alpha easing (idle -> target -> combat).
  - Isolating cockpit buttons to Bar 10 avoids all stance-paging conflicts with Warrior/Druid/Rogue forms (which page across Slots 73..108).
  - `PUIHotbars` never alters, iterates over, or styles Bar 10 buttons.

#### Case Study E: ActiveAssist Smart Buttons vs Tactical Threat Engine (`PUIHud` vs `PUITactical`)
* **`PUIHud` Role:** Owns the on-screen physical button widgets (`Primus_PUIHud_LeftActiveAssist`, `Primus_PUIHud_RightActiveAssist`) and handles button animations, color transitions (Red -> Amber -> Green), and click triggers.
* **`PUITactical` Role:** Owns combat telemetry calculation, threat scanning, 4-layer aggro discrimination, and the 2-Click Claim & Execute network protocol.
* **Interaction:** `PUIHud` queries `PUITactical:GetCurrentAlert()` and invokes `PUITactical:ClaimRescue()` / `PUITactical:ExecuteRescue()`. Neither module mutates the other's internal frame tree.

### 4.2 Master Cross-Domain Boundary Matrix

| Interface Domain / Feature | Visual Frame Owner | Backend Data / Trigger Engine | Interaction Protocol |
| :--- | :--- | :--- | :--- |
| **HUD Cockpit Mini-Bars** | `PUIHud` (Slots 109..116) | Blizzard Action Backend (`UseAction`, `PickupAction`) | Direct slot indexing (109..120); zero `PUIHotbars` overlap |
| **Bag Bar (Dock) vs Bags (Window)** | `PUIHotbars` (`PUIMicroBags`) | `PUIBags` (Inventory Grid & Item Sort) | Public API: `PUIBags:Toggle()`, bag count queries |
| **Frame Repositioning & Grids** | `PUIMover` (Drag Handles, Grid) | Respective owning modules | Registration via `PUIMover:Register(frame, key, ...)` |
| **ActiveAssist Threat Peel** | `PUIHud` (ActiveAssist Widgets) | `PUITactical` (Aggro & Comm Protocol) | Public API: `PUITactical:GetCurrentAlert()`, `ClaimRescue()` |
| **Unit Frames vs Castbars / Auras** | `PUIUnitFrames` (Health/Mana) | `PUICastBar`, `PUICombatAuras` | Frame anchoring only; independent bar & aura life cycles |
| **Combat Focus & Fading** | Visual Owners (`PUIHotbars`, `PUIChat`) | `Core/State.lua` (Zen Combat Monitor) | Signal Bus: `Events:Fire("UI_COMBAT_STATE_CHANGED")` |

---

## 5. SavedVariables Persistence & Schema Auto-Migration

1. **Dual Storage Model:**
   - `PrimusGlobalDB`: Account-wide profiles, media selections, and global options.
   - `PrimusCharDB`: Character-specific caches (e.g. `PUIBankCache`, layout overrides).
2. **Automatic Schema Migration:**
   - In [`Core/DB/DB.lua`](file:///home/primustech/Downloads/OctoWoW/Interface/AddOns/PrimusUI/Core/DB/DB.lua), when `DB:RegisterNamespace("PUI<Name>")` runs, if an existing profile contains data under the legacy non-PUI key (e.g. `"Bags"`), it is automatically deep-copied into `"PUIBags"` on first boot. User settings are never wiped.

---

## 6. Directory Structure & File Standards

```
Interface/AddOns/PrimusUI/
├── TRUTH.md                      <-- (This Document) Single Source of Truth
├── MODULES.md                    <-- Complete Module Inventory & Status Matrix
├── COMPLETED.md                  <-- Completed Innovations & Milestones Log
├── TODO.md                       <-- Feature Roadmap & Backlog
├── DESIRED_FEATURES.md           <-- Innovation Specifications
├── PrimusUI.toc                  <-- Master Addon Table of Contents (68 Active Files)
├── PrimusUI.lua                  <-- Master Runtime Anchor & Lifecycle Orchestrator
├── Core/                         <-- Tier 1: Internal Framework & Primitives
│   ├── Bootstrap/
│   ├── Events/
│   ├── DB/
│   ├── Memory/
│   ├── Time/
│   ├── Media/
│   ├── Widgets/
│   ├── Keybind/
│   ├── Console/
│   ├── Comm/
│   ├── Config/
│   ├── Debug/
│   ├── State/
│   └── Utils/
├── Modules/                      <-- Tier 2, 3, 4: Decoupled PUI Feature Suites
│   ├── Bars/PUIHotbars/          <-- PUIHotbars, PUIButtons, PUIXPBar, PUIMicroBags
│   ├── Classes/                  <-- PUIDruid, PUIHunter, PUIMage, PUIPaladin, etc.
│   ├── Combat/                   <-- PUICastBar, PUICooldowns, PUICombatLog, etc.
│   ├── Gathering/                <-- PUIGathering
│   ├── HUD/                      <-- PUIHud (PUIWings, PUIMiniBars, etc.), PUIAuras
│   ├── Player/                   <-- PUIBags, PUIBank, PUISpellbook, PUIVendor, etc.
│   ├── Professions/              <-- PUIProfessions
│   ├── Social/                   <-- PUIMessenger, PUIChat, PUIMasterLoot
│   ├── Units/                    <-- PUIUnitBase, PUIUnitFrames
│   └── Utility/                  <-- PUIMover, PUIDock, PUIMerchant, PUIFastLoot, etc.
├── Tools/                        <-- Packaging and release build scripts
└── Release/                      <-- Packaged distribution archives
```

---

## 7. Configuration & Command Guide

| Command | Purpose |
| :--- | :--- |
| `/pui` or `/primus` | Opens the Master Configuration GUI window. |
| `/pui move [category]` | Unlocks/locks UI frames with categorized pill dock and alignment grid. |
| `/pui bind` or `/hoverbind` | Toggles Hover-to-Bind mode for action buttons. |
| `/pui memory` | Runs garbage collection and displays recycled table pool diagnostics. |
| `/pui errors` | Displays the runtime error log and diagnostic trace. |
| `/pui help` | Displays the command menu in chat. |
